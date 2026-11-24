// The limits and numbers Group Films run by (v2 PRD sections 5.2 to 5.5), in one place.
//
// The limits are product rules the PRD fixes. The free amounts are the open pricing decision (V2-FR-64, OC-5): the
// server holds them as deployment configuration, never the app, and the defaults below stand until the captain sets
// them.

export const MINUTE_MS = 60_000;
export const HOUR_MS = 60 * MINUTE_MS;
export const DAY_MS = 24 * HOUR_MS;

// At most 200 Rolls in an event's whole life, the Host's own included (V2-FR-26).
export const MAX_ROLLS_PER_EVENT = 200;
// Shooting lasts at most 7 days from the event's opening (V2-FR-12).
export const MAX_SHOOTING_MS = 7 * DAY_MS;
// The Reveal Delay is from none to 24 hours (V2-FR-12, V2-FR-39).
export const MAX_REVEAL_DELAY_MS = 24 * HOUR_MS;
// The album is kept 12 months after the reveal, with notices one month and one week before its end (V2-FR-48).
export const ALBUM_MONTHS = 12;
export const FIRST_NOTICE_MONTHS_BEFORE = 1;
export const SECOND_NOTICE_MS_BEFORE = 7 * DAY_MS;
// A guest identity is kept until 12 months after the last album it took part in ends (section 8).
export const GUEST_IDENTITY_MONTHS_AFTER_LAST_ALBUM = 12;
// A report is kept 90 days after it is resolved, or until the event's end if sooner (section 8, proposed).
export const REPORT_KEPT_AFTER_RESOLUTION_MS = 90 * DAY_MS;
// The time within which support answers a report (OQ-12, answered 2026-11-23: Immerse's operator answers support
// within 48 hours). The server lists reports older than this as overdue, for success measure M-7.
export const SUPPORT_RESPONSE_MS = 48 * HOUR_MS;

// A Film Title and a Guest Name are 1 to these many characters (V2-FR-14, V2-FR-22).
export const FILM_TITLE_LIMIT = 60;
export const GUEST_NAME_LIMIT = 40;

// Each Camera's normal roll (V2-FR-25).
export const EXPOSURES_PER_ROLL = { disposable: 27, "6x6": 12, instant: 10 } as const;

function wholeNumber(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw.trim() === "") return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 0 || value > MAX_ROLLS_PER_EVENT) {
    throw new Error(`${name} must be a whole number from 0 to ${MAX_ROLLS_PER_EVENT}`);
  }
  return value;
}

// Everyone's once-ever free Rolls, "about 3" (V2-FR-62). FREE_ROLLS_EVERYONE on the deployment overrides it.
export function freeRollsForEveryone(): number {
  return wholeNumber("FREE_ROLLS_EVERYONE", 3);
}

// A subscriber's larger once-ever free Rolls (V2-FR-62, V2-FR-63). Stage 4 credits it once the server has confirmed the
// subscription with Apple; until FREE_ROLLS_SUBSCRIBER is set it is 0, and nothing in Stage 2 credits it.
export function freeRollsForSubscribers(): number {
  return wholeNumber("FREE_ROLLS_SUBSCRIBER", 0);
}
