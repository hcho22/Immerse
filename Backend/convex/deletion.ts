// Delete Account (V2-FR-05, V2-FR-06, section 9.8), done on the server and safe to repeat.
//
// The app calls `deleteAccount`. The server then removes, in batches, everything section 8 holds that names the
// person: every picture they took in any event (its marker first, then its media), their Guest Names, the guest
// identities claimed into the Account and their tokens, their push tokens, their subscription link and their Roll
// ledger, keeping only purchase rows for accounting with the Account taken off them. Events they host carry on
// without a Host (V2-FR-06). Last, the Account itself goes, and the server deletes the Clerk user through Clerk's
// Backend API, so deletion never depends on the app finishing. Clerk's `user.deleted` webhook (http.ts) runs the
// same removal for a user deleted anywhere else. Every step checks the current state first, so repeating any of it,
// or running it twice at once, ends in the same state.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Doc, Id } from "./_generated/dataModel";
import { action, type ActionCtx, internalAction, internalMutation, type MutationCtx } from "./_generated/server";
import { refuse } from "./lib/errors";

// Rows each batch handles per kind of record, well inside Convex's limits on one mutation.
const BATCH = 64;

// Removes a picture's media and keeps its number: the row keeps its event, shooter and exposure number, so the
// album shows a numbered gap and a late or repeated upload of the same exposure is refused (section 9.8).
export async function removePicture(ctx: MutationCtx, picture: Doc<"pictures">, now: number) {
  if (picture.state === "removed") return;
  const storageKey = picture.storageKey;
  await ctx.db.patch(picture._id, {
    state: "removed",
    removedAt: now,
    captureTime: undefined,
    contentType: undefined,
    size: undefined,
    sha256: undefined,
    storageKey: undefined,
    storedAt: undefined,
  });
  if (storageKey !== undefined) await queueStorageDeletion(ctx, storageKey, now);
}

export async function queueStorageDeletion(ctx: MutationCtx, storageKey: string, now: number) {
  const queued = await ctx.db
    .query("storageDeletions")
    .withIndex("by_storage_key", (q) => q.eq("storageKey", storageKey))
    .unique();
  if (queued === null) await ctx.db.insert("storageDeletions", { storageKey, queuedAt: now, attempts: 0 });
  await ctx.scheduler.runAfter(0, internal.storageQueue.drain, {});
}

// Removes a shooter's pictures and their name, keeping the membership row with no person on it as the marker that
// their exposures are gone. Returns false when it stopped at the batch limit.
async function removeShooter(ctx: MutationCtx, membership: Doc<"memberships">, now: number): Promise<boolean> {
  const pictures = await ctx.db
    .query("pictures")
    .withIndex("by_shooter_and_exposure", (q) => q.eq("membershipId", membership._id))
    .filter((q) => q.neq(q.field("state"), "removed"))
    .take(BATCH);
  for (const picture of pictures) await removePicture(ctx, picture, now);
  if (pictures.length === BATCH) return false;
  await ctx.db.patch(membership._id, {
    status: "deleted",
    guestName: "",
    accountId: undefined,
    guestIdentityId: undefined,
  });
  return true;
}

// One batch of an Account's removal. Returns `done` once nothing that names the person is left.
export const deleteAccountBatch = internalMutation({
  args: { clerkUserId: v.string() },
  handler: async (ctx, { clerkUserId }): Promise<{ done: boolean }> => {
    const now = Date.now();
    const account = await ctx.db
      .query("accounts")
      .withIndex("by_clerk_user", (q) => q.eq("clerkUserId", clerkUserId))
      .unique();
    if (account === null) return { done: true };
    if (account.deletionRequestedAt === undefined) {
      // From here on the Account can do nothing but finish its deletion (requireAccount refuses it).
      await ctx.db.patch(account._id, { deletionRequestedAt: now });
    }
    const pendingClerkDeletion = await ctx.db
      .query("clerkDeletions")
      .withIndex("by_clerk_user", (q) => q.eq("clerkUserId", clerkUserId))
      .unique();
    if (pendingClerkDeletion === null) {
      await ctx.db.insert("clerkDeletions", { clerkUserId, requestedAt: now, attempts: 0 });
    }

    // The guest identities claimed into the Account act as the Account does (V2-FR-04), so their places go too.
    const claimed = await ctx.db
      .query("guestIdentities")
      .withIndex("by_account", (q) => q.eq("accountId", account._id))
      .take(BATCH);
    const owners: Array<{ accountId: Id<"accounts"> } | { guestIdentityId: Id<"guestIdentities"> }> = [
      { accountId: account._id },
      ...claimed.map((identity) => ({ guestIdentityId: identity._id })),
    ];

    // 1. Pictures and names, everywhere, sealed or revealed.
    for (const owner of owners) {
      const memberships =
        "accountId" in owner
          ? await ctx.db
              .query("memberships")
              .withIndex("by_account", (q) => q.eq("accountId", owner.accountId))
              .take(BATCH)
          : await ctx.db
              .query("memberships")
              .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", owner.guestIdentityId))
              .take(BATCH);
      for (const membership of memberships) {
        if (!(await removeShooter(ctx, membership, now))) return { done: false };
      }
      if (memberships.length === BATCH) return { done: false };
    }

    // 2. Events they host run on to their reveal with no Host (V2-FR-06).
    const hosted = await ctx.db
      .query("events")
      .withIndex("by_host", (q) => q.eq("hostAccountId", account._id))
      .take(BATCH);
    for (const event of hosted) await ctx.db.patch(event._id, { hostAccountId: undefined, hostLeftAt: now });
    if (hosted.length === BATCH) return { done: false };

    // 3. Push tokens, of the Account and of its claimed identities.
    for (const owner of owners) {
      const tokens =
        "accountId" in owner
          ? await ctx.db
              .query("pushTokens")
              .withIndex("by_account", (q) => q.eq("accountId", owner.accountId))
              .take(BATCH)
          : await ctx.db
              .query("pushTokens")
              .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", owner.guestIdentityId))
              .take(BATCH);
      for (const token of tokens) await ctx.db.delete(token._id);
      if (tokens.length === BATCH) return { done: false };
    }

    // 4. The claimed guest identities and their tokens.
    for (const identity of claimed) {
      const sessions = await ctx.db
        .query("guestSessions")
        .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", identity._id))
        .take(BATCH);
      for (const session of sessions) await ctx.db.delete(session._id);
      if (sessions.length === BATCH) return { done: false };
      await ctx.db.delete(identity._id);
    }
    if (claimed.length === BATCH) return { done: false };

    // 5. The subscription link.
    const links = await ctx.db
      .query("subscriptionLinks")
      .withIndex("by_account", (q) => q.eq("accountId", account._id))
      .take(BATCH);
    for (const link of links) await ctx.db.delete(link._id);
    if (links.length === BATCH) return { done: false };

    // 6. The Roll ledger: Apple's purchase, refund and reversal rows stay for accounting with no Account on them;
    // every other row goes, and so do the Rolls in the balance.
    const ledger = await ctx.db
      .query("rollLedger")
      .withIndex("by_account", (q) => q.eq("accountId", account._id))
      .take(BATCH);
    for (const row of ledger) {
      if (row.appleTransactionId !== undefined) await ctx.db.patch(row._id, { accountId: undefined });
      else await ctx.db.delete(row._id);
    }
    if (ledger.length === BATCH) return { done: false };

    // 7. The Account.
    await ctx.db.delete(account._id);
    return { done: true };
  },
});

async function removeEverything(ctx: Pick<ActionCtx, "runMutation">, clerkUserId: string) {
  for (;;) {
    const { done } = await ctx.runMutation(internal.deletion.deleteAccountBatch, { clerkUserId });
    if (done) return;
  }
}

// Delete Account, for the signed-in person. Returns once the server holds nothing that names them and Clerk has
// deleted the user. When Clerk cannot be reached it throws after the server's own removal; the server keeps
// retrying Clerk's deletion, and the app may simply ask again.
export const deleteAccount = action({
  args: {},
  handler: async (ctx): Promise<{ deleted: true }> => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) refuse("unauthenticated");
    await removeEverything(ctx, identity.subject);
    const clerk = await ctx.runAction(internal.clerk.deleteUser, { clerkUserId: identity.subject });
    if (!clerk.deleted) throw new Error("Clerk could not delete the user yet; the server will keep trying");
    return { deleted: true };
  },
});

// Clerk deleted the user (its `user.deleted` webhook): remove what the server holds, and stop asking Clerk.
export const userDeletedAtClerk = internalAction({
  args: { clerkUserId: v.string() },
  handler: async (ctx, { clerkUserId }) => {
    await removeEverything(ctx, clerkUserId);
    await ctx.runMutation(internal.clerk.forgetDeletion, { clerkUserId });
  },
});
