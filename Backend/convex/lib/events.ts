// What the event functions share: validating an event's setup, making it, scheduling its timed steps (section 9.5),
// and describing it to the people who may see it.
import type { Doc, Id } from "../_generated/dataModel";
import { internal } from "../_generated/api";
import type { MutationCtx, QueryCtx } from "../_generated/server";
import {
  EXPOSURES_PER_ROLL,
  FILM_TITLE_LIMIT,
  GUEST_NAME_LIMIT,
  MAX_REVEAL_DELAY_MS,
  MAX_ROLLS_PER_EVENT,
  MAX_SHOOTING_MS,
} from "./config";
import { refuse } from "./errors";
import { joinCodeVerifier, joinCodeFor } from "./joinCode";
import { albumEndsAt, albumNotice, opensAt, phaseOf, type Phase } from "./phase";

export type Camera = Doc<"events">["camera"];
export type FilmStock = NonNullable<Doc<"events">["filmStock"]>;

const REQUEST_ID = /^[A-Za-z0-9_-]{16,64}$/;
const TREATMENT_VERSION = /^[A-Za-z0-9._-]{1,40}$/;

// A name or title trimmed, with runs of spaces made one, of 1 to `limit` characters.
function cleanText(raw: string, limit: number, what: string): string {
  const text = raw.trim().replace(/\s+/g, " ");
  if (text.length === 0 || [...text].length > limit) refuse("invalid", `${what} is 1 to ${limit} characters`);
  return text;
}

export const cleanFilmTitle = (raw: string) => cleanText(raw, FILM_TITLE_LIMIT, "A Film Title");
export const cleanGuestName = (raw: string) => cleanText(raw, GUEST_NAME_LIMIT, "A Guest Name");

export function checkRequestId(requestId: string) {
  if (!REQUEST_ID.test(requestId)) refuse("invalid", "Malformed request id");
}

export function checkRolls(rolls: number) {
  if (!Number.isInteger(rolls) || rolls < 1) refuse("invalid", "Rolls are a whole number of 1 or more");
  if (rolls > MAX_ROLLS_PER_EVENT) refuse("rollLimit", `An event has at most ${MAX_ROLLS_PER_EVENT} Rolls`);
}

// The 6×6 needs a Film Stock for everyone; the Disposable and the Instant take none (V2-FR-10, ADR 0014).
export function checkFilmStock(camera: Camera, filmStock: FilmStock | undefined) {
  if (camera === "6x6" && filmStock === undefined) refuse("invalid", "A 6×6 Group Film needs a Film Stock");
  if (camera !== "6x6" && filmStock !== undefined) refuse("invalid", "Only the 6×6 takes a Film Stock");
}

export function checkTreatmentVersion(version: string) {
  if (!TREATMENT_VERSION.test(version)) refuse("invalid", "Malformed treatment version");
}

// The times of V2-FR-12: a Start Time in the future when there is one, an End Time after the opening and at most 7
// days after it, and a Reveal Delay of none to 24 hours.
export function checkTimes(times: { opensAt: number; endsAt: number; revealDelayMs: number }, now: number) {
  const { opensAt, endsAt, revealDelayMs } = times;
  if (![opensAt, endsAt, revealDelayMs].every(Number.isFinite)) refuse("invalid", "Malformed times");
  if (endsAt <= now) refuse("invalid", "The End Time is in the past");
  if (endsAt <= opensAt) refuse("invalid", "The End Time is before the event opens");
  if (endsAt - opensAt > MAX_SHOOTING_MS) refuse("invalid", "Shooting lasts at most 7 days");
  if (!Number.isInteger(revealDelayMs) || revealDelayMs < 0 || revealDelayMs > MAX_REVEAL_DELAY_MS) {
    refuse("invalid", "The Reveal Delay is from none to 24 hours");
  }
}

export type NewEvent = {
  title: string;
  hostAccountId: Id<"accounts">;
  camera: Camera;
  filmStock?: FilmStock;
  treatmentVersion: string;
  rolls: number;
  startsAt?: number;
  endsAt: number;
  revealDelayMs: number;
  createRequestId?: string;
};

// Makes an event, its first Join Code and its scheduled steps. The caller has checked the setup and the balance.
export async function insertEvent(ctx: MutationCtx, setup: NewEvent, now: number): Promise<Id<"events">> {
  const eventId = await ctx.db.insert("events", {
    title: setup.title,
    hostAccountId: setup.hostAccountId,
    camera: setup.camera,
    filmStock: setup.filmStock,
    treatmentVersion: setup.treatmentVersion,
    exposuresPerRoll: EXPOSURES_PER_ROLL[setup.camera],
    rollsSetAside: setup.rolls,
    rollsTaken: 0,
    startsAt: setup.startsAt,
    endsAt: setup.endsAt,
    revealDelayMs: setup.revealDelayMs,
    revealsAt: setup.endsAt + setup.revealDelayMs,
    joiningPaused: false,
    joinCodeGeneration: 1,
    webAlbumOn: false,
    state: setup.startsAt !== undefined ? "scheduled" : "open",
    createRequestId: setup.createRequestId,
    jobs: {},
    createdAt: now,
  });
  await ctx.db.insert("joinCodes", { eventId, verifier: await joinCodeVerifier(await joinCodeFor(eventId, 1)), generation: 1 });
  await scheduleSteps(ctx, eventId, now);
  return eventId;
}

// Cancels an event's scheduled steps that have not run.
async function cancelSteps(ctx: MutationCtx, jobs: Doc<"events">["jobs"]) {
  for (const id of [jobs.open, jobs.end, jobs.reveal, jobs.gone]) {
    if (id === undefined) continue;
    const job = await ctx.db.system.get(id);
    if (job !== null && job.state.kind === "pending") await ctx.scheduler.cancel(id);
  }
}

// Schedules the event's opening at its Start Time, its end at the End Time and its reveal at End Time plus Reveal
// Delay (section 9.5), cancelling whatever was scheduled before. Called at Load Film and after every change of the
// times; the reveal schedules the album's end. Each step checks the event's current state when it runs.
export async function scheduleSteps(ctx: MutationCtx, eventId: Id<"events">, now: number) {
  const event = await ctx.db.get(eventId);
  if (event === null) return;
  await cancelSteps(ctx, event.jobs);
  const jobs: Doc<"events">["jobs"] = {};
  const phase = phaseOf(event, now);
  if (phase === "scheduled" && event.startsAt !== undefined) {
    jobs.open = await ctx.scheduler.runAt(event.startsAt, internal.schedule.openEvent, { eventId });
  }
  if (phase === "scheduled" || phase === "open") {
    jobs.end = await ctx.scheduler.runAt(event.endsAt, internal.schedule.endEvent, { eventId });
  }
  if (phase !== "revealed" && phase !== "gone" && phase !== "deleted") {
    jobs.reveal = await ctx.scheduler.runAt(event.revealsAt, internal.schedule.revealEvent, { eventId });
  }
  if (phase === "revealed" || event.state === "revealed") {
    jobs.gone = await ctx.scheduler.runAt(albumEndsAt(event), internal.schedule.goneEvent, { eventId });
  }
  await ctx.db.patch(eventId, { jobs });
}

// Stops every scheduled step, for an event that was deleted.
export async function stopSteps(ctx: MutationCtx, event: Doc<"events">) {
  await cancelSteps(ctx, event.jobs);
  await ctx.db.patch(event._id, { jobs: {} });
}

// The current Join Code, and the verifier of each earlier one stays retired.
export async function currentJoinCode(event: Doc<"events">): Promise<string> {
  return joinCodeFor(event._id, event.joinCodeGeneration);
}

// What every member may know of the event (V2-FR-21, V2-FR-11): never a picture, and nothing of the Host's beyond the
// event's title and the Host's display name.
export async function eventSummary(ctx: QueryCtx, event: Doc<"events">, now: number) {
  const host = event.hostAccountId !== undefined ? await ctx.db.get(event.hostAccountId) : null;
  const phase: Phase = phaseOf(event, now);
  return {
    eventId: event._id,
    title: event.title,
    hostName: host?.displayName ?? null,
    hostLeft: event.hostAccountId === undefined,
    camera: event.camera,
    filmStock: event.filmStock ?? null,
    exposuresPerRoll: event.exposuresPerRoll,
    phase,
    startsAt: event.startsAt ?? null,
    opensAt: opensAt(event),
    endsAt: event.endsAt,
    revealDelayMs: event.revealDelayMs,
    revealsAt: event.revealsAt,
    albumEndsAt: albumEndsAt(event),
    albumNotice: albumNotice(event, now),
    joiningPaused: event.joiningPaused,
  };
}
