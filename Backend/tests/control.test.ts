// Control, moderation and deletion (v2 PRD section 5.9, section 7): Withdraw Before Reveal, removing one's own picture,
// the Host removing a picture or a guest with their pictures, reporting to the Host and support, support removing a
// picture, deleting the event, leaving and rejoining, claiming a guest identity into an Account, and Delete Guest
// Identity. Every removal writes its marker first, so nothing removed comes back by a late or repeated upload.
import { createHmac } from "node:crypto";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { api, internal } from "../convex/_generated/api";
import type { Id } from "../convex/_generated/dataModel";
import { readObject, storageConfig } from "../convex/lib/storage";
import { type Backend, drainStorageDeletions, newBackend, newHost, pictureFile, readAddresses, refusalCode, signedIn } from "./support/convex";
import { freshToken, joinAsGuest, loadFilm, storePicture } from "./support/events";
import { startSupportRelay } from "./support/webhook-double";

let relay: Awaited<ReturnType<typeof startSupportRelay>>;
beforeEach(async () => {
  relay = await startSupportRelay();
});
afterEach(async () => {
  await relay.close();
});

async function eventWithGuests() {
  const t = newBackend();
  const { host, accountId } = await newHost(t, "user_maya", "Maya");
  const { eventId, joinCode } = await loadFilm(host, { rolls: 3 });
  const jo = await joinAsGuest(t, joinCode, "Jo");
  const sam = await joinAsGuest(t, joinCode, "Sam");
  return { t, host, accountId, eventId, joinCode, jo, sam };
}

async function reveal(t: Backend, eventId: Id<"events">) {
  await t.mutation(internal.proofs.revealProofEvent, { eventId });
}

async function keysOf(t: Backend, eventId: Id<"events">) {
  return t.run(async (ctx) =>
    (await ctx.db.query("pictures").withIndex("by_event", (q) => q.eq("eventId", eventId)).collect()).flatMap((picture) =>
      [picture.storageKey, picture.viewStorageKey].filter((key): key is string => key !== undefined),
    ),
  );
}

async function gone(keys: string[]) {
  for (const key of keys) expect(await readObject(storageConfig(), key)).toBeNull();
}

describe("Withdraw Before Reveal (V2-FR-50)", () => {
  test("removes every picture the guest sent, unseen, and refuses any picture up to the last exposure they had used", async () => {
    const { t, eventId, jo, sam } = await eventWithGuests();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    await storePicture(t, eventId, 2, { guestToken: jo.token });
    await storePicture(t, eventId, 1, { guestToken: sam.token });
    const keys = (await keysOf(t, eventId)).slice(0, 4);
    // Jo's phone had used five exposures; three, four and five were still waiting on it.
    expect(await t.mutation(api.joining.withdraw, { eventId, guestToken: jo.token, throughExposure: 5 })).toEqual({ withdrawnThrough: 5 });
    await drainStorageDeletions(t);
    await gone(keys);
    for (const exposureNumber of [1, 3, 5]) {
      const file = await pictureFile(1024);
      expect(
        await refusalCode(
          t.action(api.pictures.requestUpload, {
            eventId, exposureNumber, captureTime: Date.now(), contentType: file.contentType, size: file.size, sha256: file.sha256,
            guestToken: jo.token,
          }),
        ),
      ).toBe("pictureRemoved");
    }
    // Jo keeps shooting with what is left of the Roll; the count never goes back.
    await storePicture(t, eventId, 6, { guestToken: jo.token });
    const view = await t.query(api.joining.memberView, { eventId, guestToken: jo.token });
    expect(view.exposuresUsed).toBe(6);
    expect(view.withdrawnThrough).toBe(5);
    await reveal(t, eventId);
    const album = await t.action(api.reads.album, { eventId, guestToken: sam.token });
    // Jo's two sent pictures leave numbered gaps; Sam's and Jo's sixth stay.
    expect(album.entries.map((entry) => (entry.removed ? "gap" : entry.shooterName))).toEqual(["gap", "gap", "Sam", "Jo"]);
    expect(album.entries.map((entry) => entry.number)).toEqual([1, 2, 3, 4]);
  });

  test("is over at the reveal, and repeating it changes nothing further", async () => {
    const { t, eventId, jo } = await eventWithGuests();
    await t.mutation(api.joining.withdraw, { eventId, guestToken: jo.token, throughExposure: 2 });
    expect(await t.mutation(api.joining.withdraw, { eventId, guestToken: jo.token, throughExposure: 1 })).toEqual({ withdrawnThrough: 2 });
    await reveal(t, eventId);
    expect(await refusalCode(t.mutation(api.joining.withdraw, { eventId, guestToken: jo.token, throughExposure: 2 }))).toBe("alreadyRevealed");
  });
});

describe("removing pictures after the reveal (V2-FR-51, V2-FR-52)", () => {
  test("a guest removes one of their own, for everyone; never another's; and not before the reveal", async () => {
    const { t, eventId, jo, sam } = await eventWithGuests();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    await storePicture(t, eventId, 1, { guestToken: sam.token });
    expect(await refusalCode(t.mutation(api.joining.removeMyPicture, { eventId, guestToken: jo.token, exposureNumber: 1 }))).toBe("notRevealed");
    await reveal(t, eventId);
    const before = await readAddresses(t, { eventId, guestToken: sam.token });
    const josAddress = before.find((picture) => picture.shooterName === "Jo")!;
    await t.mutation(api.joining.removeMyPicture, { eventId, guestToken: jo.token, exposureNumber: 1 });
    await t.mutation(api.joining.removeMyPicture, { eventId, guestToken: jo.token, exposureNumber: 1 });
    await drainStorageDeletions(t);
    expect((await fetch(josAddress.url)).status).toBe(404);
    expect((await fetch(josAddress.viewUrl)).status).toBe(404);
    const album = await t.action(api.reads.album, { eventId, guestToken: sam.token });
    expect(album.entries.filter((entry) => entry.removed)).toHaveLength(1);
    // Removing her own exposure 1 again is only Jo's; Sam's exposure 1 stays.
    expect((await readAddresses(t, { eventId, guestToken: sam.token })).map((p) => p.shooterName)).toEqual(["Sam"]);
  });

  test("the Host removes any picture after the reveal, and changes nothing else about any picture", async () => {
    const { t, host, eventId, jo } = await eventWithGuests();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    const pictureId = await t.run(async (ctx) => (await ctx.db.query("pictures").first())!._id);
    expect(await refusalCode(host.mutation(api.hosting.removePictureAsHost, { eventId, pictureId }))).toBe("notRevealed");
    await reveal(t, eventId);
    await host.mutation(api.hosting.removePictureAsHost, { eventId, pictureId });
    const album = await host.action(api.reads.album, { eventId });
    expect(album.entries).toEqual([{ number: 1, removed: true }]);
    expect(await t.run(async (ctx) => (await ctx.db.get(pictureId))!.removedBy)).toBe("host");
  });
});

describe("the Host removes a guest (V2-FR-53)", () => {
  test("their pictures go with them, their access ends, and nothing of theirs arrives later", async () => {
    const { t, host, eventId, joinCode, jo, sam } = await eventWithGuests();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    await storePicture(t, eventId, 1, { guestToken: sam.token });
    const josKeys = (await keysOf(t, eventId)).slice(0, 2);
    const josPlace = await t.run(async (ctx) =>
      (await ctx.db.query("memberships").collect()).find((membership) => membership.guestName === "Jo")!._id,
    );
    await host.mutation(api.hosting.removeGuest, { eventId, membershipId: josPlace });
    await drainStorageDeletions(t);
    await gone(josKeys);
    expect(await refusalCode(t.query(api.joining.memberView, { eventId, guestToken: jo.token }))).toBe("guestTokenRefused");
    expect(await refusalCode(t.mutation(api.guests.startSession, { ...jo.guest, eventId }))).toBe("guestTokenRefused");
    // The phone learns it was removed, and deletes what waits on it.
    expect(await t.query(api.joining.standing, { eventId, guest: jo.guest })).toMatchObject({ place: "removed" });
    expect(await t.query(api.joining.preview, { code: joinCode, guest: jo.guest })).toMatchObject({ status: "removed" });
    expect(await refusalCode(joinAsGuest(t, joinCode, "Jo again", jo.guest))).toBe("removedFromEvent");
    // Not even with a replaced code.
    const { joinCode: replaced } = await host.mutation(api.hosting.replaceJoinCode, { eventId, generation: 1 });
    expect(await refusalCode(joinAsGuest(t, replaced, "Jo again", jo.guest))).toBe("removedFromEvent");
    // Their Roll stays used (V2-FR-28).
    expect((await host.query(api.hosting.view, { eventId })).rolls).toMatchObject({ taken: 2 });
    await reveal(t, eventId);
    const album = await t.action(api.reads.album, { eventId, guestToken: sam.token });
    expect(album.entries.map((entry) => (entry.removed ? "gap" : entry.shooterName))).toEqual(["gap", "Sam"]);
  });

  test("the Account a removed identity was claimed into is refused too, and so is the identity claimed later", async () => {
    const { t, host, eventId, joinCode, jo } = await eventWithGuests();
    const josPlace = await t.run(async (ctx) =>
      (await ctx.db.query("memberships").collect()).find((membership) => membership.guestName === "Jo")!._id,
    );
    await host.mutation(api.hosting.removeGuest, { eventId, membershipId: josPlace });
    await newHost(t, "user_jo", "Jo");
    const joAccount = signedIn(t, "user_jo");
    await joAccount.mutation(api.identities.claim, { guest: jo.guest });
    expect(await refusalCode(joAccount.mutation(api.joining.join, { code: joinCode, guestName: "Jo" }))).toBe("removedFromEvent");
  });

  test("the Host cannot remove themselves", async () => {
    const { t, host, eventId, joinCode } = await eventWithGuests();
    await host.mutation(api.joining.join, { code: joinCode, guestName: "Maya" });
    const mayasPlace = await t.run(async (ctx) =>
      (await ctx.db.query("memberships").collect()).find((membership) => membership.guestName === "Maya")!._id,
    );
    expect(await refusalCode(host.mutation(api.hosting.removeGuest, { eventId, membershipId: mayasPlace }))).toBe("invalid");
  });
});

describe("reporting a picture (V2-FR-54, OQ-12)", () => {
  test("reaches the Host in the app without the reporter, and the support relay, signed; it removes nothing", async () => {
    const { t, host, eventId, jo, sam } = await eventWithGuests();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    const pictureId = await t.run(async (ctx) => (await ctx.db.query("pictures").first())!._id);
    expect(await refusalCode(t.mutation(api.reports.report, { eventId, guestToken: sam.token, pictureId, reason: "harassment" }))).toBe("notRevealed");
    await reveal(t, eventId);
    await t.mutation(api.reports.report, { eventId, guestToken: sam.token, pictureId, reason: "harassment" });
    await t.mutation(api.reports.report, { eventId, guestToken: sam.token, pictureId, reason: "harassment" });
    await t.finishAllScheduledFunctions(() => undefined);
    const view = await host.query(api.hosting.view, { eventId });
    expect(view.reports).toEqual([{ reportId: expect.any(String), pictureId, reason: "harassment", at: expect.any(Number) }]);
    expect(JSON.stringify(view.reports)).not.toContain("Sam");
    expect(relay.received).toHaveLength(1);
    const [delivered] = relay.received;
    expect(delivered!.body).toMatchObject({ type: "picture.reported", eventTitle: "Ana & Leo", pictureId, reason: "harassment" });
    expect(delivered!.raw).not.toContain("Sam");
    const expected = createHmac("sha256", relay.secret).update(delivered!.raw).digest("hex");
    expect(delivered!.signature).toBe(`sha256=${expected}`);
    expect(await readAddresses(t, { eventId, guestToken: sam.token })).toHaveLength(1);
  });

  test("a relay that fails is tried again until it accepts, and support sees the report as open meanwhile", async () => {
    const { t, eventId, jo, sam } = await eventWithGuests();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    const pictureId = await t.run(async (ctx) => (await ctx.db.query("pictures").first())!._id);
    await reveal(t, eventId);
    relay.answerWith(503);
    await t.mutation(api.reports.report, { eventId, guestToken: sam.token, pictureId, reason: "privacy" });
    await t.finishAllScheduledFunctions(() => undefined);
    const [open] = await t.query(internal.support.openReports, {});
    expect(open).toMatchObject({ pictureId, reason: "privacy", delivered: false, overdue: false, shooterName: "Jo" });
    relay.answerWith(200);
    const report = await t.run(async (ctx) => (await ctx.db.query("reports").first())!);
    await t.action(internal.reports.deliver, { reportId: report._id });
    expect((await t.query(internal.support.openReports, {}))[0]).toMatchObject({ delivered: true });
    // Past 48 hours it is overdue (success measure M-7).
    await t.run((ctx) => ctx.db.patch(report._id, { at: Date.now() - 49 * 3_600_000 }));
    expect((await t.query(internal.support.openReports, {}))[0]).toMatchObject({ overdue: true });
  });

  test("support removes a reported picture from any event, a deleted Host's included, and closes its reports", async () => {
    const { t, eventId, jo, sam } = await eventWithGuests();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    const pictureId = await t.run(async (ctx) => (await ctx.db.query("pictures").first())!._id);
    await reveal(t, eventId);
    await t.mutation(internal.deletion.deleteAccountBatch, { clerkUserId: "user_maya" });
    await t.mutation(api.reports.report, { eventId, guestToken: sam.token, pictureId, reason: "sexual" });
    await t.mutation(internal.support.removePictureForSupport, { pictureId });
    expect(await t.query(internal.support.openReports, {})).toEqual([]);
    expect(await readAddresses(t, { eventId, guestToken: sam.token })).toEqual([]);
  });

  test("only a member of the event reports, and a Host who shoots removes rather than reports", async () => {
    const { t, host, eventId, jo } = await eventWithGuests();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    const pictureId = await t.run(async (ctx) => (await ctx.db.query("pictures").first())!._id);
    await reveal(t, eventId);
    expect(await refusalCode(host.mutation(api.reports.report, { eventId, pictureId, reason: "other" }))).toBe("notAMember");
    await newHost(t, "user_stranger", "Stranger");
    expect(await refusalCode(signedIn(t, "user_stranger").mutation(api.reports.report, { eventId, pictureId, reason: "other" }))).toBe("notAMember");
    await t.run(async (ctx) => {
      const account = await ctx.db.query("accounts").withIndex("by_clerk_user", (q) => q.eq("clerkUserId", "user_maya")).unique();
      await ctx.db.insert("memberships", { eventId, accountId: account!._id, guestName: "Maya", exposuresUsed: 0, status: "joined", joinedAt: Date.now() });
    });
    expect(await refusalCode(host.mutation(api.reports.report, { eventId, pictureId, reason: "other" }))).toBe("invalid");
  });
});

describe("the Host deletes the event (V2-FR-55)", () => {
  test("every picture goes for everyone, the link says it is no longer available, unclaimed Rolls return, and phones learn of it", async () => {
    const { t, host, eventId, joinCode, jo } = await eventWithGuests();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    const keys = await keysOf(t, eventId);
    expect((await host.query(api.rolls.balance, {})).rolls).toBe(0);
    await host.mutation(api.hosting.deleteEvent, { eventId });
    await host.mutation(api.hosting.deleteEvent, { eventId });
    await t.finishAllScheduledFunctions(() => undefined);
    await drainStorageDeletions(t);
    await gone(keys);
    expect((await host.query(api.rolls.balance, {})).rolls).toBe(1);
    expect(await t.query(api.joining.preview, { code: joinCode })).toEqual({ status: "unavailable" });
    expect(await t.query(api.joining.standing, { eventId, guest: jo.guest })).toEqual({ event: "deleted", place: "none" });
    expect(await host.query(api.hosting.hosted, {})).toEqual([]);
    const left = await t.run(async (ctx) => ({
      pictures: await ctx.db.query("pictures").collect(),
      memberships: await ctx.db.query("memberships").collect(),
    }));
    expect(left).toEqual({ pictures: [], memberships: [] });
  });
});

describe("leaving and rejoining (V2-FR-56)", () => {
  test("a guest who leaves stops shooting, keeps their pictures and the album, and rejoins to their own Roll while open", async () => {
    const t = newBackend();
    const { host } = await newHost(t, "user_maya", "Maya");
    const { eventId, joinCode } = await loadFilm(host, { rolls: 1 });
    const jo = await joinAsGuest(t, joinCode, "Jo");
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    await t.mutation(api.joining.leave, { eventId, guestToken: jo.token });
    expect(await t.query(api.joining.preview, { code: joinCode, guest: jo.guest })).toMatchObject({ status: "open", place: "left" });
    // Every Roll is taken, but Jo comes back to her own.
    const back = await joinAsGuest(t, joinCode, "ignored", jo.guest);
    expect(back).toMatchObject({ guestName: "Jo", exposuresUsed: 1 });
    expect((await host.query(api.hosting.view, { eventId })).rolls).toMatchObject({ taken: 1 });
    // Not while joining is paused.
    await t.mutation(api.joining.leave, { eventId, guestToken: back.token });
    await host.mutation(api.hosting.setJoiningPaused, { eventId, paused: true });
    expect(await refusalCode(joinAsGuest(t, joinCode, "Jo", jo.guest))).toBe("joiningPaused");
    // After the reveal a guest who left still sees every picture.
    await reveal(t, eventId);
    expect(await readAddresses(t, { eventId, guestToken: await freshToken(t, eventId, jo.guest) })).toHaveLength(1);
  });
});

describe("Claim Guest Identity (V2-FR-04)", () => {
  test("the place, its exposures and pictures move to the Account, with nothing uploaded again", async () => {
    const { t, host, eventId, jo } = await eventWithGuests();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    await newHost(t, "user_jo", "Jo");
    const joAccount = signedIn(t, "user_jo");
    expect(await joAccount.mutation(api.identities.claim, { guest: jo.guest })).toEqual({ moved: [eventId], kept: [] });
    expect(await joAccount.mutation(api.identities.claim, { guest: jo.guest })).toEqual({ moved: [], kept: [] });
    // The Account acts for the place now, on any iPhone; the old guest token stops.
    expect(await refusalCode(t.query(api.joining.memberView, { eventId, guestToken: jo.token }))).toBe("guestTokenRefused");
    const view = await joAccount.query(api.joining.memberView, { eventId });
    expect(view).toMatchObject({ guestName: "Jo", exposuresUsed: 1, storedExposures: [1] });
    expect(await joAccount.query(api.joining.mine, {})).toEqual([expect.objectContaining({ guestName: "Jo", exposuresUsed: 1 })]);
    const file = await pictureFile(8 * 1024);
    expect(
      await refusalCode(
        joAccount.action(api.pictures.requestUpload, {
          eventId, exposureNumber: 1, captureTime: Date.now(), contentType: file.contentType, size: file.size, sha256: file.sha256,
        }),
      ),
    ).toBe("exposureTaken");
    await storePicture(joAccount, eventId, 2);
    expect((await host.query(api.hosting.view, { eventId })).guests.find((guest) => guest.name === "Jo")).toMatchObject({ exposuresUsed: 2 });
    // Another Account cannot claim it.
    await newHost(t, "user_other", "Other");
    expect(await refusalCode(signedIn(t, "user_other").mutation(api.identities.claim, { guest: jo.guest }))).toBe("identityClaimed");
  });

  test("an Account already in the same event keeps both places as they were, each with its own Roll", async () => {
    const { t, host, eventId, joinCode, jo } = await eventWithGuests();
    await newHost(t, "user_jo", "Jo");
    const joAccount = signedIn(t, "user_jo");
    await joAccount.mutation(api.joining.join, { code: joinCode, guestName: "Jo (Account)" });
    expect(await joAccount.mutation(api.identities.claim, { guest: jo.guest })).toEqual({ moved: [], kept: [eventId] });
    // The kept place still answers to the phone's secret.
    const token = await freshToken(t, eventId, jo.guest);
    await storePicture(t, eventId, 1, { guestToken: token });
    await storePicture(joAccount, eventId, 1);
    const names = (await host.query(api.hosting.view, { eventId })).guests.map((guest) => guest.name).sort();
    expect(names).toEqual(["Jo", "Jo (Account)", "Sam"]);
  });
});

describe("Delete Guest Identity (V2-FR-57)", () => {
  test("removes all its pictures from every event it joined, and the identity itself", async () => {
    const { t, host, eventId, jo } = await eventWithGuests();
    await t.run(async (ctx) => {
      const account = await ctx.db.query("accounts").first();
      await ctx.db.insert("rollLedger", { accountId: account!._id, kind: "free", freeGrant: "subscriber", rolls: 1, at: Date.now() });
    });
    const { eventId: second, joinCode: secondCode } = await loadFilm(host, { rolls: 1 });
    const joInSecond = await joinAsGuest(t, secondCode, "Jo", jo.guest);
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    await storePicture(t, second, 1, { guestToken: joInSecond.token });
    const keys = [...(await keysOf(t, eventId)), ...(await keysOf(t, second))];
    await t.mutation(api.identities.deleteGuestIdentity, { guest: jo.guest });
    await t.mutation(api.identities.deleteGuestIdentity, { guest: jo.guest });
    await drainStorageDeletions(t);
    await gone(keys);
    expect(await t.run((ctx) => ctx.db.query("guestIdentities").withIndex("by_public_id", (q) => q.eq("publicId", jo.guest.publicId)).unique())).toBeNull();
    expect((await host.query(api.hosting.view, { eventId })).guests.map((guest) => guest.name)).toEqual(["Sam"]);
  });
});
