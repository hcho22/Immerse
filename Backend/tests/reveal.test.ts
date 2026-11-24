// The timed steps (v2 PRD section 9.5, V2-FR-12, V2-FR-28, V2-FR-38 to V2-FR-42, V2-FR-48, V2-FR-06): the event opens
// at its Start Time, shooting stops at the End Time and unclaimed Rolls return, the album reveals at End Time plus
// Reveal Delay without anyone acting, ending early reveals at once, the album's end notices show, and 12 months after
// the reveal the event is gone. A deleted Host's event runs on to its reveal. These tests run Convex's scheduler on
// fake timers, so time moves without waiting.
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "../convex/_generated/api";
import type { Id } from "../convex/_generated/dataModel";
import { DAY_MS, HOUR_MS, MINUTE_MS } from "../convex/lib/config";
import { addMonths } from "../convex/lib/phase";
import { type Backend, newBackend, newHost, refusalCode, signedIn } from "./support/convex";
import { freshToken, joinAsGuest, loadFilm } from "./support/events";

beforeEach(() => {
  vi.useFakeTimers({ toFake: ["Date", "setTimeout", "clearTimeout"] });
  vi.setSystemTime(new Date("2026-12-05T18:00:00Z"));
});
afterEach(() => {
  vi.useRealTimers();
});

// Moves the clock and lets every scheduled step that comes due run.
async function advance(t: Backend, ms: number) {
  vi.advanceTimersByTime(ms);
  await t.finishInProgressScheduledFunctions();
  // A step may schedule another at once (the reveal's alert, a purge batch).
  vi.advanceTimersByTime(1);
  await t.finishInProgressScheduledFunctions();
}

async function balance(host: ReturnType<typeof signedIn>) {
  return (await host.query(api.rolls.balance, {})).rolls;
}

async function stored(t: Backend, eventId: Id<"events">) {
  return t.run(async (ctx) => (await ctx.db.get(eventId))!);
}

describe("an event's life on the server's clock", () => {
  test("opens at its Start Time, stops shooting at its End Time, returns unclaimed Rolls and reveals on time", async () => {
    const t = newBackend();
    const { host } = await newHost(t, "user_maya", "Maya");
    const startsAt = Date.now() + 3 * DAY_MS;
    const endsAt = startsAt + 6 * HOUR_MS;
    const { eventId, joinCode } = await loadFilm(host, { rolls: 3, startsAt, endsAt, revealDelayMs: 10 * HOUR_MS });
    expect(await balance(host)).toBe(0);

    await advance(t, 3 * DAY_MS - MINUTE_MS);
    expect(await refusalCode(joinAsGuest(t, joinCode))).toBe("notYetOpen");
    await advance(t, MINUTE_MS);
    expect((await stored(t, eventId)).state).toBe("open");
    const jo = await joinAsGuest(t, joinCode, "Jo");

    await advance(t, 6 * HOUR_MS);
    expect((await stored(t, eventId)).state).toBe("ended");
    // The two Rolls nobody took return to the Host's balance, without the Host doing anything (V2-FR-28).
    expect(await balance(host)).toBe(2);
    expect(await refusalCode(joinAsGuest(t, joinCode, "Sam"))).toBe("shootingEnded");
    expect(await refusalCode(host.action(api.reads.album, { eventId }))).toBe("sealed");
    expect(await refusalCode(t.action(api.reads.album, { eventId, guestToken: await freshToken(t, eventId, jo.guest) }))).toBe("sealed");

    await advance(t, 10 * HOUR_MS - MINUTE_MS);
    expect(await refusalCode(host.action(api.reads.album, { eventId }))).toBe("sealed");
    await advance(t, MINUTE_MS);
    const revealed = await stored(t, eventId);
    expect(revealed.state).toBe("revealed");
    // The reveal is scheduled for End Time plus Reveal Delay, and records when it ran, for success measure M-3.
    expect(revealed.revealsAt).toBe(endsAt + 10 * HOUR_MS);
    expect(revealed.revealedAt! - revealed.revealsAt).toBeGreaterThanOrEqual(0);
    expect(revealed.revealedAt! - revealed.revealsAt).toBeLessThan(MINUTE_MS);
    expect((await host.action(api.reads.album, { eventId })).entries).toEqual([]);
    // Repeating the steps changes nothing (V2-FR-81).
    await t.mutation(internal.schedule.endEvent, { eventId });
    await t.mutation(internal.schedule.revealEvent, { eventId });
    expect(await balance(host)).toBe(2);
  });

  test("the reveal does not wait for anyone, and nothing but the time reveals: not every Roll finished (V2-FR-42)", async () => {
    const t = newBackend();
    const { host } = await newHost(t, "user_maya", "Maya");
    const { eventId, joinCode } = await loadFilm(host, { rolls: 1, endsAt: Date.now() + DAY_MS, revealDelayMs: 0 });
    const jo = await joinAsGuest(t, joinCode, "Jo");
    await t.mutation(api.joining.reportExposures, { eventId, guestToken: jo.token, exposuresUsed: 27 });
    await host.mutation(api.hosting.setJoiningPaused, { eventId, paused: true });
    await advance(t, DAY_MS - MINUTE_MS);
    expect((await host.query(api.hosting.view, { eventId })).phase).toBe("open");
    await advance(t, MINUTE_MS);
    expect((await host.query(api.hosting.view, { eventId })).phase).toBe("revealed");
  });

  test("a step that runs late never lets anyone in after the End Time or keeps the album sealed after the reveal", async () => {
    const t = newBackend();
    const { host } = await newHost(t, "user_maya", "Maya");
    const { eventId, joinCode } = await loadFilm(host, { endsAt: Date.now() + HOUR_MS, revealDelayMs: HOUR_MS });
    // The steps have not run (the clock moved without the scheduler), as when the server was unreachable.
    vi.setSystemTime(Date.now() + 2 * HOUR_MS);
    expect(await refusalCode(joinAsGuest(t, joinCode))).toBe("shootingEnded");
    expect((await host.action(api.reads.album, { eventId })).entries).toEqual([]);
    expect((await stored(t, eventId)).state).toBe("open");
  });

  test("ending early stops shooting and reveals at once whatever the Reveal Delay, and returns unclaimed Rolls (V2-FR-40)", async () => {
    const t = newBackend();
    const { host } = await newHost(t, "user_maya", "Maya");
    const { eventId, joinCode } = await loadFilm(host, { rolls: 3, revealDelayMs: 24 * HOUR_MS });
    const jo = await joinAsGuest(t, joinCode, "Jo");
    await advance(t, HOUR_MS);
    await host.mutation(api.hosting.endEarly, { eventId });
    await advance(t, 0);
    const event = await stored(t, eventId);
    expect(event).toMatchObject({ state: "revealed", endsAt: event.revealsAt });
    expect(await balance(host)).toBe(2);
    const token = await freshToken(t, eventId, jo.guest);
    expect((await t.action(api.reads.album, { eventId, guestToken: token })).entries).toEqual([]);
    // A picture taken after the early end is refused (V2-FR-31).
    expect(
      await refusalCode(
        t.action(api.pictures.requestUpload, {
          eventId,
          exposureNumber: 1,
          captureTime: Date.now() + 1_000,
          contentType: "image/jpeg",
          size: 10,
          sha256: "A".repeat(43) + "=",
          guestToken: token,
        }),
      ),
    ).toBe("afterEndTime");
    // Ending early again changes nothing; the old reveal step finds the event revealed.
    expect(await host.mutation(api.hosting.endEarly, { eventId })).toEqual({ revealedAt: event.revealsAt });
    await advance(t, 25 * HOUR_MS);
    expect(await balance(host)).toBe(2);
  });

  test("the album's end notices show one month and one week before, and 12 months after the reveal the event is gone", async () => {
    const t = newBackend();
    const { host } = await newHost(t, "user_maya", "Maya");
    const { eventId, joinCode } = await loadFilm(host, { endsAt: Date.now() + HOUR_MS, revealDelayMs: 0 });
    const jo = await joinAsGuest(t, joinCode, "Jo");
    await advance(t, HOUR_MS);
    const revealedAt = (await stored(t, eventId)).revealsAt;
    const albumEndsAt = addMonths(revealedAt, 12);
    const notice = async () =>
      (await t.query(api.joining.memberView, { eventId, guestToken: await freshToken(t, eventId, jo.guest) })).event.albumNotice;
    expect(await notice()).toBe("none");
    vi.setSystemTime(addMonths(revealedAt, 11) - MINUTE_MS);
    expect(await notice()).toBe("none");
    vi.setSystemTime(addMonths(revealedAt, 11));
    expect(await notice()).toBe("month");
    expect((await host.query(api.hosting.view, { eventId })).albumNotice).toBe("month");
    vi.setSystemTime(albumEndsAt - 7 * DAY_MS);
    expect(await notice()).toBe("week");
    expect((await host.query(api.hosting.view, { eventId })).albumEndsAt).toBe(albumEndsAt);
    // The album's end, scheduled at the reveal for exactly 12 months later.
    const gone = await t.run(async (ctx) =>
      (await ctx.db.system.query("_scheduled_functions").collect()).find((job) => job.name === "schedule:goneEvent"),
    );
    expect(gone?.scheduledTime).toBe(albumEndsAt);
    vi.setSystemTime(albumEndsAt);
    expect(await refusalCode(t.mutation(api.guests.startSession, { ...jo.guest, eventId }))).toBe("eventGone");
    expect(await t.query(api.joining.preview, { code: joinCode })).toEqual({ status: "unavailable" });
    await t.mutation(internal.schedule.goneEvent, { eventId });
    await advance(t, 0);
    const after = await t.run(async (ctx) => ({
      event: await ctx.db.get(eventId),
      memberships: await ctx.db.query("memberships").collect(),
      sessions: await ctx.db.query("guestSessions").collect(),
    }));
    expect(after.event).toMatchObject({ state: "gone", title: "" });
    expect(after.memberships).toHaveLength(0);
    expect(after.sessions).toHaveLength(0);
    expect(await host.query(api.hosting.hosted, {})).toEqual([]);
  });
});

describe("a deleted Host's event runs on (V2-FR-06)", () => {
  test("it accepts joins until its End Time, reveals on schedule, its unclaimed Rolls lapse, and nobody controls it", async () => {
    const t = newBackend();
    const { host } = await newHost(t, "user_maya", "Maya");
    const { eventId, joinCode } = await loadFilm(host, { rolls: 3, endsAt: Date.now() + DAY_MS, revealDelayMs: HOUR_MS });
    const jo = await joinAsGuest(t, joinCode, "Jo");
    // Maya's Account is deleted on the server (Delete Account's own tests cover Clerk).
    await t.mutation(internal.deletion.deleteAccountBatch, { clerkUserId: "user_maya" });
    expect(await t.query(api.joining.preview, { code: joinCode })).toMatchObject({ status: "open", event: { hostName: null, hostLeft: true } });
    const sam = await joinAsGuest(t, joinCode, "Sam");
    expect(sam.event.hostLeft).toBe(true);
    await advance(t, DAY_MS);
    // Nothing returns: there is no balance to return to.
    expect(await t.run(async (ctx) => (await ctx.db.query("rollLedger").collect()).filter((row) => row.kind === "return"))).toEqual([]);
    expect((await stored(t, eventId)).rollsSettledAt).toBeDefined();
    await advance(t, HOUR_MS);
    expect((await stored(t, eventId)).state).toBe("revealed");
    expect((await t.action(api.reads.album, { eventId, guestToken: await freshToken(t, eventId, jo.guest) })).entries).toEqual([]);
    // Signing in again makes a new, empty Account, which is not the Host.
    await newHost(t, "user_maya_again", "Maya");
    const again = signedIn(t, "user_maya_again");
    expect(await refusalCode(again.query(api.hosting.view, { eventId }))).toBe("notTheHost");
  });
});
