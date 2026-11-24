// The album and sealing (v2 PRD V2-FR-37, V2-FR-41, V2-FR-43, V2-FR-45, V2-FR-70, open check OC-4): every route to a
// picture before the reveal returns nothing, the revealed album is in capture order across guests with numbered gaps,
// a late picture takes its place by capture time, each picture has its viewing copy, and "Your Film is ready" reaches
// every member with the full app at the reveal, once, the Host included and a removed guest not.
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { api, internal } from "../convex/_generated/api";
import { storageConfig } from "../convex/lib/storage";
import { startApnsDouble } from "./support/apns-double";
import { newBackend, newHost, randomId, readAddresses, refusalCode, signedIn } from "./support/convex";
import { joinAsGuest, loadFilm, storePicture } from "./support/events";

let apns: Awaited<ReturnType<typeof startApnsDouble>>;
beforeEach(async () => {
  apns = await startApnsDouble();
});
afterEach(async () => {
  await apns.close();
});

async function party() {
  const t = newBackend();
  const { host } = await newHost(t, "user_maya", "Maya");
  const { eventId, joinCode } = await loadFilm(host, { rolls: 3 });
  const jo = await joinAsGuest(t, joinCode, "Jo");
  const sam = await joinAsGuest(t, joinCode, "Sam");
  return { t, host, eventId, joinCode, jo, sam };
}

describe("before the reveal nobody sees a picture, by any route (V2-FR-37)", () => {
  test("the album, the shooter's own place, the Host's view and the storage itself give nothing", async () => {
    const { t, host, eventId, jo, sam } = await party();
    const minute = Date.now();
    await storePicture(t, eventId, 1, { guestToken: jo.token, captureTime: minute });
    for (const attempt of [
      host.action(api.reads.album, { eventId }),
      t.action(api.reads.album, { eventId, guestToken: jo.token }),
      t.action(api.reads.album, { eventId, guestToken: sam.token }),
    ]) {
      expect(await refusalCode(attempt)).toBe("sealed");
    }
    const ownView = await t.query(api.joining.memberView, { eventId, guestToken: jo.token });
    expect(ownView.storedExposures).toEqual([1]);
    expect(JSON.stringify(ownView)).not.toMatch(/url|storageKey/i);
    const keys = await t.run(async (ctx) => {
      const picture = (await ctx.db.query("pictures").first())!;
      return [picture.storageKey!, picture.viewStorageKey!];
    });
    const config = storageConfig();
    for (const key of keys) expect((await fetch(`${config.endpoint}/${config.bucket}/${key}`)).status).toBe(403);
  });
});

describe("the revealed album (V2-FR-43, V2-FR-45, V2-FR-41)", () => {
  test("every member sees the same pictures in capture order across guests, numbered, with names and viewing copies", async () => {
    const { t, host, eventId, jo, sam } = await party();
    const start = Date.now() - 60_000;
    const samsFirst = await storePicture(t, eventId, 1, { guestToken: sam.token, captureTime: start + 1_000 });
    const josFirst = await storePicture(t, eventId, 1, { guestToken: jo.token, captureTime: start + 2_000 });
    await storePicture(t, eventId, 2, { guestToken: sam.token, captureTime: start + 3_000 });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    const views = [
      await host.action(api.reads.album, { eventId }),
      await t.action(api.reads.album, { eventId, guestToken: jo.token }),
      await t.action(api.reads.album, { eventId, guestToken: sam.token }),
    ];
    for (const album of views) {
      expect(album.entries.map((entry) => !entry.removed && [entry.number, entry.shooterName, entry.exposureNumber])).toEqual([
        [1, "Sam", 1],
        [2, "Jo", 1],
        [3, "Sam", 2],
      ]);
    }
    const [hostView, josView] = views;
    expect(hostView!.isHost).toBe(true);
    expect(josView!.entries.map((entry) => !entry.removed && entry.mine)).toEqual([false, true, false]);
    const [first] = hostView!.entries;
    if (first!.removed) throw new Error("expected a picture");
    expect(new Uint8Array(await (await fetch(first.url)).arrayBuffer()).byteLength).toBe(samsFirst.file.size);
    expect(new Uint8Array(await (await fetch(first.viewUrl)).arrayBuffer()).byteLength).toBe(samsFirst.view.size);
    expect(new URL(first.viewUrl).searchParams.get("X-Amz-Expires")).toBe("60");
    expect(josFirst.file.size).toBeGreaterThan(josFirst.view.size);
  });

  test("a picture that arrives after the reveal joins the album in its place by capture time, for everyone", async () => {
    const { t, host, eventId, jo, sam } = await party();
    const start = Date.now() - 60_000;
    await storePicture(t, eventId, 1, { guestToken: sam.token, captureTime: start + 1_000 });
    await storePicture(t, eventId, 2, { guestToken: sam.token, captureTime: start + 3_000 });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    // Jo shot offline in between, and comes online after the reveal (V2-FR-41).
    const token = (await t.mutation(api.guests.startSession, { ...jo.guest, eventId })).token;
    await storePicture(t, eventId, 1, { guestToken: token, captureTime: start + 2_000 });
    expect((await readAddresses(host, { eventId })).map((picture) => picture.shooterName)).toEqual(["Sam", "Jo", "Sam"]);
  });

  test("a removed guest's app sees no picture and learns it was removed; a stranger sees nothing", async () => {
    const { t, host, eventId, jo } = await party();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    const josPlace = await t.run(async (ctx) => (await ctx.db.query("memberships").collect()).find((m) => m.guestName === "Jo")!._id);
    await host.mutation(api.hosting.removeGuest, { eventId, membershipId: josPlace });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    expect(await refusalCode(t.action(api.reads.album, { eventId, guestToken: jo.token }))).toBe("guestTokenRefused");
    expect(await t.query(api.joining.standing, { eventId, guest: jo.guest })).toMatchObject({ event: "revealed", place: "removed" });
    await newHost(t, "user_stranger", "Stranger");
    expect(await refusalCode(signedIn(t, "user_stranger").action(api.reads.album, { eventId }))).toBe("notAMember");
  });
});

describe("Your Film is ready (V2-FR-70)", () => {
  test("reaches the Host and every member with the full app, a guest who left included, a removed guest not, once", async () => {
    const { t, host, eventId, joinCode, jo, sam } = await party();
    const tokens = { host: "a1".repeat(32), jo: "b2".repeat(32), sam: "c3".repeat(32), removed: "d4".repeat(32) };
    await host.mutation(api.pushTokens.register, { installationId: randomId(), token: tokens.host, environment: "sandbox" });
    await t.mutation(api.pushTokens.registerGuest, { installationId: randomId(), token: tokens.jo, environment: "sandbox", guest: jo.guest });
    await t.mutation(api.pushTokens.registerGuest, { installationId: randomId(), token: tokens.sam, environment: "production", guest: sam.guest });
    const lee = await joinAsGuest(t, joinCode, "Lee");
    await t.mutation(api.pushTokens.registerGuest, { installationId: randomId(), token: tokens.removed, environment: "sandbox", guest: lee.guest });
    await t.mutation(api.joining.leave, { eventId, guestToken: sam.token });
    const leesPlace = await t.run(async (ctx) => (await ctx.db.query("memberships").collect()).find((m) => m.guestName === "Lee")!._id);
    await host.mutation(api.hosting.removeGuest, { eventId, membershipId: leesPlace });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    await t.finishAllScheduledFunctions(() => undefined);
    const sentTo = apns.requests.map((request) => request.path.split("/").pop()).sort();
    expect(sentTo).toEqual([tokens.host, tokens.jo, tokens.sam].sort());
    for (const request of apns.requests) {
      expect(JSON.parse(request.body)).toEqual({
        aps: { alert: { title: "Ana & Leo", body: "Your Film is ready" }, sound: "default" },
        eventId,
      });
    }
    // Once per event: the step run again sends nothing.
    await t.action(internal.alerts.sendFilmReady, { eventId });
    expect(apns.requests).toHaveLength(3);
  });

  test("an installation carries both its signed-in Account and the phone's guest identity, and sign-out keeps the guest's", async () => {
    const { t, host, jo } = await party();
    const installationId = randomId();
    await t.mutation(api.pushTokens.registerGuest, { installationId, token: "e5".repeat(32), environment: "sandbox", guest: jo.guest });
    await host.mutation(api.pushTokens.register, { installationId, token: "e5".repeat(32), environment: "sandbox" });
    const both = await t.run((ctx) => ctx.db.query("pushTokens").collect());
    expect(both).toHaveLength(1);
    expect(both[0]!.accountId).toBeDefined();
    expect(both[0]!.guestIdentityId).toBeDefined();
    await host.mutation(api.pushTokens.unregister, { installationId });
    const after = await t.run((ctx) => ctx.db.query("pushTokens").collect());
    expect(after).toHaveLength(1);
    expect(after[0]!.accountId).toBeUndefined();
  });
});
