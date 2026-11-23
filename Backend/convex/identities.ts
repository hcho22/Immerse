// The guest identity's two lasting changes (v2 PRD V2-FR-04, V2-FR-57): claiming it into an Account, so its places and
// pictures follow the person to any iPhone they sign in on, and deleting it, which removes all its pictures from every
// event it joined, as Delete Account does for an Account.
import { v } from "convex/values";
import { mutation } from "./_generated/server";
import { endSessionsIn } from "./guests";
import { removeShooter } from "./deletion";
import { guestCredentials, identityForCredentials, requireAccount } from "./lib/callers";
import { refuse } from "./lib/errors";

// Claim Guest Identity (V2-FR-04): the signed-in person takes over the phone's guest identity. Each place it holds moves
// to the Account, with its Roll, remaining exposures, name and pictures, and acts through the Account from then on;
// nothing is uploaded again. Where the Account already holds a place in the same event, both places stay as they were,
// each with its own Roll and pictures, and that one keeps answering to the phone's secret. Claiming never moves a place
// to another event or merges two. Repeating it changes nothing further; an identity claimed into another Account is
// refused.
export const claim = mutation({
  args: { guest: guestCredentials },
  handler: async (ctx, { guest }) => {
    const account = await requireAccount(ctx);
    const identity = await identityForCredentials(ctx, guest);
    if (identity === null) refuse("guestTokenRefused");
    if (identity.accountId !== undefined && identity.accountId !== account._id) refuse("identityClaimed");
    const now = Date.now();
    const moved: string[] = [];
    const kept: string[] = [];
    for (const membership of await ctx.db
      .query("memberships")
      .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", identity._id))
      .collect()) {
      const accountPlace = await ctx.db
        .query("memberships")
        .withIndex("by_event_and_account", (q) => q.eq("eventId", membership.eventId).eq("accountId", account._id))
        .unique();
      if (accountPlace !== null) {
        kept.push(membership.eventId);
        continue;
      }
      await ctx.db.patch(membership._id, { accountId: account._id, guestIdentityId: undefined });
      await endSessionsIn(ctx, identity._id, membership.eventId);
      moved.push(membership.eventId);
    }
    if (identity.accountId === undefined) await ctx.db.patch(identity._id, { accountId: account._id, claimedAt: now });
    return { moved, kept };
  },
});

// Delete Guest Identity (V2-FR-57): a guest who never signed in removes every picture of theirs from every event the
// identity joined, each leaving a numbered gap, and the identity itself, its tokens and its push token. The phone
// deletes what waits on it and the Instant prints it keeps. A claimed identity is deleted with its Account instead.
export const deleteGuestIdentity = mutation({
  args: { guest: guestCredentials },
  handler: async (ctx, { guest }) => {
    const identity = await identityForCredentials(ctx, guest);
    if (identity === null) return { deleted: true };
    if (identity.accountId !== undefined) refuse("identityClaimed");
    const now = Date.now();
    for (const membership of await ctx.db
      .query("memberships")
      .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", identity._id))
      .collect()) {
      // A guest identity holds at most one Roll per event, of at most 27 exposures, so one pass removes them all.
      await removeShooter(ctx, membership, now);
    }
    for (const session of await ctx.db
      .query("guestSessions")
      .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", identity._id))
      .collect()) {
      await ctx.db.delete(session._id);
    }
    for (const row of await ctx.db
      .query("pushTokens")
      .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", identity._id))
      .collect()) {
      if (row.accountId === undefined) await ctx.db.delete(row._id);
      else await ctx.db.patch(row._id, { guestIdentityId: undefined });
    }
    await ctx.db.delete(identity._id);
    return { deleted: true };
  },
});
