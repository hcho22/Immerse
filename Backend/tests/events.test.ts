// Creating and running a Group Film from the Host's side (v2 PRD sections 5.2 to 5.5): Load Film and its limits, free
// Rolls once ever, the Join Code and its link, pausing and replacing it, adding Rolls, moving the times, and the Host's
// view of counts, never pictures, before the reveal.
import { describe, expect, test } from "vitest";
import { api } from "../convex/_generated/api";
import { DAY_MS, HOUR_MS } from "../convex/lib/config";
import { joinCodeFor, joinCodeVerifier } from "../convex/lib/joinCode";
import { newBackend, newHost, refusalCode, signedIn, randomId } from "./support/convex";
import { credentials, joinAsGuest, loadFilm, storePicture } from "./support/events";

async function maya() {
  const t = newBackend();
  const { host, accountId } = await newHost(t, "user_maya", "Maya");
  return { t, host, accountId };
}

describe("Load Film", () => {
  test("makes the event, sets its Rolls aside from the free Rolls, and issues its Join Code at once", async () => {
    const { t, host } = await maya();
    expect(await host.query(api.rolls.balance, {})).toEqual({ rolls: 3 });
    const { eventId, joinCode } = await loadFilm(host, { rolls: 3 });
    expect(joinCode).toMatch(/^[A-Za-z0-9_-]{22}$/);
    expect(await host.query(api.rolls.balance, {})).toEqual({ rolls: 0 });
    const view = await host.query(api.hosting.view, { eventId });
    expect(view).toMatchObject({
      title: "Ana & Leo",
      hostName: "Maya",
      camera: "disposable",
      exposuresPerRoll: 27,
      phase: "open",
      joinCode,
      rolls: { setAside: 3, taken: 0, free: 3, limit: 200 },
      picturesArrived: 0,
      guests: [],
    });
    // The code is stored only as a verifier (section 8).
    const stored = JSON.stringify(await t.run((ctx) => ctx.db.query("joinCodes").collect()));
    expect(stored).not.toContain(joinCode);
    expect(stored).toContain(await joinCodeVerifier(joinCode));
  });

  test("free Rolls are credited once ever, however many events the Account hosts (V2-FR-62)", async () => {
    const { t, host } = await maya();
    await loadFilm(host, { rolls: 2 });
    await loadFilm(host, { rolls: 1 });
    expect(await host.query(api.rolls.balance, {})).toEqual({ rolls: 0 });
    expect(await refusalCode(loadFilm(host, { rolls: 1 }))).toBe("balanceTooLow");
    const free = await t.run(async (ctx) => (await ctx.db.query("rollLedger").collect()).filter((row) => row.kind === "free"));
    expect(free).toHaveLength(1);
    const history = await host.query(api.rolls.history, {});
    expect(history.map((row) => row.kind).sort()).toEqual(["free", "setAside", "setAside"]);
  });

  test("a repeated Load Film with the same request id makes one event (V2-FR-81)", async () => {
    const { t, host } = await maya();
    const requestId = randomId();
    const first = await loadFilm(host, { requestId, rolls: 2 });
    const second = await loadFilm(host, { requestId, rolls: 2 });
    expect(second).toEqual(first);
    expect(await t.run((ctx) => ctx.db.query("events").collect())).toHaveLength(1);
    expect(await host.query(api.rolls.balance, {})).toEqual({ rolls: 1 });
  });

  test("refuses a Start Time or End Time in the past, more than 7 days of shooting, and a Reveal Delay above 24 hours", async () => {
    const { host } = await maya();
    const now = Date.now();
    const refusals = await Promise.all([
      refusalCode(loadFilm(host, { startsAt: now - 1_000 })),
      refusalCode(loadFilm(host, { endsAt: now - 1_000 })),
      refusalCode(loadFilm(host, { endsAt: now + 7 * DAY_MS + 60_000 })),
      refusalCode(loadFilm(host, { startsAt: now + 30 * DAY_MS, endsAt: now + 38 * DAY_MS })),
      refusalCode(loadFilm(host, { revealDelayMs: 24 * HOUR_MS + 1 })),
      refusalCode(loadFilm(host, { revealDelayMs: -1 })),
      refusalCode(loadFilm(host, { title: "   " })),
      refusalCode(loadFilm(host, { title: "x".repeat(61) })),
    ]);
    expect(refusals).toEqual(Array(refusals.length).fill("invalid"));
    // A Start Time weeks ahead with 7 days of shooting is fine (V2-FR-12).
    expect(await loadFilm(host, { startsAt: now + 30 * DAY_MS, endsAt: now + 37 * DAY_MS, rolls: 1 })).toHaveProperty("joinCode");
  });

  test("the Camera is one of the three photo Cameras, and only the 6×6 takes a Film Stock, which it needs (V2-FR-10)", async () => {
    const { host } = await maya();
    expect(await refusalCode(loadFilm(host, { camera: "6x6" }))).toBe("invalid");
    expect(await refusalCode(loadFilm(host, { camera: "disposable", filmStock: "color" }))).toBe("invalid");
    // The Super 8 and the 16mm are not offered: the server's argument validator refuses them.
    await expect(
      host.mutation(api.hosting.create, {
        requestId: randomId(),
        title: "Super 8",
        camera: "super8" as never,
        rolls: 1,
        endsAt: Date.now() + DAY_MS,
        revealDelayMs: 0,
        treatmentVersion: "film-look-5",
      }),
    ).rejects.toThrow();
    const { eventId } = await loadFilm(host, { camera: "6x6", filmStock: "blackAndWhite", rolls: 1 });
    expect(await host.query(api.hosting.view, { eventId })).toMatchObject({ camera: "6x6", filmStock: "blackAndWhite", exposuresPerRoll: 12 });
  });

  test("at most 200 Rolls in the event's life (V2-FR-26)", async () => {
    const { t, host, accountId } = await maya();
    await t.run((ctx) => ctx.db.insert("rollLedger", { accountId, kind: "free", freeGrant: "subscriber", rolls: 300, at: Date.now() }));
    expect(await refusalCode(loadFilm(host, { rolls: 201 }))).toBe("rollLimit");
    const { eventId } = await loadFilm(host, { rolls: 199 });
    expect(await host.mutation(api.hosting.addRolls, { eventId, rolls: 1, requestId: randomId() })).toEqual({ rollsSetAside: 200 });
    expect(await refusalCode(host.mutation(api.hosting.addRolls, { eventId, rolls: 1, requestId: randomId() }))).toBe("rollLimit");
  });

  test("only a signed-in person with an Account can host, and only the Host sees or changes the event", async () => {
    const { t, host } = await maya();
    expect(await refusalCode(loadFilm(signedIn(t, "user_nobody")))).toBe("noAccount");
    const { eventId } = await loadFilm(host);
    await newHost(t, "user_ana", "Ana");
    const ana = signedIn(t, "user_ana");
    for (const attempt of [
      ana.query(api.hosting.view, { eventId }),
      ana.mutation(api.hosting.setJoiningPaused, { eventId, paused: true }),
      ana.mutation(api.hosting.replaceJoinCode, { eventId, generation: 1 }),
      ana.mutation(api.hosting.addRolls, { eventId, rolls: 1, requestId: randomId() }),
      ana.mutation(api.hosting.endEarly, { eventId }),
      ana.mutation(api.hosting.rename, { eventId, title: "Mine now" }),
      ana.mutation(api.hosting.deleteEvent, { eventId }),
      ana.mutation(api.hosting.updateTimes, { eventId, revealDelayMs: 0 }),
    ]) {
      expect(await refusalCode(attempt)).toBe("notTheHost");
    }
    // A guest token cannot act as the Host either.
    const { joinCode } = (await host.query(api.hosting.view, { eventId })) as { joinCode: string };
    const jo = await joinAsGuest(t, joinCode);
    expect(await refusalCode(t.query(api.hosting.view, { eventId }))).toBe("unauthenticated");
    expect(jo.token).toBeTruthy();
  });
});

describe("the Join Code and its link (V2-FR-15 to V2-FR-18)", () => {
  test("the link shows the Join Confirmation without joining anyone, and never a picture", async () => {
    const { t, host } = await maya();
    const { eventId, joinCode } = await loadFilm(host);
    const preview = await t.query(api.joining.preview, { code: joinCode });
    expect(preview).toMatchObject({
      status: "open",
      place: "none",
      event: { eventId, title: "Ana & Leo", hostName: "Maya", camera: "disposable", exposuresPerRoll: 27, phase: "open" },
    });
    expect(JSON.stringify(preview)).not.toMatch(/url|storageKey|picture/i);
    expect((await host.query(api.hosting.view, { eventId })).rolls).toMatchObject({ taken: 0 });
  });

  test("an unknown code finds nothing", async () => {
    const { t } = await maya();
    expect(await t.query(api.joining.preview, { code: randomId(16) })).toEqual({ status: "unknown" });
    expect(await t.query(api.joining.preview, { code: "short" })).toEqual({ status: "unknown" });
    expect(await refusalCode(t.mutation(api.joining.join, { code: randomId(16), guestName: "Jo", guest: credentials() }))).toBe("unknownCode");
  });

  test("the code is the same for the event's whole life, and is derived from nothing a guest can see", async () => {
    const { host } = await maya();
    const { eventId, joinCode } = await loadFilm(host);
    expect(await joinCodeFor(eventId, 1)).toBe(joinCode);
    expect((await host.query(api.hosting.view, { eventId })).joinCode).toBe(joinCode);
    expect(joinCode).not.toContain(eventId);
  });

  test("pausing admits nobody new, keeps guests who joined, and resuming admits the next person with the same code", async () => {
    const { t, host } = await maya();
    const { eventId, joinCode } = await loadFilm(host);
    const jo = await joinAsGuest(t, joinCode, "Jo");
    await host.mutation(api.hosting.setJoiningPaused, { eventId, paused: true });
    expect(await t.query(api.joining.preview, { code: joinCode })).toMatchObject({ status: "paused" });
    expect(await refusalCode(joinAsGuest(t, joinCode, "Sam"))).toBe("joiningPaused");
    // Jo keeps shooting.
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    await host.mutation(api.hosting.setJoiningPaused, { eventId, paused: false });
    expect((await joinAsGuest(t, joinCode, "Sam")).guestName).toBe("Sam");
  });

  test("replacing the code stops the old link at once and for good, and affects nobody who joined", async () => {
    const { t, host } = await maya();
    const { eventId, joinCode } = await loadFilm(host);
    const jo = await joinAsGuest(t, joinCode, "Jo");
    const replaced = await host.mutation(api.hosting.replaceJoinCode, { eventId, generation: 1 });
    expect(replaced.generation).toBe(2);
    expect(replaced.joinCode).not.toBe(joinCode);
    // Repeating the same request replaces it once.
    expect(await host.mutation(api.hosting.replaceJoinCode, { eventId, generation: 1 })).toEqual(replaced);
    expect(await t.query(api.joining.preview, { code: joinCode })).toEqual({ status: "replaced" });
    expect(await refusalCode(joinAsGuest(t, joinCode, "Sam"))).toBe("codeReplaced");
    expect(await t.query(api.joining.preview, { code: replaced.joinCode })).toMatchObject({ status: "open" });
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    expect((await host.query(api.hosting.view, { eventId })).joinCode).toBe(replaced.joinCode);
  });

  test("before the Start Time the link shows the event and when it opens, and nobody can join, the Host included", async () => {
    const { t, host } = await maya();
    const startsAt = Date.now() + 14 * DAY_MS;
    const { eventId, joinCode } = await loadFilm(host, { startsAt, rolls: 2 });
    expect(await t.query(api.joining.preview, { code: joinCode })).toMatchObject({ status: "notYetOpen", event: { phase: "scheduled", startsAt } });
    expect(await refusalCode(joinAsGuest(t, joinCode))).toBe("notYetOpen");
    expect(await refusalCode(host.mutation(api.joining.join, { code: joinCode, guestName: "Maya" }))).toBe("notYetOpen");
    // While scheduled the Host can add Rolls, pause, replace the code and move the times (section 16.3).
    expect(await host.mutation(api.hosting.addRolls, { eventId, rolls: 1, requestId: randomId() })).toEqual({ rollsSetAside: 3 });
    await host.mutation(api.hosting.setJoiningPaused, { eventId, paused: true });
    await host.mutation(api.hosting.updateTimes, { eventId, startsAt: startsAt + DAY_MS, endsAt: startsAt + 2 * DAY_MS });
    expect(await host.query(api.hosting.view, { eventId })).toMatchObject({ phase: "scheduled", startsAt: startsAt + DAY_MS, joiningPaused: true });
  });

  test("every Roll taken: nobody new can join until the Host adds Rolls, which admits the next guest at once", async () => {
    const { t, host } = await maya();
    const { eventId, joinCode } = await loadFilm(host, { rolls: 1 });
    await joinAsGuest(t, joinCode, "Jo");
    expect(await t.query(api.joining.preview, { code: joinCode })).toMatchObject({ status: "full" });
    expect(await refusalCode(joinAsGuest(t, joinCode, "Sam"))).toBe("rollsTaken");
    await t.run(async (ctx) => {
      const account = await ctx.db.query("accounts").first();
      await ctx.db.insert("rollLedger", { accountId: account!._id, kind: "free", freeGrant: "subscriber", rolls: 5, at: Date.now() });
    });
    await host.mutation(api.hosting.addRolls, { eventId, rolls: 2, requestId: randomId() });
    expect((await joinAsGuest(t, joinCode, "Sam")).guestName).toBe("Sam");
  });

  test("two people taking the last Roll at once: exactly one gets it (V2-FR-24)", async () => {
    const { t, host } = await maya();
    const { joinCode } = await loadFilm(host, { rolls: 1 });
    const outcomes = await Promise.allSettled([joinAsGuest(t, joinCode, "Jo"), joinAsGuest(t, joinCode, "Sam")]);
    expect(outcomes.filter((outcome) => outcome.status === "fulfilled")).toHaveLength(1);
    const refused = outcomes.find((outcome) => outcome.status === "rejected") as PromiseRejectedResult;
    expect(refused.reason.data.code).toBe("rollsTaken");
  });

  test("adding Rolls is refused after the End Time, needs the balance, and repeats safely", async () => {
    const { t, host } = await maya();
    const { eventId } = await loadFilm(host, { rolls: 2 });
    const requestId = randomId();
    expect(await host.mutation(api.hosting.addRolls, { eventId, rolls: 1, requestId })).toEqual({ rollsSetAside: 3 });
    expect(await host.mutation(api.hosting.addRolls, { eventId, rolls: 1, requestId })).toEqual({ rollsSetAside: 3 });
    expect(await refusalCode(host.mutation(api.hosting.addRolls, { eventId, rolls: 1, requestId: randomId() }))).toBe("balanceTooLow");
    await t.run((ctx) => ctx.db.patch(eventId, { endsAt: Date.now() - 1, revealsAt: Date.now() + HOUR_MS }));
    expect(await refusalCode(host.mutation(api.hosting.addRolls, { eventId, rolls: 1, requestId: randomId() }))).toBe("shootingEnded");
  });
});

describe("joining (V2-FR-21 to V2-FR-25)", () => {
  test("a guest joins with only a name, gets a token for the event and what the phone needs to shoot offline", async () => {
    const { t, host } = await maya();
    const { eventId, joinCode } = await loadFilm(host, { camera: "6x6", filmStock: "color" });
    const jo = await joinAsGuest(t, joinCode, "  Jo  ");
    expect(jo).toMatchObject({
      guestName: "Jo",
      exposuresUsed: 0,
      event: { eventId, camera: "6x6", filmStock: "color", exposuresPerRoll: 12 },
    });
    expect(jo.guestToken).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect((await host.query(api.hosting.view, { eventId })).rolls).toMatchObject({ taken: 1, free: 2 });
    expect(await refusalCode(joinAsGuest(t, joinCode, ""))).toBe("invalid");
    expect(await refusalCode(joinAsGuest(t, joinCode, "x".repeat(41)))).toBe("invalid");
  });

  test("joining again takes no second Roll", async () => {
    const { t, host } = await maya();
    const { eventId, joinCode } = await loadFilm(host);
    const guest = credentials();
    await joinAsGuest(t, joinCode, "Jo", guest);
    await joinAsGuest(t, joinCode, "Jo", guest);
    expect((await host.query(api.hosting.view, { eventId })).rolls).toMatchObject({ taken: 1 });
    expect(await t.query(api.joining.preview, { code: joinCode, guest })).toMatchObject({ status: "member", place: "joined" });
  });

  test("a wrong secret for a known guest identity is refused and joins nobody", async () => {
    const { t, host } = await maya();
    const { joinCode } = await loadFilm(host);
    const guest = credentials();
    await joinAsGuest(t, joinCode, "Jo", guest);
    expect(await refusalCode(joinAsGuest(t, joinCode, "Jo", { publicId: guest.publicId, secret: randomId(32) }))).toBe("guestTokenRefused");
  });

  test("the Host can shoot in their own event, taking one of its Rolls like any guest (V2-FR-25)", async () => {
    const { host } = await maya();
    const { eventId, joinCode } = await loadFilm(host, { rolls: 2 });
    const reply = await host.mutation(api.joining.join, { code: joinCode, guestName: "Maya" });
    expect(reply.guestToken).toBeNull();
    await storePicture(host, eventId, 1);
    const view = await host.query(api.hosting.view, { eventId });
    expect(view.rolls).toMatchObject({ taken: 1, free: 1 });
    expect(view.guests).toEqual([expect.objectContaining({ name: "Maya", isHost: true, exposuresUsed: 1 })]);
    // The Host cannot leave their own event.
    expect(await refusalCode(host.mutation(api.joining.leave, { eventId }))).toBe("invalid");
  });

  test("the Host sees each guest's name and exposures used, and how many pictures arrived, never a picture (V2-FR-29)", async () => {
    const { t, host } = await maya();
    const { eventId, joinCode } = await loadFilm(host);
    const jo = await joinAsGuest(t, joinCode, "Jo");
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    await t.mutation(api.joining.reportExposures, { eventId, guestToken: jo.token, exposuresUsed: 5 });
    const view = await host.query(api.hosting.view, { eventId });
    expect(view.picturesArrived).toBe(1);
    expect(view.guests).toEqual([expect.objectContaining({ name: "Jo", exposuresUsed: 5, status: "joined" })]);
    expect(JSON.stringify(view)).not.toMatch(/storageKey|url|sha256/i);
    expect(await refusalCode(host.action(api.reads.album, { eventId }))).toBe("sealed");
  });

  test("a guest changes their name until the album ends, and it shows on their pictures", async () => {
    const { t, host } = await maya();
    const { eventId, joinCode } = await loadFilm(host);
    const jo = await joinAsGuest(t, joinCode, "Jo");
    expect(await t.mutation(api.joining.setGuestName, { eventId, guestToken: jo.token, guestName: "Jo B" })).toEqual({ guestName: "Jo B" });
    expect((await host.query(api.hosting.view, { eventId })).guests[0]!.name).toBe("Jo B");
  });
});

describe("the times (V2-FR-12)", () => {
  test("the End Time and Reveal Delay move until the End Time, within the limits, and the Start Time only until the event opens", async () => {
    const { t, host } = await maya();
    const { eventId } = await loadFilm(host);
    const now = Date.now();
    await host.mutation(api.hosting.updateTimes, { eventId, endsAt: now + 3 * DAY_MS, revealDelayMs: 0 });
    expect(await host.query(api.hosting.view, { eventId })).toMatchObject({ endsAt: now + 3 * DAY_MS, revealsAt: now + 3 * DAY_MS });
    expect(await refusalCode(host.mutation(api.hosting.updateTimes, { eventId, endsAt: now + 8 * DAY_MS }))).toBe("invalid");
    expect(await refusalCode(host.mutation(api.hosting.updateTimes, { eventId, startsAt: now + DAY_MS }))).toBe("invalid");
    await t.run((ctx) => ctx.db.patch(eventId, { endsAt: Date.now() - 1, revealsAt: Date.now() + HOUR_MS }));
    expect(await refusalCode(host.mutation(api.hosting.updateTimes, { eventId, revealDelayMs: 0 }))).toBe("shootingEnded");
  });

  test("moving the times reschedules the end and the reveal at their exact new times", async () => {
    const { t, host } = await maya();
    const { eventId } = await loadFilm(host);
    const endsAt = Date.now() + 2 * DAY_MS;
    await host.mutation(api.hosting.updateTimes, { eventId, endsAt, revealDelayMs: 3 * HOUR_MS });
    const pending = await t.run(async (ctx) =>
      (await ctx.db.system.query("_scheduled_functions").collect()).filter((job) => job.state.kind === "pending"),
    );
    const byName = Object.fromEntries(pending.map((job) => [job.name, job.scheduledTime]));
    expect(byName["schedule:endEvent"]).toBe(endsAt);
    expect(byName["schedule:revealEvent"]).toBe(endsAt + 3 * HOUR_MS);
    const cancelled = await t.run(async (ctx) =>
      (await ctx.db.system.query("_scheduled_functions").collect()).filter((job) => job.state.kind === "canceled"),
    );
    expect(cancelled.map((job) => job.name).sort()).toEqual(["schedule:endEvent", "schedule:revealEvent"]);
  });

  test("clearing a Start Time opens the event now, with its 7 days counted from now", async () => {
    const { t, host } = await maya();
    const startsAt = Date.now() + 10 * DAY_MS;
    const { eventId, joinCode } = await loadFilm(host, { startsAt, endsAt: startsAt + DAY_MS });
    expect(await refusalCode(host.mutation(api.hosting.updateTimes, { eventId, startsAt: null }))).toBe("invalid");
    await host.mutation(api.hosting.updateTimes, { eventId, startsAt: null, endsAt: Date.now() + DAY_MS });
    expect(await host.query(api.hosting.view, { eventId })).toMatchObject({ phase: "open" });
    expect((await joinAsGuest(t, joinCode)).guestName).toBe("Jo");
  });
});
