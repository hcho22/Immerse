// The Host's side of a Group Film (v2 PRD sections 5.2 to 5.5 and 5.9): Load Film, the event's settings before and
// after it opens, the Join Code, adding Rolls, ending early, renaming, deleting the event, removing a guest or a
// picture, and the Host's view of counts, never pictures, before the reveal.
//
// Every function resolves the caller on the server and refuses anyone but the event's Host; a deleted Host's event has
// none, so nobody can change it (V2-FR-06). Every change can be repeated safely (V2-FR-81): Load Film and adding Rolls
// carry the app's request id, and every other change sets a state rather than stepping it.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Doc, Id } from "./_generated/dataModel";
import { mutation, query, type MutationCtx, type QueryCtx } from "./_generated/server";
import { endSessionsIn } from "./guests";
import { removePicture } from "./deletion";
import { requireAccount } from "./lib/callers";
import { MAX_ROLLS_PER_EVENT, REPORT_KEPT_AFTER_RESOLUTION_MS } from "./lib/config";
import { refuse } from "./lib/errors";
import {
  checkFilmStock,
  checkRequestId,
  checkRolls,
  checkTimes,
  checkTreatmentVersion,
  cleanFilmTitle,
  currentJoinCode,
  eventSummary,
  insertEvent,
  scheduleSteps,
  stopSteps,
} from "./lib/events";
import { joinCodeFor, joinCodeVerifier } from "./lib/joinCode";
import { isBeforeEnd, isLive, opensAt, phaseOf } from "./lib/phase";
import { cameraValidator, filmStockValidator } from "./schema";
import { balanceOf, ensureFreeRolls, setAside, settleUnclaimedRolls } from "./rolls";
import { revealNow } from "./schedule";

// The event, when the signed-in caller is its Host.
async function hostedEvent(ctx: QueryCtx, eventId: Id<"events">) {
  const account = await requireAccount(ctx);
  const event = await ctx.db.get(eventId);
  if (event === null || event.hostAccountId === undefined || event.hostAccountId !== account._id) refuse("notTheHost");
  return { account, event };
}

// Load Film (V2-FR-13): makes the event, sets its Rolls aside from the balance, fixes its Camera and Film Stock for
// good, and issues its Join Code at once, also for an event that opens later at its Start Time. A repeated request with
// the same request id returns the same event.
export const create = mutation({
  args: {
    requestId: v.string(),
    title: v.string(),
    camera: cameraValidator,
    filmStock: v.optional(filmStockValidator),
    rolls: v.number(),
    startsAt: v.optional(v.number()),
    endsAt: v.number(),
    revealDelayMs: v.number(),
    treatmentVersion: v.string(),
  },
  handler: async (ctx, args) => {
    const account = await requireAccount(ctx);
    checkRequestId(args.requestId);
    const repeated = await ctx.db
      .query("events")
      .withIndex("by_host_and_request", (q) => q.eq("hostAccountId", account._id).eq("createRequestId", args.requestId))
      .unique();
    if (repeated !== null) return { eventId: repeated._id, joinCode: await currentJoinCode(repeated) };
    const now = Date.now();
    const title = cleanFilmTitle(args.title);
    checkFilmStock(args.camera, args.filmStock);
    checkRolls(args.rolls);
    checkTreatmentVersion(args.treatmentVersion);
    if (args.startsAt !== undefined && (!Number.isFinite(args.startsAt) || args.startsAt <= now)) {
      refuse("invalid", "The Start Time is in the past");
    }
    checkTimes({ opensAt: args.startsAt ?? now, endsAt: args.endsAt, revealDelayMs: args.revealDelayMs }, now);
    await ensureFreeRolls(ctx, account._id, now);
    const balance = await balanceOf(ctx, account._id);
    if (balance < args.rolls) refuse("balanceTooLow", `The balance holds ${Math.max(0, balance)} Rolls`);
    const eventId = await insertEvent(
      ctx,
      {
        title,
        hostAccountId: account._id,
        camera: args.camera,
        filmStock: args.filmStock,
        treatmentVersion: args.treatmentVersion,
        rolls: args.rolls,
        startsAt: args.startsAt,
        endsAt: args.endsAt,
        revealDelayMs: args.revealDelayMs,
        createRequestId: args.requestId,
      },
      now,
    );
    await setAside(ctx, account._id, eventId, args.rolls, now);
    const event = (await ctx.db.get(eventId))!;
    return { eventId, joinCode: await currentJoinCode(event) };
  },
});

// The Host's view (V2-FR-29): the event's settings, its Join Code while it can still be used, how many Rolls are taken
// and free, each guest's name and exposures used, how many pictures have arrived, and the reports about its pictures
// without their reporters (V2-FR-54). Never a picture or its thumbnail before the reveal.
export const view = query({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const { event } = await hostedEvent(ctx, eventId);
    const now = Date.now();
    const summary = await eventSummary(ctx, event, now);
    if (!isLive(summary.phase)) {
      return { ...summary, joinCode: null, joinCodeGeneration: null, rolls: null, picturesArrived: 0, guests: [], reports: [] };
    }
    const memberships = await ctx.db
      .query("memberships")
      .withIndex("by_event", (q) => q.eq("eventId", eventId))
      .collect();
    const stored = await ctx.db
      .query("pictures")
      .withIndex("by_event_and_state", (q) => q.eq("eventId", eventId).eq("state", "stored"))
      .collect();
    const reports = await ctx.db
      .query("reports")
      .withIndex("by_event", (q) => q.eq("eventId", eventId))
      .collect();
    return {
      ...summary,
      // After the End Time the same link leads members to the album (V2-FR-15).
      joinCode: await currentJoinCode(event),
      joinCodeGeneration: event.joinCodeGeneration,
      rolls: {
        setAside: event.rollsSetAside,
        taken: event.rollsTaken,
        free: event.rollsSettledAt === undefined ? Math.max(0, event.rollsSetAside - event.rollsTaken) : 0,
        limit: MAX_ROLLS_PER_EVENT,
      },
      picturesArrived: stored.length,
      guests: memberships
        .filter((membership) => membership.status !== "deleted")
        .map((membership) => ({
          membershipId: membership._id,
          name: membership.guestName,
          exposuresUsed: membership.exposuresUsed,
          status: membership.status,
          isHost: membership.accountId !== undefined && membership.accountId === event.hostAccountId,
        })),
      reports: reports
        .filter((report) => report.resolvedAt === undefined)
        .map((report) => ({ reportId: report._id, pictureId: report.pictureId, reason: report.reason, at: report.at })),
    };
  },
});

// The events the signed-in person hosts, for the Film Library; the events they joined are `joining:mine`.
export const hosted = query({
  args: {},
  handler: async (ctx) => {
    const account = await requireAccount(ctx);
    const now = Date.now();
    const events = await ctx.db
      .query("events")
      .withIndex("by_host", (q) => q.eq("hostAccountId", account._id))
      .collect();
    const live = events.filter((event) => isLive(phaseOf(event, now)));
    return Promise.all(live.map((event) => eventSummary(ctx, event, now)));
  },
});

// Moves the Start Time until the event opens, and the End Time and Reveal Delay until the End Time, within V2-FR-12's
// limits; the scheduled steps move with them. A Start Time of null opens the event now. Moving the End Time to now is
// ending early, which is `endEarly`.
export const updateTimes = mutation({
  args: {
    eventId: v.id("events"),
    startsAt: v.optional(v.union(v.number(), v.null())),
    endsAt: v.optional(v.number()),
    revealDelayMs: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { event } = await hostedEvent(ctx, args.eventId);
    const now = Date.now();
    const phase = phaseOf(event, now);
    if (!isBeforeEnd(phase)) refuse("shootingEnded");
    let startsAt = event.startsAt;
    if (args.startsAt !== undefined) {
      if (phase !== "scheduled") {
        if (args.startsAt !== null && args.startsAt !== event.startsAt) {
          refuse("invalid", "The event has opened; its Start Time cannot move");
        }
      } else if (args.startsAt === null) {
        // Clearing the Start Time opens the event now, and its 7 days count from now.
        startsAt = now;
      } else {
        if (!Number.isFinite(args.startsAt) || args.startsAt <= now) refuse("invalid", "The Start Time is in the past");
        startsAt = args.startsAt;
      }
    }
    const endsAt = args.endsAt ?? event.endsAt;
    const revealDelayMs = args.revealDelayMs ?? event.revealDelayMs;
    checkTimes({ opensAt: startsAt ?? opensAt(event), endsAt, revealDelayMs }, now);
    const opensNow = event.state === "scheduled" && startsAt !== undefined && startsAt <= now;
    await ctx.db.patch(event._id, {
      startsAt,
      endsAt,
      revealDelayMs,
      revealsAt: endsAt + revealDelayMs,
      state: opensNow ? "open" : event.state,
    });
    await scheduleSteps(ctx, event._id, now);
    return { ok: true };
  },
});

// Pauses or resumes joining while the event is scheduled or open (V2-FR-16). A pause made before the Start Time holds
// when the event opens.
export const setJoiningPaused = mutation({
  args: { eventId: v.id("events"), paused: v.boolean() },
  handler: async (ctx, { eventId, paused }) => {
    const { event } = await hostedEvent(ctx, eventId);
    if (!isBeforeEnd(phaseOf(event, Date.now()))) refuse("shootingEnded");
    if (event.joiningPaused !== paused) await ctx.db.patch(eventId, { joiningPaused: paused });
    return { paused };
  },
});

// Replaces the Join Code behind the app's warning (V2-FR-17): the old link and every printed copy stop working at once
// and for good; nobody who joined is affected. Returns the new code. Each call replaces the code once more.
export const replaceJoinCode = mutation({
  args: { eventId: v.id("events"), generation: v.number() },
  handler: async (ctx, { eventId, generation }) => {
    const { event } = await hostedEvent(ctx, eventId);
    if (!isBeforeEnd(phaseOf(event, Date.now()))) refuse("shootingEnded");
    // The app names the code it saw, so a repeated request replaces it once (V2-FR-81).
    if (generation !== event.joinCodeGeneration) return { joinCode: await currentJoinCode(event), generation: event.joinCodeGeneration };
    const now = Date.now();
    for (const row of await ctx.db
      .query("joinCodes")
      .withIndex("by_event", (q) => q.eq("eventId", eventId))
      .collect()) {
      if (row.retiredAt === undefined) await ctx.db.patch(row._id, { retiredAt: now });
    }
    const next = event.joinCodeGeneration + 1;
    const joinCode = await joinCodeFor(eventId, next);
    await ctx.db.insert("joinCodes", { eventId, verifier: await joinCodeVerifier(joinCode), generation: next });
    await ctx.db.patch(eventId, { joinCodeGeneration: next });
    return { joinCode, generation: next };
  },
});

// Adds Rolls from the balance while the event is scheduled or open, up to 200 in its life (V2-FR-26, V2-FR-27). New
// guests can take them at once. A repeated request with the same request id adds them once.
export const addRolls = mutation({
  args: { eventId: v.id("events"), rolls: v.number(), requestId: v.string() },
  handler: async (ctx, { eventId, rolls, requestId }) => {
    const { account, event } = await hostedEvent(ctx, eventId);
    checkRequestId(requestId);
    const repeated = await ctx.db
      .query("rollLedger")
      .withIndex("by_account_and_request", (q) => q.eq("accountId", account._id).eq("requestId", requestId))
      .unique();
    if (repeated !== null) return { rollsSetAside: event.rollsSetAside };
    const now = Date.now();
    if (!isBeforeEnd(phaseOf(event, now))) refuse("shootingEnded");
    checkRolls(rolls);
    if (event.rollsSetAside + rolls > MAX_ROLLS_PER_EVENT) {
      refuse("rollLimit", `An event has at most ${MAX_ROLLS_PER_EVENT} Rolls`);
    }
    await ensureFreeRolls(ctx, account._id, now);
    const balance = await balanceOf(ctx, account._id);
    if (balance < rolls) refuse("balanceTooLow", `The balance holds ${Math.max(0, balance)} Rolls`);
    await setAside(ctx, account._id, eventId, rolls, now, requestId);
    await ctx.db.patch(eventId, { rollsSetAside: event.rollsSetAside + rolls });
    return { rollsSetAside: event.rollsSetAside + rolls };
  },
});

// Ends the event early (V2-FR-40): now becomes the End Time, shooting stops for everyone, unclaimed Rolls return, and
// the album reveals at once whatever Reveal Delay was chosen. Repeating it changes nothing further.
export const endEarly = mutation({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const { event } = await hostedEvent(ctx, eventId);
    const now = Date.now();
    const phase = phaseOf(event, now);
    if (phase === "revealed") return { revealedAt: event.revealsAt };
    if (phase !== "open") refuse(phase === "scheduled" ? "notYetOpen" : "shootingEnded");
    await ctx.db.patch(eventId, { endsAt: now, revealsAt: now });
    await revealNow(ctx, eventId, now);
    return { revealedAt: now };
  },
});

// Changes the Film Title until the album ends (V2-FR-14).
export const rename = mutation({
  args: { eventId: v.id("events"), title: v.string() },
  handler: async (ctx, { eventId, title }) => {
    const { event } = await hostedEvent(ctx, eventId);
    if (!isLive(phaseOf(event, Date.now()))) refuse("eventGone");
    const cleaned = cleanFilmTitle(title);
    if (cleaned !== event.title) await ctx.db.patch(eventId, { title: cleaned });
    return { title: cleaned };
  },
});

// Deletes the whole event after the app's warning (V2-FR-55): every picture and the web album go for everyone, the
// link says the event is no longer available, the event leaves every Film Library, and unclaimed Rolls return when it
// is deleted before its End Time. Phones learn of it when they next come online and delete what they keep for it.
export const deleteEvent = mutation({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const { event } = await hostedEvent(ctx, eventId);
    const now = Date.now();
    if (event.state === "deleted") return { deleted: true };
    if (!isLive(phaseOf(event, now))) refuse("eventGone");
    await settleUnclaimedRolls(ctx, event, now);
    await stopSteps(ctx, event);
    await ctx.db.patch(eventId, { state: "deleted", deletedAt: now, webAlbumOn: false });
    await ctx.scheduler.runAfter(0, internal.schedule.purgeEvent, { eventId });
    return { deleted: true };
  },
});

// Removes a guest's pictures and their access to the event, for good (V2-FR-53): their pictures go with them, their
// tokens end, and any picture of theirs that arrives later is refused. Their Roll stays used (V2-FR-28).
export async function removeMember(ctx: MutationCtx, membership: Doc<"memberships">, now: number) {
  if (membership.status === "removed" || membership.status === "deleted") return;
  for (const picture of await ctx.db
    .query("pictures")
    .withIndex("by_shooter_and_exposure", (q) => q.eq("membershipId", membership._id))
    .collect()) {
    await removePicture(ctx, picture, now, "guestRemoved");
  }
  if (membership.guestIdentityId !== undefined) await endSessionsIn(ctx, membership.guestIdentityId, membership.eventId);
  await ctx.db.patch(membership._id, { status: "removed", removedAt: now });
}

// The Host removes a guest while the event is open, awaiting its reveal, or revealed (V2-FR-53).
export const removeGuest = mutation({
  args: { eventId: v.id("events"), membershipId: v.id("memberships") },
  handler: async (ctx, { eventId, membershipId }) => {
    const { event } = await hostedEvent(ctx, eventId);
    const now = Date.now();
    const phase = phaseOf(event, now);
    if (!isLive(phase)) refuse("eventGone");
    const membership = await ctx.db.get(membershipId);
    if (membership === null || membership.eventId !== eventId) refuse("invalid", "No such guest in this event");
    if (membership.accountId !== undefined && membership.accountId === event.hostAccountId) {
      refuse("invalid", "The Host cannot remove themselves");
    }
    await removeMember(ctx, membership, now);
    return { removed: true };
  },
});

// The Host removes any picture after the reveal, for everyone (V2-FR-52); before it the Host sees none.
export const removePictureAsHost = mutation({
  args: { eventId: v.id("events"), pictureId: v.id("pictures") },
  handler: async (ctx, { eventId, pictureId }) => {
    const { event } = await hostedEvent(ctx, eventId);
    const now = Date.now();
    const phase = phaseOf(event, now);
    if (!isLive(phase)) refuse("eventGone");
    if (phase !== "revealed") refuse("notRevealed");
    const picture = await ctx.db.get(pictureId);
    if (picture === null || picture.eventId !== eventId) refuse("invalid", "No such picture in this event");
    await removePicture(ctx, picture, now, "host");
    await resolveReportsFor(ctx, pictureId, now, "removed");
    return { removed: true };
  },
});

// Marks every open report about a picture resolved.
export async function resolveReportsFor(
  ctx: MutationCtx,
  pictureId: Id<"pictures">,
  now: number,
  resolution: "removed" | "kept",
) {
  for (const report of await ctx.db
    .query("reports")
    .withIndex("by_picture_and_reporter", (q) => q.eq("pictureId", pictureId))
    .collect()) {
    if (report.resolvedAt === undefined) {
      await ctx.db.patch(report._id, { resolvedAt: now, resolution, expiresAt: now + REPORT_KEPT_AFTER_RESOLUTION_MS });
    }
  }
}
