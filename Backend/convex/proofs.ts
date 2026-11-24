// Fixtures for the server proofs and the tests: a proof event an Account shoots in, a guest with no Account in it,
// removing that guest, and moving the event's End Time and reveal to now. They are internal functions, which no app or
// browser can call; they run only from the Convex dashboard, `npx convex run` with the deployment's key, or the tests.
// The app itself uses Load Film (`hosting:create`), joining (`joining:join`) and the timed reveal (schedule.ts); these
// reach the same code underneath.
import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
import { ensureGuestIdentity } from "./guests";
import { removeMember } from "./hosting";
import { DAY_MS } from "./lib/config";
import { insertEvent, scheduleSteps } from "./lib/events";
import { CameraPackageVersion } from "./lib/versions";
import { endNow, revealNow } from "./schedule";

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

// A Disposable proof event the Account hosts and holds a Roll in, open for seven days and revealing at its end. Its
// Rolls are set aside outside the balance, so a proof never spends a Host's free Rolls.
export const createProofEvent = internalMutation({
  args: { clerkUserId: v.string(), title: v.optional(v.string()), rolls: v.optional(v.number()) },
  handler: async (ctx, { clerkUserId, title, rolls }) => {
    const account = await ctx.db
      .query("accounts")
      .withIndex("by_clerk_user", (q) => q.eq("clerkUserId", clerkUserId))
      .unique();
    if (account === null) throw new Error("No Account for that Clerk user");
    const now = Date.now();
    const eventId = await insertEvent(
      ctx,
      {
        title: title ?? "Proof event",
        hostAccountId: account._id,
        camera: "disposable",
        treatmentVersion: CameraPackageVersion,
        rolls: rolls ?? 10,
        endsAt: now + 7 * DAY_MS,
        revealDelayMs: 0,
      },
      now,
    );
    await ctx.db.insert("memberships", {
      eventId,
      accountId: account._id,
      guestName: account.displayName,
      exposuresUsed: 0,
      status: "joined",
      joinedAt: now,
    });
    await ctx.db.patch(eventId, { rollsTaken: 1 });
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
    const event = (await ctx.db.get(eventId))!;
    await ctx.db.patch(eventId, { rollsTaken: event.rollsTaken + 1 });
    return { membershipId };
  },
});

// The Host's removal of a guest (V2-FR-53): their tokens end, their pictures go.
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
    if (membership !== null) await removeMember(ctx, membership, Date.now());
  },
});

// Ends shooting now, as the End Time would, with the reveal an hour or the Reveal Delay later, whichever is longer.
export const endProofEvent = internalMutation({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const event = await ctx.db.get(eventId);
    if (event === null || event.state === "revealed" || event.state === "gone" || event.state === "deleted") return;
    const now = Date.now();
    if (event.endsAt <= now) return;
    await ctx.db.patch(eventId, { endsAt: now, revealsAt: now + Math.max(event.revealDelayMs, 60 * 60_000) });
    await endNow(ctx, (await ctx.db.get(eventId))!, now);
    await scheduleSteps(ctx, eventId, now);
  },
});

// Reveals the event now, as the scheduled reveal would.
export const revealProofEvent = internalMutation({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const event = await ctx.db.get(eventId);
    if (event === null || event.state === "revealed" || event.state === "gone" || event.state === "deleted") return;
    const now = Date.now();
    await ctx.db.patch(eventId, { endsAt: Math.min(event.endsAt, now), revealsAt: now });
    await revealNow(ctx, eventId, now);
  },
});
