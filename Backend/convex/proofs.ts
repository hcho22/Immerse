// Fixtures for Stage 1's proofs, before Stage 2 builds Load Film and joining: a proof event an Account shoots in,
// a guest with no Account in it, and the reveal. They are internal functions, which no app or browser can call;
// they run only from the Convex dashboard, `npx convex run` with the deployment's key, or the tests. Stage 2
// replaces them with Load Film, Join and the timed reveal.
import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
import { ensureGuestIdentity } from "./guests";
import { removePicture } from "./deletion";

const DAY_MS = 24 * 60 * 60 * 1000;

// An Account's id, for running the push test against it (`push:sendTestAlert`).
export const accountIdForClerkUser = internalQuery({
  args: { clerkUserId: v.string() },
  handler: async (ctx, { clerkUserId }) => {
    const account = await ctx.db
      .query("accounts")
      .withIndex("by_clerk_user", (q) => q.eq("clerkUserId", clerkUserId))
      .unique();
    return account?._id ?? null;
  },
});

// A Disposable proof event the Account hosts and holds a Roll in, open for seven days and revealing at its end.
export const createProofEvent = internalMutation({
  args: { clerkUserId: v.string(), title: v.optional(v.string()) },
  handler: async (ctx, { clerkUserId, title }) => {
    const account = await ctx.db
      .query("accounts")
      .withIndex("by_clerk_user", (q) => q.eq("clerkUserId", clerkUserId))
      .unique();
    if (account === null) throw new Error("No Account for that Clerk user");
    const now = Date.now();
    const endsAt = now + 7 * DAY_MS;
    const eventId = await ctx.db.insert("events", {
      title: title ?? "Stage 1 proof",
      hostAccountId: account._id,
      camera: "disposable",
      exposuresPerRoll: 27,
      endsAt,
      revealsAt: endsAt,
      state: "open",
      createdAt: now,
    });
    await ctx.db.insert("memberships", {
      eventId,
      accountId: account._id,
      guestName: account.displayName,
      exposuresUsed: 0,
      status: "joined",
      joinedAt: now,
    });
    return { eventId };
  },
});

// A guest with no Account, holding a Roll in the event under a Guest Name.
export const addProofGuest = internalMutation({
  args: { eventId: v.id("events"), publicId: v.string(), secret: v.string(), guestName: v.string() },
  handler: async (ctx, { eventId, publicId, secret, guestName }) => {
    const guestIdentityId = await ensureGuestIdentity(ctx, publicId, secret);
    const existing = await ctx.db
      .query("memberships")
      .withIndex("by_event_and_guest_identity", (q) => q.eq("eventId", eventId).eq("guestIdentityId", guestIdentityId))
      .unique();
    if (existing !== null) return { membershipId: existing._id };
    const membershipId = await ctx.db.insert("memberships", {
      eventId,
      guestIdentityId,
      guestName,
      exposuresUsed: 0,
      status: "joined",
      joinedAt: Date.now(),
    });
    return { membershipId };
  },
});

// The Host's removal of a guest, as Stage 2 will build it (V2-FR-53): their tokens end, their pictures go.
export const removeProofGuest = internalMutation({
  args: { eventId: v.id("events"), publicId: v.string() },
  handler: async (ctx, { eventId, publicId }) => {
    const identity = await ctx.db
      .query("guestIdentities")
      .withIndex("by_public_id", (q) => q.eq("publicId", publicId))
      .unique();
    if (identity === null) return;
    const membership = await ctx.db
      .query("memberships")
      .withIndex("by_event_and_guest_identity", (q) => q.eq("eventId", eventId).eq("guestIdentityId", identity._id))
      .unique();
    if (membership === null) return;
    const now = Date.now();
    for (const session of await ctx.db
      .query("guestSessions")
      .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", identity._id))
      .collect()) {
      if (session.eventId === eventId) await ctx.db.delete(session._id);
    }
    for (const picture of await ctx.db
      .query("pictures")
      .withIndex("by_shooter_and_exposure", (q) => q.eq("membershipId", membership._id))
      .collect()) {
      await removePicture(ctx, picture, now);
    }
    await ctx.db.patch(membership._id, { status: "removed" });
  },
});

// Ends shooting now, as the End Time would.
export const endProofEvent = internalMutation({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const event = await ctx.db.get(eventId);
    if (event === null || event.state !== "open") return;
    const now = Date.now();
    await ctx.db.patch(eventId, { state: "ended", endsAt: Math.min(event.endsAt, now) });
  },
});

// Reveals the event now, as the scheduled reveal will.
export const revealProofEvent = internalMutation({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const event = await ctx.db.get(eventId);
    if (event === null || event.state === "revealed" || event.state === "gone" || event.state === "deleted") return;
    const now = Date.now();
    await ctx.db.patch(eventId, { state: "revealed", endsAt: Math.min(event.endsAt, now), revealsAt: now });
  },
});
