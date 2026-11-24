// An event's state now (v2 PRD section 6.1), read from its times rather than waiting on the scheduler: the scheduled
// steps (schedule.ts) do the work that comes with each change, such as returning Rolls and sending the alert, but every
// rule that depends on the state reads it here, so a step that runs late never lets anyone join after the End Time or
// see a picture before the reveal, and never holds the reveal back.
import type { Doc } from "../_generated/dataModel";
import {
  ALBUM_MONTHS,
  FIRST_NOTICE_MONTHS_BEFORE,
  SECOND_NOTICE_MS_BEFORE,
} from "./config";

export type Phase = "scheduled" | "open" | "ended" | "revealed" | "gone" | "deleted";

// The same day of the month, `months` later, in UTC; the last day of a shorter month stands in for a day it lacks.
export function addMonths(ms: number, months: number): number {
  const date = new Date(ms);
  const day = date.getUTCDate();
  date.setUTCDate(1);
  date.setUTCMonth(date.getUTCMonth() + months);
  const lastDay = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)).getUTCDate();
  date.setUTCDate(Math.min(day, lastDay));
  return date.getTime();
}

// When the album ends: 12 months after the reveal (V2-FR-48).
export function albumEndsAt(event: Pick<Doc<"events">, "revealsAt">): number {
  return addMonths(event.revealsAt, ALBUM_MONTHS);
}

// When the event opened, or opens: its Start Time, or Load Film.
export function opensAt(event: Pick<Doc<"events">, "startsAt" | "createdAt">): number {
  return event.startsAt ?? event.createdAt;
}

export function phaseOf(event: Doc<"events">, now: number): Phase {
  if (event.state === "deleted" || event.state === "gone") return event.state;
  if (now >= albumEndsAt(event)) return "gone";
  if (event.state === "revealed" || now >= event.revealsAt) return "revealed";
  if (event.state === "ended" || now >= event.endsAt) return "ended";
  if (event.startsAt !== undefined && now < event.startsAt) return "scheduled";
  return "open";
}

// Whether the event still exists for its members: not gone at its 12-month end and not deleted.
export function isLive(phase: Phase): boolean {
  return phase !== "gone" && phase !== "deleted";
}

// Whether the Host may still change the event's setup: scheduled or open (V2-FR-16, V2-FR-17, V2-FR-27).
export function isBeforeEnd(phase: Phase): boolean {
  return phase === "scheduled" || phase === "open";
}

export type AlbumNotice = "none" | "month" | "week";

// Which of the album's end notices shows now (V2-FR-48): one month before the end, then one week before.
export function albumNotice(event: Doc<"events">, now: number): AlbumNotice {
  if (phaseOf(event, now) !== "revealed") return "none";
  const end = albumEndsAt(event);
  if (now >= end - SECOND_NOTICE_MS_BEFORE) return "week";
  if (now >= addMonths(event.revealsAt, ALBUM_MONTHS - FIRST_NOTICE_MONTHS_BEFORE)) return "month";
  return "none";
}
