// Delete Account (V2-FR-05, V2-FR-06, section 8, section 9.8): the server removes exactly what section 8 says,
// keeps a deleted Host's events running, keeps purchase records for accounting without the person, deletes the
// Clerk user, and every step repeats safely.
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { api, internal } from "../convex/_generated/api";
import type { Id } from "../convex/_generated/dataModel";
import { queueStorageDeletion } from "../convex/deletion";
import { readObject, storageConfig } from "../convex/lib/storage";
import { startClerkDouble } from "./support/clerk-double";
import {
  type Backend,
  drainStorageDeletions,
  everyRow,
  newBackend,
  newEvent,
  newGuest,
  newHost,
  pictureFile,
  put,
  randomId,
  refusalCode,
  signedIn,
  readAddresses,
} from "./support/convex";

let clerk: Awaited<ReturnType<typeof startClerkDouble>>;
beforeEach(async () => {
  clerk = await startClerkDouble();
});
afterEach(async () => {
  await clerk.close();
});

async function store(t: Backend, runner: { action: Backend["action"] }, eventId: Id<"events">, exposureNumber: number, guestToken?: string) {
  const file = await pictureFile(16 * 1024);
  const args = { eventId, exposureNumber, captureTime: Date.now(), contentType: file.contentType, size: file.size, sha256: file.sha256, guestToken };
  const address = await runner.action(api.pictures.requestUpload, args);
  if (address.status !== "upload") throw new Error("expected an address");
  await put(address, file.bytes);
  await runner.action(api.pictures.confirmUpload, { eventId, exposureNumber, guestToken });
}

// Maya hosts one event and shoots in it, shoots in Ana's event, and holds every kind of record section 8 names.
async function mayaWithEverything() {
  const t = newBackend();
  const { host: maya, accountId } = await newHost(t, "user_maya", "Maya");
  const { host: ana } = await newHost(t, "user_ana", "Ana");
  const mayasEvent = await newEvent(t, "user_maya");
  const anasEvent = await newEvent(t, "user_ana");
  // Maya joins Ana's event with her Account.
  await t.run((ctx) =>
    ctx.db.insert("memberships", { eventId: anasEvent, accountId, guestName: "Maya", exposuresUsed: 0, status: "joined", joinedAt: Date.now() }),
  );
  await store(t, maya, mayasEvent, 1);
  await store(t, maya, mayasEvent, 2);
  await store(t, maya, anasEvent, 1);
  // One picture still waiting to be confirmed.
  const waiting = await pictureFile(1024);
  await maya.action(api.pictures.requestUpload, {
    eventId: anasEvent,
    exposureNumber: 2,
    captureTime: Date.now(),
    contentType: waiting.contentType,
    size: waiting.size,
    sha256: waiting.sha256,
  });
  // A guest identity Maya used before signing in, now claimed into her Account, with a picture in Ana's event.
  const claimedGuest = await newGuest(t, anasEvent, "Maya on her old phone");
  await store(t, t, anasEvent, 1, claimedGuest.token);
  await t.run(async (ctx) => {
    const identity = await ctx.db.query("guestIdentities").withIndex("by_public_id", (q) => q.eq("publicId", claimedGuest.publicId)).unique();
    await ctx.db.patch(identity!._id, { accountId, claimedAt: Date.now() });
    await ctx.db.insert("pushTokens", { installationId: randomId(), token: "cd".repeat(32), environment: "sandbox", guestIdentityId: identity!._id, updatedAt: Date.now() });
  });
  // Ana's guest Jo, whose picture must stay.
  const jo = await newGuest(t, mayasEvent, "Jo");
  await store(t, t, mayasEvent, 1, jo.token);
  await maya.mutation(api.pushTokens.register, { installationId: randomId(), token: "ab".repeat(32), environment: "production" });
  await ana.mutation(api.pushTokens.register, { installationId: randomId(), token: "ef".repeat(32), environment: "production" });
  await t.run(async (ctx) => {
    await ctx.db.insert("subscriptionLinks", {
      accountId,
      originalTransactionId: "2000000000000001",
      environment: "Sandbox",
      linkedAt: Date.now(),
      rollsCredited: 20,
    });
    const token = (await ctx.db.get(accountId))!.appAccountToken!;
    await ctx.db.insert("purchases", {
      transactionId: "2000000000000002",
      originalTransactionId: "2000000000000002",
      productId: "test.rolls.pack",
      environment: "Sandbox",
      rolls: 10,
      appAccountToken: token,
      accountId,
      assignedAt: Date.now(),
      purchasedAt: Date.now(),
      revoked: false,
      stateSignedAt: Date.now(),
      firstSeenAt: Date.now(),
    });
    await ctx.db.insert("rollLedger", { accountId, kind: "free", rolls: 3, at: Date.now() });
    await ctx.db.insert("rollLedger", { accountId, kind: "purchase", rolls: 10, appleTransactionId: "2000000000000002", at: Date.now() });
    await ctx.db.insert("rollLedger", { accountId, kind: "setAside", rolls: -5, eventId: mayasEvent, at: Date.now() });
  });
  const mayasKeys = await t.run(async (ctx) => {
    const memberships = await ctx.db.query("memberships").collect();
    const mayas = new Set(memberships.filter((m) => m.accountId === accountId || m.guestName.startsWith("Maya")).map((m) => m._id));
    return (await ctx.db.query("pictures").collect()).filter((p) => mayas.has(p.membershipId)).map((p) => p.storageKey!);
  });
  return { t, maya, accountId, mayasEvent, anasEvent, claimedGuest, jo, mayasKeys };
}

describe("Delete Account", () => {
  test("removes everything that names the person, everywhere, and nothing else", async () => {
    const { t, maya, accountId, mayasEvent, anasEvent, claimedGuest, mayasKeys } = await mayaWithEverything();
    expect(mayasKeys.length).toBe(5);
    const purchaseToken = await t.run(async (ctx) => (await ctx.db.get(accountId))!.appAccountToken!);
    expect(await maya.action(api.deletion.deleteAccount, {})).toEqual({ deleted: true });
    await drainStorageDeletions(t);

    const rows = await everyRow(t);
    const text = JSON.stringify(rows);
    // Nothing names her: not her Account, her Clerk user, her claimed identity, or her names.
    expect(text).not.toContain(accountId);
    expect(text).not.toContain("user_maya");
    expect(text).not.toContain(claimedGuest.publicId);
    expect(text).not.toContain("Maya");
    expect(text).not.toContain(purchaseToken);
    // Her push tokens, her link to the subscription and non-purchase ledger rows are gone; the purchase stays, nameless,
    // and so does the record that the subscription's subscriber Rolls were given, without her.
    expect(rows.filter((r) => r.table === "pushTokens").map((r) => r.row.token)).toEqual(["ef".repeat(32)]);
    const links = rows.filter((r) => r.table === "subscriptionLinks").map((r) => r.row);
    expect(links).toHaveLength(1);
    expect(links[0]).toMatchObject({ originalTransactionId: "2000000000000001", rollsCredited: 20 });
    expect(links[0]!.accountId).toBeUndefined();
    expect(typeof links[0]!.accountDeletedAt).toBe("number");
    const purchases = rows.filter((r) => r.table === "purchases").map((r) => r.row);
    expect(purchases).toHaveLength(1);
    expect(purchases[0]).toMatchObject({ transactionId: "2000000000000002", rolls: 10 });
    expect(purchases[0]!.accountId).toBeUndefined();
    expect(purchases[0]!.appAccountToken).toBeUndefined();
    const ledger = rows.filter((r) => r.table === "rollLedger").map((r) => r.row);
    expect(ledger).toHaveLength(1);
    expect(ledger[0]).toMatchObject({ kind: "purchase", appleTransactionId: "2000000000000002" });
    expect(ledger[0]!.accountId).toBeUndefined();
    // Her pictures leave numbered gaps, keeping only their number and place in capture order; Jo's picture stays.
    const pictures = rows.filter((r) => r.table === "pictures").map((r) => r.row);
    const removed = pictures.filter((p) => p.state === "removed");
    expect(removed.map((p) => p.exposureNumber).sort()).toEqual([1, 1, 1, 2, 2]);
    for (const picture of removed) {
      expect(Object.keys(picture).sort()).toEqual(
        ["_creationTime", "_id", "captureTime", "eventId", "everStored", "exposureNumber", "membershipId", "removedAt", "removedBy", "requestedAt", "state"].sort(),
      );
      expect(picture.removedBy).toBe("deletion");
    }
    expect(pictures.filter((p) => p.state === "stored")).toHaveLength(1);
    // Her media is gone from storage.
    for (const key of mayasKeys) expect(await readObject(storageConfig(), key)).toBeNull();
    // Her event runs on with no Host (V2-FR-06); Ana's is untouched.
    const events = rows.filter((r) => r.table === "events").map((r) => r.row);
    const hers = events.find((e) => e._id === mayasEvent)!;
    expect(hers.hostAccountId).toBeUndefined();
    expect(hers.hostLeftAt).toBeTypeOf("number");
    expect(hers.state).toBe("open");
    expect(events.find((e) => e._id === anasEvent)!.hostAccountId).toBeDefined();
    // Clerk was asked once to delete the user, with the secret key.
    expect(clerk.requests).toEqual([{ method: "DELETE", path: "/v1/users/user_maya", authorization: `Bearer ${clerk.secretKey}` }]);
  });

  test("a deleted Host's event still takes pictures from its guests and reveals to them", async () => {
    const { t, maya, mayasEvent, jo } = await mayaWithEverything();
    await maya.action(api.deletion.deleteAccount, {});
    await store(t, t, mayasEvent, 2, jo.token);
    await t.mutation(internal.proofs.revealProofEvent, { eventId: mayasEvent });
    const album = await readAddresses(t, { eventId: mayasEvent, guestToken: jo.token });
    expect(album.map((p) => [p.shooterName, p.exposureNumber])).toEqual([
      ["Jo", 1],
      ["Jo", 2],
    ]);
  });

  test("repeating it changes nothing further", async () => {
    const { t, maya } = await mayaWithEverything();
    await maya.action(api.deletion.deleteAccount, {});
    const after = await everyRow(t);
    expect(await maya.action(api.deletion.deleteAccount, {})).toEqual({ deleted: true });
    expect(await everyRow(t)).toEqual(after);
    // Clerk may be asked again for the same user, which it answers as done.
    expect(new Set(clerk.requests.map((request) => request.path))).toEqual(new Set(["/v1/users/user_maya"]));
  });

  test("a person signed in with no Account yet still has their Clerk user deleted", async () => {
    const t = newBackend();
    const person = signedIn(t, "user_new");
    expect(await person.action(api.deletion.deleteAccount, {})).toEqual({ deleted: true });
    expect(clerk.requests).toEqual([{ method: "DELETE", path: "/v1/users/user_new", authorization: `Bearer ${clerk.secretKey}` }]);
    expect(await t.run((ctx) => ctx.db.query("clerkDeletions").collect())).toHaveLength(0);
  });

  test("when Clerk cannot be reached, the server's removal still completes, and Clerk is retried", async () => {
    const { t, maya, accountId } = await mayaWithEverything();
    clerk.answerWith(503);
    await expect(maya.action(api.deletion.deleteAccount, {})).rejects.toThrow(/Clerk could not delete/);
    expect(JSON.stringify(await everyRow(t)).includes(accountId)).toBe(false);
    // The same Clerk user cannot start a new Account while its deletion is pending.
    expect(await maya.query(api.accounts.me, {})).toEqual({ state: "accountDeleted" });
    expect(
      await refusalCode(maya.mutation(api.accounts.createAccount, { displayName: "Maya", ageConfirmed: true, ageConfirmation: "birthMonthAndYear" })),
    ).toBe("accountDeleted");
    const pending = await t.run((ctx) => ctx.db.query("clerkDeletions").collect());
    expect(pending).toMatchObject([{ clerkUserId: "user_maya", attempts: 1 }]);
    // The retry the server scheduled succeeds once Clerk answers.
    clerk.answerWith(200);
    await t.action(internal.clerk.deleteUser, { clerkUserId: "user_maya" });
    expect(await t.run((ctx) => ctx.db.query("clerkDeletions").collect())).toHaveLength(0);
    // Asking again from the app also succeeds.
    expect(await maya.action(api.deletion.deleteAccount, {})).toEqual({ deleted: true });
  });

  test("Clerk answering that the user is already gone counts as deleted", async () => {
    const { maya } = await mayaWithEverything();
    clerk.answerWith(404);
    expect(await maya.action(api.deletion.deleteAccount, {})).toEqual({ deleted: true });
  });

  test("signing in again makes a new, empty Account", async () => {
    const { t, maya } = await mayaWithEverything();
    await maya.action(api.deletion.deleteAccount, {});
    // Clerk gives the person a new user id when they sign up again.
    const again = signedIn(t, "user_maya_again");
    expect(await again.query(api.accounts.me, {})).toEqual({ state: "noAccount" });
    await again.mutation(api.accounts.createAccount, { displayName: "Maya", ageConfirmed: true, ageConfirmation: "birthMonthAndYear" });
    const accounts = await t.run((ctx) => ctx.db.query("accounts").collect());
    expect(accounts.map((a) => a.clerkUserId).sort()).toEqual(["user_ana", "user_maya_again"]);
  });

  test("an Account being deleted can do nothing else", async () => {
    const { t, maya, mayasEvent } = await mayaWithEverything();
    await t.run(async (ctx) => {
      const account = await ctx.db.query("accounts").withIndex("by_clerk_user", (q) => q.eq("clerkUserId", "user_maya")).unique();
      await ctx.db.patch(account!._id, { deletionRequestedAt: Date.now() });
    });
    expect(await refusalCode(readAddresses(maya, { eventId: mayasEvent }))).toBe("accountDeleted");
    expect(await refusalCode(maya.mutation(api.accounts.setDisplayName, { displayName: "X" }))).toBe("accountDeleted");
  });

  test("a deletion that stopped partway finishes when it runs again", async () => {
    const { t, maya, accountId } = await mayaWithEverything();
    // One batch, then the action is lost: the Account is marked and some rows may be left.
    await t.mutation(internal.deletion.deleteAccountBatch, { clerkUserId: "user_maya" });
    expect(await maya.action(api.deletion.deleteAccount, {})).toEqual({ deleted: true });
    expect(JSON.stringify(await everyRow(t)).includes(accountId)).toBe(false);
  });

  test("an Account with more records than one batch holds is removed whole", async () => {
    const t = newBackend();
    const { host, accountId } = await newHost(t, "user_busy", "Busy");
    const eventIds: Id<"events">[] = [];
    for (let index = 0; index < 70; index += 1) eventIds.push(await newEvent(t, "user_busy"));
    await t.run(async (ctx) => {
      for (const eventId of eventIds) {
        const membership = await ctx.db.query("memberships").withIndex("by_event_and_account", (q) => q.eq("eventId", eventId).eq("accountId", accountId)).unique();
        for (let exposure = 1; exposure <= 2; exposure += 1) {
          await ctx.db.insert("pictures", { eventId, membershipId: membership!._id, exposureNumber: exposure, state: "stored", storageKey: `pictures/${eventId}/${exposure}`, size: 1, sha256: "x", contentType: "image/jpeg", captureTime: 1, requestedAt: 1 });
        }
      }
    });
    expect(await host.action(api.deletion.deleteAccount, {})).toEqual({ deleted: true });
    const rows = await everyRow(t);
    expect(JSON.stringify(rows).includes(accountId)).toBe(false);
    expect(rows.filter((r) => r.table === "pictures" && r.row.state !== "removed")).toHaveLength(0);
    expect(rows.filter((r) => r.table === "storageDeletions")).toHaveLength(140);
  });
});

describe("The storage deletion queue", () => {
  async function pendingDrains(t: Backend) {
    const scheduled = await t.run((ctx) => ctx.db.system.query("_scheduled_functions").collect());
    return scheduled.filter((f) => f.name.includes("drain") && f.state.kind === "pending");
  }

  test("queueing many keys in one mutation starts one drain, and drains at once never take the same row", async () => {
    const t = newBackend();
    await t.run(async (ctx) => {
      for (let index = 0; index < 64; index += 1) await queueStorageDeletion(ctx, `pictures/many/${index}`, Date.now());
    });
    expect(await pendingDrains(t)).toHaveLength(1);
    const [first, second] = await Promise.all([
      t.mutation(internal.storageQueue.claim, {}),
      t.mutation(internal.storageQueue.claim, {}),
    ]);
    const claimed = [...first, ...second].map((row) => row.storageKey);
    expect(claimed).toHaveLength(64);
    expect(new Set(claimed).size).toBe(64);
    expect(await t.mutation(internal.storageQueue.claim, {})).toEqual([]);
  });

  test("keys still backing off after failures do not hold newer keys back", async () => {
    const t = newBackend();
    const later = Date.now() + 3_600_000;
    await t.run(async (ctx) => {
      for (let index = 0; index < 50; index += 1) {
        await ctx.db.insert("storageDeletions", { storageKey: `pictures/failing/${index}`, queuedAt: 1, attempts: 3, nextAttemptAt: later });
      }
      await queueStorageDeletion(ctx, "pictures/newer/1", Date.now());
    });
    await drainStorageDeletions(t);
    const left = await t.run((ctx) => ctx.db.query("storageDeletions").collect());
    expect(left).toHaveLength(50);
    expect(left.every((row) => row.storageKey.startsWith("pictures/failing/") && row.attempts === 3)).toBe(true);
  });
});
