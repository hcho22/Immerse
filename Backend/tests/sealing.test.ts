// Sealing and read grants (V2-FR-37, section 9.4, open check OC-4): every way found to read a sealed picture is
// tried, and each one returns nothing before the reveal.
import { AwsClient } from "aws4fetch";
import { describe, expect, test } from "vitest";
import { api, internal } from "../convex/_generated/api";
import type { Id } from "../convex/_generated/dataModel";
import { presignRead, storageConfig } from "../convex/lib/storage";
import {
  type Backend,
  drainStorageDeletions,
  type Guest,
  newBackend,
  newEvent,
  newGuest,
  newHost,
  pictureFile,
  put,
  refusalCode,
  signedIn,
  readAddresses,
} from "./support/convex";

// An event with one stored picture by a guest and one by the Host, sealed.
async function sealedEvent() {
  const t = newBackend();
  const { host } = await newHost(t, "user_host");
  const eventId = await newEvent(t, "user_host");
  const guest = await newGuest(t, eventId, "Jo");
  const guestFile = await upload(t, eventId, { guestToken: guest.token }, 1);
  const hostFile = await upload(t, eventId, { as: host }, 1);
  const keys = await t.run(async (ctx) =>
    (await ctx.db.query("pictures").collect()).map((picture) => picture.storageKey!),
  );
  return { t, host, eventId, guest, keys, guestFile, hostFile };
}

async function upload(
  t: Backend,
  eventId: Id<"events">,
  who: { guestToken?: string; as?: ReturnType<typeof signedIn> },
  exposureNumber: number,
) {
  const runner = who.as ?? t;
  const file = await pictureFile(32 * 1024);
  const args = {
    eventId,
    exposureNumber,
    captureTime: Date.now(),
    contentType: file.contentType,
    size: file.size,
    sha256: file.sha256,
    guestToken: who.guestToken,
  };
  const address = await runner.action(api.pictures.requestUpload, args);
  if (address.status !== "upload") throw new Error("expected an address");
  expect((await put(address, file.bytes)).status).toBe(200);
  expect(await runner.action(api.pictures.confirmUpload, { eventId, exposureNumber, guestToken: who.guestToken })).toEqual({
    status: "stored",
  });
  return file;
}

function objectUrl(key: string) {
  const config = storageConfig();
  return `${config.endpoint}/${config.bucket}/${key}`;
}

describe("before the reveal, no one can read a sealed picture", () => {
  test("the server issues no read address to the Host, the shooter or another guest", async () => {
    const { t, host, eventId, guest } = await sealedEvent();
    const other: Guest = await newGuest(t, eventId, "Sam");
    expect(await refusalCode(readAddresses(host, { eventId }))).toBe("sealed");
    expect(await refusalCode(readAddresses(t, { eventId, guestToken: guest.token }))).toBe("sealed");
    expect(await refusalCode(readAddresses(t, { eventId, guestToken: other.token }))).toBe("sealed");
  });

  test("after shooting ends but before the reveal, the pictures stay sealed", async () => {
    const { t, host, eventId } = await sealedEvent();
    await t.mutation(internal.proofs.endProofEvent, { eventId });
    expect(await refusalCode(readAddresses(host, { eventId }))).toBe("sealed");
  });

  test("the storage key alone reads nothing: the bucket is private", async () => {
    const { keys } = await sealedEvent();
    for (const key of keys) {
      const response = await fetch(objectUrl(key));
      expect(response.status).toBe(403);
      expect(await response.text()).not.toContain("JFIF");
    }
  });

  test("the bucket cannot be listed without credentials", async () => {
    await sealedEvent();
    const config = storageConfig();
    expect((await fetch(`${config.endpoint}/${config.bucket}?list-type=2`)).status).toBe(403);
    expect((await fetch(`${config.endpoint}/${config.bucket}/`)).status).toBe(403);
  });

  test("an upload address cannot be turned into a read: the same signature refuses a GET", async () => {
    const t = newBackend();
    const { host } = await newHost(t, "user_host");
    const eventId = await newEvent(t, "user_host");
    const file = await pictureFile(8 * 1024);
    const address = await host.action(api.pictures.requestUpload, {
      eventId,
      exposureNumber: 1,
      captureTime: Date.now(),
      contentType: file.contentType,
      size: file.size,
      sha256: file.sha256,
    });
    if (address.status !== "upload") throw new Error("expected an address");
    await put(address, file.bytes);
    await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 });
    // Refused with or without the headers the address was signed with; no response carries the picture.
    for (const init of [{ method: "GET" }, { method: "HEAD" }, { method: "GET", headers: address.headers }]) {
      const response = await fetch(address.url, init);
      expect(response.status).toBeGreaterThanOrEqual(400);
      expect((await response.arrayBuffer()).byteLength).not.toBe(file.size);
    }
  });

  test("an address signed with the wrong secret is refused", async () => {
    const { keys } = await sealedEvent();
    const config = storageConfig();
    const forged = await presignRead({ ...config, secretAccessKey: "not-the-secret" }, keys[0]!);
    expect((await fetch(forged.url)).status).toBe(403);
  });

  test("a guest token cannot read another event's pictures", async () => {
    const { t, eventId } = await sealedEvent();
    const otherEvent = await newEvent(t, "user_host");
    const stranger = await newGuest(t, otherEvent, "Lee");
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    expect(await refusalCode(readAddresses(t, { eventId, guestToken: stranger.token }))).toBe(
      "guestTokenRefused",
    );
  });

  test("a signed-in person with no place in the event cannot read it, even after the reveal", async () => {
    const { t, eventId } = await sealedEvent();
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    await newHost(t, "user_stranger", "Stranger");
    const stranger = signedIn(t, "user_stranger");
    expect(await refusalCode(readAddresses(stranger, { eventId }))).toBe("notAMember");
    expect(await refusalCode(readAddresses(t, { eventId }))).toBe("unauthenticated");
  });
});

describe("after the reveal, members get short-lived read addresses", () => {
  test("every member, the Host and a guest who left included, reads every picture whole", async () => {
    const { t, host, eventId, guest, guestFile, hostFile } = await sealedEvent();
    await t.run(async (ctx) => {
      const membership = await ctx.db.query("memberships").filter((q) => q.eq(q.field("guestName"), "Jo")).unique();
      await ctx.db.patch(membership!._id, { status: "left" });
    });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    for (const reader of [readAddresses(host, { eventId }), readAddresses(t, { eventId, guestToken: guest.token })]) {
      const addresses = await reader;
      expect(addresses).toHaveLength(2);
      for (const address of addresses) {
        expect(new URL(address.url).searchParams.get("X-Amz-Expires")).toBe("60");
        const bytes = new Uint8Array(await (await fetch(address.url)).arrayBuffer());
        const expected = address.shooterName === "Jo" ? guestFile : hostFile;
        expect(bytes.byteLength).toBe(expected.size);
        expect(address.sha256).toBe(expected.sha256);
      }
    }
  });

  test("an expired read address reads nothing", async () => {
    const { t, eventId, keys } = await sealedEvent();
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    const expiring = await presignRead(storageConfig(), keys[0]!, 1);
    expect((await fetch(expiring.url)).status).toBe(200);
    await new Promise((resolve) => setTimeout(resolve, 2_100));
    expect((await fetch(expiring.url)).status).toBe(403);
  });

  test("a read address reused after its picture was removed reads nothing", async () => {
    const { t, host, eventId, guest } = await sealedEvent();
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    const addresses = await readAddresses(host, { eventId });
    const guestAddress = addresses.find((address) => address.shooterName === "Jo")!;
    expect((await fetch(guestAddress.url)).status).toBe(200);
    await t.mutation(internal.proofs.removeProofGuest, { eventId, publicId: guest.publicId });
    await drainStorageDeletions(t);
    expect((await fetch(guestAddress.url)).status).toBe(404);
    // The removed guest's own token reads nothing more.
    expect(await refusalCode(readAddresses(t, { eventId, guestToken: guest.token }))).toBe(
      "guestTokenRefused",
    );
    // And the album lists only what is left.
    expect((await readAddresses(host, { eventId })).map((a) => a.shooterName)).toEqual(["Maya"]);
  });

  test("a removed guest cannot get back in with their secret", async () => {
    const { t, eventId, guest } = await sealedEvent();
    await t.mutation(internal.proofs.removeProofGuest, { eventId, publicId: guest.publicId });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    expect(
      await refusalCode(t.mutation(api.guests.startSession, { publicId: guest.publicId, secret: guest.secret, eventId })),
    ).toBe("guestTokenRefused");
  });

  test("an expired guest token is refused", async () => {
    const { t, eventId, guest } = await sealedEvent();
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    await t.run(async (ctx) => {
      for (const session of await ctx.db.query("guestSessions").collect()) await ctx.db.patch(session._id, { expiresAt: Date.now() - 1 });
    });
    expect(await refusalCode(readAddresses(t, { eventId, guestToken: guest.token }))).toBe(
      "guestTokenRefused",
    );
    // With the secret, the guest gets a new one.
    const { token } = await t.mutation(api.guests.startSession, { publicId: guest.publicId, secret: guest.secret, eventId });
    expect(await readAddresses(t, { eventId, guestToken: token })).toHaveLength(2);
  });

  test("a gone or deleted event gives no addresses", async () => {
    const { t, host, eventId } = await sealedEvent();
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    await t.run((ctx) => ctx.db.patch(eventId, { state: "deleted" }));
    expect(await refusalCode(readAddresses(host, { eventId }))).toBe("eventGone");
  });

  test("the guest secret is never stored, only its verifier", async () => {
    const { t, guest } = await sealedEvent();
    const stored = JSON.stringify(await t.run((ctx) => ctx.db.query("guestIdentities").collect()));
    expect(stored).not.toContain(guest.secret);
    const sessions = JSON.stringify(await t.run((ctx) => ctx.db.query("guestSessions").collect()));
    expect(sessions).not.toContain(guest.token);
  });

  test("storage credentials of a different key pair read nothing", async () => {
    const { keys } = await sealedEvent();
    const config = storageConfig();
    const wrong = new AwsClient({ accessKeyId: "someoneelse", secretAccessKey: "x".repeat(40), service: "s3", region: config.region });
    expect((await wrong.fetch(objectUrl(keys[0]!))).status).toBe(403);
  });
});
