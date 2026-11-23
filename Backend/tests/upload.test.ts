// The upload path of section 9.3 (open check OC-3), against the S3-compatible stand-in for R2: a picture-sized
// file goes up through a one-time address the server signs, and is stored only after its size and checksum match.
import { AwsClient } from "aws4fetch";
import { describe, expect, test } from "vitest";
import { api, internal } from "../convex/_generated/api";
import { presignUpload, readObject, storageConfig } from "../convex/lib/storage";
import {
  drainStorageDeletions,
  newBackend,
  newEvent,
  newGuest,
  newHost,
  pictureFile,
  put,
  refusalCode,
  signedIn,
} from "./support/convex";

async function setUp() {
  const t = newBackend();
  const { host, accountId } = await newHost(t, "user_host");
  const eventId = await newEvent(t, "user_host");
  return { t, host, accountId, eventId };
}

function uploadArgs(eventId: string, file: Awaited<ReturnType<typeof pictureFile>>, exposureNumber = 1) {
  return {
    eventId: eventId as never,
    exposureNumber,
    captureTime: Date.now(),
    contentType: file.contentType,
    size: file.size,
    sha256: file.sha256,
  };
}

async function storedState(t: ReturnType<typeof newBackend>, exposureNumber = 1) {
  return t.run(async (ctx) => {
    const picture = await ctx.db
      .query("pictures")
      .filter((q) => q.eq(q.field("exposureNumber"), exposureNumber))
      .unique();
    return picture;
  });
}

describe("a picture-sized file reaches R2 through a one-time address", () => {
  test("the Host's picture is uploaded, confirmed by size and checksum, and stored", async () => {
    const { t, host, eventId } = await setUp();
    const file = await pictureFile();
    const address = await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    expect(address.status).toBe("upload");
    if (address.status !== "upload") return;
    expect(address.method).toBe("PUT");
    expect(new URL(address.url).searchParams.get("X-Amz-Expires")).toBe("300");
    expect((await put(address, file.bytes)).status).toBe(200);
    expect(await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })).toEqual({ status: "stored" });
    const picture = await storedState(t);
    expect(picture?.state).toBe("stored");
    const object = await readObject(storageConfig(), picture!.storageKey!);
    expect(object?.size).toBe(file.size);
  });

  test("a guest with no Account uploads with their guest token", async () => {
    const { t, eventId } = await setUp();
    const guest = await newGuest(t, eventId);
    const file = await pictureFile(512 * 1024);
    const address = await t.action(api.pictures.requestUpload, { ...uploadArgs(eventId, file), guestToken: guest.token });
    if (address.status !== "upload") throw new Error("expected an address");
    expect((await put(address, file.bytes)).status).toBe(200);
    expect(await t.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1, guestToken: guest.token })).toEqual({
      status: "stored",
    });
  });

  test("a picture sent twice is stored once, and the second request is told it is already stored", async () => {
    const { t, host, eventId } = await setUp();
    const file = await pictureFile(256 * 1024);
    const first = await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    if (first.status !== "upload") throw new Error("expected an address");
    await put(first, file.bytes);
    await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 });
    expect(await host.action(api.pictures.requestUpload, uploadArgs(eventId, file))).toEqual({ status: "stored" });
    expect(await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })).toEqual({ status: "stored" });
    const rows = await t.run((ctx) => ctx.db.query("pictures").collect());
    expect(rows).toHaveLength(1);
  });

  test("a different picture for an exposure already stored is refused", async () => {
    const { host, eventId } = await setUp();
    const file = await pictureFile(128 * 1024);
    const address = await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    if (address.status !== "upload") throw new Error("expected an address");
    await put(address, file.bytes);
    await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 });
    const other = await pictureFile(128 * 1024);
    expect(await refusalCode(host.action(api.pictures.requestUpload, uploadArgs(eventId, other)))).toBe("exposureTaken");
  });

  test("an upload with a different content type than the address was signed for is refused by storage", async () => {
    const { host, eventId } = await setUp();
    const file = await pictureFile(64 * 1024);
    const address = await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    if (address.status !== "upload") throw new Error("expected an address");
    const response = await put(address, file.bytes, { ...address.headers, "Content-Type": "image/png" });
    expect(response.status).toBe(403);
    expect(await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })).toEqual({ status: "missing" });
  });

  test("a body that does not match the signed checksum is refused by storage", async () => {
    const { host, eventId } = await setUp();
    const file = await pictureFile(64 * 1024);
    const address = await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    if (address.status !== "upload") throw new Error("expected an address");
    const tampered = file.bytes.slice();
    tampered[0] ^= 0xff;
    const response = await put(address, tampered);
    expect(response.status).toBeGreaterThanOrEqual(400);
    expect(await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })).toEqual({ status: "missing" });
  });

  test("an object that does not match is caught at confirmation, deleted, and the picture sent again", async () => {
    const { t, host, eventId } = await setUp();
    const file = await pictureFile(64 * 1024);
    const address = await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    if (address.status !== "upload") throw new Error("expected an address");
    // Storage that did not check the checksum header would accept any body at the key. A request signed without
    // that header stands for it here, carrying a shorter body.
    const before = await storedState(t);
    const config = storageConfig();
    const client = new AwsClient({ ...config, service: "s3" });
    const url = new URL(`${config.endpoint}/${config.bucket}/${before!.storageKey!}`);
    const response = await client.fetch(url, {
      method: "PUT",
      headers: { "content-type": file.contentType },
      body: file.bytes.slice(0, 1000),
    });
    expect(response.status).toBe(200);
    expect(await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })).toEqual({ status: "mismatch" });
    const after = await storedState(t);
    expect(after?.state).toBe("uploading");
    expect(after?.storageKey).not.toBe(before?.storageKey);
    await drainStorageDeletions(t);
    expect(await readObject(config, before!.storageKey!)).toBeNull();
    // Sent again, at the new key, the picture is stored.
    const again = await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    if (again.status !== "upload") throw new Error("expected an address");
    expect((await put(again, file.bytes)).status).toBe(200);
    expect(await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })).toEqual({ status: "stored" });
  });

  test("an empty object at the key is caught at confirmation", async () => {
    const { t, host, eventId } = await setUp();
    const file = await pictureFile(8 * 1024);
    await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    const picture = await storedState(t);
    const config = storageConfig();
    const client = new AwsClient({ ...config, service: "s3" });
    await client.fetch(`${config.endpoint}/${config.bucket}/${picture!.storageKey!}`, { method: "PUT", body: "" });
    expect(await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })).toEqual({ status: "mismatch" });
  });

  test("an expired upload address is refused by storage, and asking again gives a fresh one", async () => {
    const { t, host, eventId } = await setUp();
    const file = await pictureFile(32 * 1024);
    await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    const picture = await storedState(t);
    const expiring = await presignUpload(storageConfig(), picture!.storageKey!, file.contentType, file.sha256, 1);
    await new Promise((resolve) => setTimeout(resolve, 2_100));
    expect((await put(expiring, file.bytes)).status).toBe(403);
    const fresh = await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    if (fresh.status !== "upload") throw new Error("expected an address");
    expect((await put(fresh, file.bytes)).status).toBe(200);
    expect(await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })).toEqual({ status: "stored" });
  });

  test("an app killed after the upload but before confirming confirms on its next launch", async () => {
    const { host, eventId } = await setUp();
    const file = await pictureFile(128 * 1024);
    const address = await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    if (address.status !== "upload") throw new Error("expected an address");
    await put(address, file.bytes);
    // Killed here. On the next launch the app asks again and then confirms.
    const again = await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    expect(again.status).toBe("upload");
    expect(await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })).toEqual({ status: "stored" });
  });

  test("an app killed before uploading gets a new address for the same picture on its next launch", async () => {
    const { t, host, eventId } = await setUp();
    const file = await pictureFile(128 * 1024);
    await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    const first = await storedState(t);
    // Killed before sending anything.
    expect(await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })).toEqual({ status: "missing" });
    const again = await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    if (again.status !== "upload") throw new Error("expected an address");
    expect((await storedState(t))?.storageKey).toBe(first?.storageKey);
    await put(again, file.bytes);
    expect(await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })).toEqual({ status: "stored" });
  });

  test("a picture taken after the End Time is refused", async () => {
    const { t, host, eventId } = await setUp();
    await t.mutation(internal.proofs.endProofEvent, { eventId });
    const file = await pictureFile(16 * 1024);
    const late = { ...uploadArgs(eventId, file), captureTime: Date.now() + 60_000 };
    expect(await refusalCode(host.action(api.pictures.requestUpload, late))).toBe("afterEndTime");
  });

  test("a picture taken before the End Time still uploads after it, and after the reveal", async () => {
    const { t, host, eventId } = await setUp();
    const file = await pictureFile(16 * 1024);
    const args = { ...uploadArgs(eventId, file), captureTime: Date.now() - 1_000 };
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    const address = await host.action(api.pictures.requestUpload, args);
    if (address.status !== "upload") throw new Error("expected an address");
    await put(address, file.bytes);
    expect(await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })).toEqual({ status: "stored" });
  });

  test("malformed requests are refused before anything is recorded", async () => {
    const { t, host, eventId } = await setUp();
    const file = await pictureFile(1024);
    const bad = [
      { ...uploadArgs(eventId, file), contentType: "image/png" },
      { ...uploadArgs(eventId, file), size: 0 },
      { ...uploadArgs(eventId, file), size: 26 * 1024 * 1024 },
      { ...uploadArgs(eventId, file), sha256: "abc" },
      { ...uploadArgs(eventId, file), exposureNumber: 0 },
      { ...uploadArgs(eventId, file), exposureNumber: 28 },
      { ...uploadArgs(eventId, file), exposureNumber: 1.5 },
    ];
    for (const args of bad) expect(await refusalCode(host.action(api.pictures.requestUpload, args))).toBe("invalid");
    expect(await t.run((ctx) => ctx.db.query("pictures").collect())).toHaveLength(0);
  });

  test("nobody without a place in the event can upload to it", async () => {
    const { t, eventId } = await setUp();
    const file = await pictureFile(1024);
    expect(await refusalCode(t.action(api.pictures.requestUpload, uploadArgs(eventId, file)))).toBe("unauthenticated");
    const stranger = signedIn(t, "user_stranger");
    expect(await refusalCode(stranger.action(api.pictures.requestUpload, uploadArgs(eventId, file)))).toBe("noAccount");
    await newHost(t, "user_other", "Other");
    const other = signedIn(t, "user_other");
    expect(await refusalCode(other.action(api.pictures.requestUpload, uploadArgs(eventId, file)))).toBe("notAMember");
    expect(
      await refusalCode(t.action(api.pictures.requestUpload, { ...uploadArgs(eventId, file), guestToken: "not-a-token" })),
    ).toBe("guestTokenRefused");
  });

  test("a guest's token works only in the event it was issued for", async () => {
    const { t, eventId } = await setUp();
    const otherEvent = await newEvent(t, "user_host");
    const guest = await newGuest(t, eventId);
    const file = await pictureFile(1024);
    expect(
      await refusalCode(t.action(api.pictures.requestUpload, { ...uploadArgs(otherEvent, file), guestToken: guest.token })),
    ).toBe("guestTokenRefused");
  });

  test("a removed guest's waiting pictures are refused, and their token stops working", async () => {
    const { t, eventId } = await setUp();
    const guest = await newGuest(t, eventId);
    const file = await pictureFile(1024);
    await t.mutation(internal.proofs.removeProofGuest, { eventId, publicId: guest.publicId });
    expect(
      await refusalCode(t.action(api.pictures.requestUpload, { ...uploadArgs(eventId, file), guestToken: guest.token })),
    ).toBe("guestTokenRefused");
    expect(
      await refusalCode(t.mutation(api.guests.startSession, { publicId: guest.publicId, secret: guest.secret, eventId })),
    ).toBe("guestTokenRefused");
  });

  test("a withdrawn or removed picture can never be uploaded again", async () => {
    const { t, host, eventId } = await setUp();
    const file = await pictureFile(1024);
    const address = await host.action(api.pictures.requestUpload, uploadArgs(eventId, file));
    if (address.status !== "upload") throw new Error("expected an address");
    await put(address, file.bytes);
    await host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 });
    await t.run(async (ctx) => {
      const picture = await ctx.db.query("pictures").first();
      await ctx.db.patch(picture!._id, { state: "removed", storageKey: undefined, sha256: undefined, size: undefined });
    });
    expect(await refusalCode(host.action(api.pictures.requestUpload, uploadArgs(eventId, file)))).toBe("pictureRemoved");
    expect(await refusalCode(host.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 }))).toBe("pictureRemoved");
  });
});
