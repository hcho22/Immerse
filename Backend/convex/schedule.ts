// The timed steps of an event (v2 PRD section 9.5, V2-FR-38): its opening at the Start Time, its end at the End Time,
// its reveal at End Time plus Reveal Delay, and the album's end 12 months later. Convex runs each scheduled mutation
// exactly once, whether or not anyone has the app open; each step checks the event's current state first, so a step
// run late, twice, or after the times moved changes nothing it should not. Who may do what never waits on these steps:
// lib/phase.ts reads the state from the times.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Doc, Id } from "./_generated/dataModel";
import { internalMutation, type MutationCtx } from "./_generated/server";
import { removePicture } from "./deletion";
import { GUEST_IDENTITY_MONTHS_AFTER_LAST_ALBUM } from "./lib/config";
import { scheduleSteps } from "./lib/events";
import { addMonths, albumEndsAt, phaseOf } from "./lib/phase";
import { settleUnclaimedRolls } from "./rolls";

// Rows each purge batch handles, well inside Convex's limits on one mutation.
const PURGE_BATCH = 100;

export const openEvent = internalMutation({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const event = await ctx.db.get(eventId);
    if (event === null || event.state !== "scheduled") return;
    if (phaseOf(event, Date.now()) === "scheduled") return;
    await ctx.db.patch(eventId, { state: "open" });
  },
});

// Shooting stops; unclaimed Rolls return to the Host's balance, or lapse in a deleted Host's event (V2-FR-28, V2-FR-06).
export async function endNow(ctx: MutationCtx, event: Doc<"events">, now: number) {
  await settleUnclaimedRolls(ctx, event, now);
  if (event.state === "scheduled" || event.state === "open") await ctx.db.patch(event._id, { state: "ended" });
}

export const endEvent = internalMutation({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const event = await ctx.db.get(eventId);
    if (event === null) return;
    const now = Date.now();
    const phase = phaseOf(event, now);
    if (phase !== "ended" && phase !== "revealed") return;
    await endNow(ctx, event, now);
  },
});

// The reveal (V2-FR-38): every picture on the server becomes visible to every member at once, the album's end is
// scheduled, and "Your Film is ready" goes out (V2-FR-70).
export async function revealNow(ctx: MutationCtx, eventId: Id<"events">, now: number) {
  const event = await ctx.db.get(eventId);
  if (event === null || event.state === "revealed" || event.state === "gone" || event.state === "deleted") return;
  await endNow(ctx, event, now);
  await ctx.db.patch(eventId, { state: "revealed", revealedAt: now, albumEndsAt: albumEndsAt(event) });
  await scheduleSteps(ctx, eventId, now);
  await ctx.scheduler.runAfter(0, internal.alerts.sendFilmReady, { eventId });
}

export const revealEvent = internalMutation({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const event = await ctx.db.get(eventId);
    if (event === null) return;
    const now = Date.now();
    if (phaseOf(event, now) !== "revealed") return;
    await revealNow(ctx, eventId, now);
  },
});

// Twelve months after the reveal the album ends (V2-FR-48): the event is gone, and its pictures and records go.
export const goneEvent = internalMutation({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const event = await ctx.db.get(eventId);
    if (event === null || event.state === "gone" || event.state === "deleted") return;
    if (phaseOf(event, Date.now()) !== "gone") return;
    await ctx.db.patch(eventId, { state: "gone", jobs: {} });
    await ctx.scheduler.runAfter(0, internal.schedule.purgeEvent, { eventId });
  },
});

// Removes what a gone or deleted event held, in batches (section 6.1's Gone and Deleted, section 8): every picture's
// media and row, every place and its name, every report and guest token. The event keeps a minimal record of its Rolls
// for the balance ledger, and its Join Codes' verifiers, so its link can say the event is no longer available. Each
// guest identity that took part is checked 12 months later and deleted if no other event holds it (section 8).
export const purgeEvent = internalMutation({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const event = await ctx.db.get(eventId);
    if (event === null || (event.state !== "gone" && event.state !== "deleted")) return;
    const now = Date.now();
    const pictures = await ctx.db
      .query("pictures")
      .withIndex("by_event", (q) => q.eq("eventId", eventId))
      .take(PURGE_BATCH);
    for (const picture of pictures) {
      await removePicture(ctx, picture, now, "deletion");
      await ctx.db.delete(picture._id);
    }
    if (pictures.length === PURGE_BATCH) {
      await ctx.scheduler.runAfter(0, internal.schedule.purgeEvent, { eventId });
      return;
    }
    const reports = await ctx.db
      .query("reports")
      .withIndex("by_event", (q) => q.eq("eventId", eventId))
      .take(PURGE_BATCH);
    for (const report of reports) await ctx.db.delete(report._id);
    if (reports.length === PURGE_BATCH) {
      await ctx.scheduler.runAfter(0, internal.schedule.purgeEvent, { eventId });
      return;
    }
    const sessions = await ctx.db
      .query("guestSessions")
      .withIndex("by_event", (q) => q.eq("eventId", eventId))
      .take(PURGE_BATCH);
    for (const session of sessions) await ctx.db.delete(session._id);
    if (sessions.length === PURGE_BATCH) {
      await ctx.scheduler.runAfter(0, internal.schedule.purgeEvent, { eventId });
      return;
    }
    const memberships = await ctx.db
      .query("memberships")
      .withIndex("by_event", (q) => q.eq("eventId", eventId))
      .take(PURGE_BATCH);
    const identityCheck = addMonths(now, GUEST_IDENTITY_MONTHS_AFTER_LAST_ALBUM);
    for (const membership of memberships) {
      if (membership.guestIdentityId !== undefined) {
        await ctx.scheduler.runAt(identityCheck, internal.guests.expireIdentity, {
          guestIdentityId: membership.guestIdentityId,
        });
      }
      await ctx.db.delete(membership._id);
    }
    if (memberships.length === PURGE_BATCH) {
      await ctx.scheduler.runAfter(0, internal.schedule.purgeEvent, { eventId });
      return;
    }
    // The minimal record: its Rolls, its Host for the ledger, and its states.
    await ctx.db.patch(eventId, { title: "" });
  },
});
