// The view-only web album's rules, on the server (v2 PRD V2-FR-37, V2-FR-47, section 9.4): the Host's switch, and what
// the deployment tells the join page's Worker. Before the reveal, with the switch off, after it is switched off again,
// for a withdrawn or removed picture, a removed guest's pictures, a replaced code, and an ended, deleted or gone event,
// no picture is listed and no read address is signed, whatever is asked and whoever asks.
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { api, internal } from "../convex/_generated/api";
import type { Id } from "../convex/_generated/dataModel";
import { crc32 } from "../convex/lib/crc32";
import { newBackend, newHost, refusalCode, signedIn, type Backend } from "./support/convex";
import { joinAsGuest, loadFilm, storePicture } from "./support/events";
import { startClerkDouble } from "./support/clerk-double";
import { askDeployment } from "./support/web";

let clerk: Awaited<ReturnType<typeof startClerkDouble>>;
beforeEach(async () => {
  clerk = await startClerkDouble();
});
afterEach(async () => {
  await clerk.close();
});

async function party(rolls = 3) {
  const t = newBackend();
  const { host } = await newHost(t, "user_maya", "Maya");
  const { eventId, joinCode } = await loadFilm(host, { rolls });
  const jo = await joinAsGuest(t, joinCode, "Jo");
  const sam = await joinAsGuest(t, joinCode, "Sam");
  return { t, host, eventId, joinCode, jo, sam };
}

async function pictureIds(t: Backend, eventId: Id<"events">) {
  return t.run(async (ctx) =>
    (await ctx.db.query("pictures").withIndex("by_event", (q) => q.eq("eventId", eventId)).collect())
      .sort((a, b) => (a.captureTime ?? 0) - (b.captureTime ?? 0))
      .map((picture) => picture._id),
  );
}

// Every way to ask for a picture of the event through the web, each refused.
async function expectNoPicture(t: Backend, code: string, ids: string[]) {
  const page = await askDeployment(t, "/web/page", { code });
  expect(page.body.album ?? null).toBeNull();
  expect(JSON.stringify(page.body)).not.toMatch(/storageKey|X-Amz|pictures\//);
  for (const pictureId of ids) {
    for (const copy of ["view", "full"]) {
      const grant = await askDeployment(t, "/web/picture", { code, pictureId, copy });
      expect(grant.status).toBe(404);
      expect(grant.body).toEqual({ granted: false });
    }
  }
}

describe("the Host's switch (V2-FR-47)", () => {
  test("is off unless the Host turns it on, and can be turned on only after the reveal", async () => {
    const { t, host, eventId, jo } = await party();
    expect((await host.query(api.hosting.view, { eventId })).webAlbum).toBe(false);
    expect(await refusalCode(host.mutation(api.hosting.setWebAlbum, { eventId, on: true }))).toBe("notRevealed");
    await t.mutation(internal.proofs.endProofEvent, { eventId });
    expect(await refusalCode(host.mutation(api.hosting.setWebAlbum, { eventId, on: true }))).toBe("notRevealed");
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    expect((await host.query(api.hosting.view, { eventId })).webAlbum).toBe(false);
    expect((await t.query(api.joining.memberView, { eventId, guestToken: jo.token })).event.webAlbumOn).toBe(false);
    expect(await host.mutation(api.hosting.setWebAlbum, { eventId, on: true })).toEqual({ on: true });
    // Repeating it changes nothing further (V2-FR-81).
    expect(await host.mutation(api.hosting.setWebAlbum, { eventId, on: true })).toEqual({ on: true });
    expect((await host.query(api.hosting.view, { eventId })).webAlbum).toBe(true);
    expect((await t.query(api.joining.memberView, { eventId, guestToken: jo.token })).event.webAlbumOn).toBe(true);
    expect(await host.mutation(api.hosting.setWebAlbum, { eventId, on: false })).toEqual({ on: false });
    expect((await host.query(api.hosting.view, { eventId })).webAlbum).toBe(false);
  });

  test("only the event's Host can change it: not a guest, not another Account, nobody signed in", async () => {
    const { t, eventId } = await party();
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    await newHost(t, "user_other", "Other");
    expect(await refusalCode(signedIn(t, "user_other").mutation(api.hosting.setWebAlbum, { eventId, on: true }))).toBe("notTheHost");
    expect(await refusalCode(t.mutation(api.hosting.setWebAlbum, { eventId, on: true }))).toBe("unauthenticated");
    expect((await askDeployment(t, "/web/page", { code: "x".repeat(22) })).body.status).toBe("unknown");
  });

  test("a deleted Host's event keeps the setting it had, and nobody can change it (V2-FR-06)", async () => {
    const { t, host, eventId, joinCode, jo } = await party();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    await host.mutation(api.hosting.setWebAlbum, { eventId, on: true });
    await host.action(api.deletion.deleteAccount, {});
    await t.finishAllScheduledFunctions(() => undefined);
    const page = await askDeployment(t, "/web/page", { code: joinCode });
    expect(page.body.status).toBe("revealed");
    expect(page.body.event.hostLeft).toBe(true);
    expect(page.body.album).toHaveLength(1);
    await newHost(t, "user_maya_again", "Maya");
    expect(await refusalCode(signedIn(t, "user_maya_again").mutation(api.hosting.setWebAlbum, { eventId, on: false }))).toBe("notTheHost");
  });
});

describe("only the join page's Worker may ask", () => {
  test("a request without the shared secret, or with a wrong one, is refused before anything is read", async () => {
    const { t, joinCode } = await party();
    for (const path of ["/web/page", "/web/picture"] as const) {
      const none = await t.fetch(path, { method: "POST", body: JSON.stringify({ code: joinCode, pictureId: "x" }) });
      expect(none.status).toBe(401);
      expect((await askDeployment(t, path, { code: joinCode, pictureId: "x" }, "wrong-secret-wrong-secret-wrong-secret")).status).toBe(401);
    }
    const saved = process.env.WEB_GATEWAY_SECRET;
    try {
      // A deployment with no secret set stays closed.
      delete process.env.WEB_GATEWAY_SECRET;
      expect((await askDeployment(t, "/web/page", { code: joinCode }, "undefined")).status).toBe(401);
      process.env.WEB_GATEWAY_SECRET = "short";
      expect((await askDeployment(t, "/web/page", { code: joinCode }, "short")).status).toBe(401);
    } finally {
      process.env.WEB_GATEWAY_SECRET = saved;
    }
    expect((await askDeployment(t, "/web/page", {})).status).toBe(400);
    expect((await askDeployment(t, "/web/picture", { code: joinCode })).status).toBe(400);
  });
});

describe("what a link's page may show (V2-FR-18)", () => {
  test("each state of an event, and never more than its title, Host name, Camera and times", async () => {
    const t = newBackend();
    const { host } = await newHost(t, "user_maya", "Maya");
    const later = await loadFilm(host, { rolls: 1, startsAt: Date.now() + 3_600_000, title: "Later" });
    expect((await askDeployment(t, "/web/page", { code: later.joinCode })).body).toMatchObject({
      status: "scheduled",
      event: { title: "Later", hostName: "Maya", camera: "disposable", exposuresPerRoll: 27 },
      album: null,
    });
    const { eventId, joinCode } = await loadFilm(host, { rolls: 1, camera: "6x6", filmStock: "blackAndWhite" });
    const open = await askDeployment(t, "/web/page", { code: joinCode });
    expect(open.body).toMatchObject({ status: "open", event: { camera: "6x6", filmStock: "blackAndWhite", hostLeft: false } });
    expect(Object.keys(open.body.event).sort()).toEqual(
      ["albumEndsAt", "albumNotice", "camera", "endsAt", "exposuresPerRoll", "filmStock", "hostLeft", "hostName", "opensAt", "revealsAt", "title"].sort(),
    );
    await host.mutation(api.hosting.setJoiningPaused, { eventId, paused: true });
    expect((await askDeployment(t, "/web/page", { code: joinCode })).body.status).toBe("paused");
    await host.mutation(api.hosting.setJoiningPaused, { eventId, paused: false });
    await joinAsGuest(t, joinCode, "Jo");
    expect((await askDeployment(t, "/web/page", { code: joinCode })).body.status).toBe("full");
    await t.mutation(internal.proofs.endProofEvent, { eventId });
    expect((await askDeployment(t, "/web/page", { code: joinCode })).body).toMatchObject({ status: "ended", album: null });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    expect((await askDeployment(t, "/web/page", { code: joinCode })).body).toMatchObject({ status: "revealed", album: null });
    await host.mutation(api.hosting.deleteEvent, { eventId });
    expect((await askDeployment(t, "/web/page", { code: joinCode })).body).toEqual({ status: "unavailable" });
    expect((await askDeployment(t, "/web/page", { code: "NoSuchEventCodeAtAll00" })).body).toEqual({ status: "unknown" });
    expect((await askDeployment(t, "/web/page", { code: "not a code" })).body).toEqual({ status: "unknown" });
  });

  test("a replaced code says only that, and the new code shows the event", async () => {
    const { t, host, eventId, joinCode } = await party();
    const replaced = await host.mutation(api.hosting.replaceJoinCode, { eventId, generation: 1 });
    expect((await askDeployment(t, "/web/page", { code: joinCode })).body).toEqual({ status: "replaced" });
    expect((await askDeployment(t, "/web/page", { code: replaced.joinCode })).body.status).toBe("open");
  });
});

describe("no picture reaches the web unless the album is revealed and switched on (V2-FR-37, V2-FR-47)", () => {
  test("before the reveal, after shooting ended, and after the reveal with the switch off", async () => {
    const { t, eventId, joinCode, jo } = await party();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    const ids = await pictureIds(t, eventId);
    await expectNoPicture(t, joinCode, ids);
    await t.mutation(internal.proofs.endProofEvent, { eventId });
    await expectNoPicture(t, joinCode, ids);
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    await expectNoPicture(t, joinCode, ids);
  });

  test("switched on, the album lists every picture in capture order with names and numbered gaps, and each reads whole", async () => {
    const { t, host, eventId, joinCode, jo, sam } = await party();
    const start = Date.now() - 60_000;
    const first = await storePicture(t, eventId, 1, { guestToken: sam.token, captureTime: start + 1_000 });
    await storePicture(t, eventId, 1, { guestToken: jo.token, captureTime: start + 2_000 });
    await storePicture(t, eventId, 2, { guestToken: sam.token, captureTime: start + 3_000 });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    await host.mutation(api.hosting.setWebAlbum, { eventId, on: true });
    await t.mutation(api.joining.removeMyPicture, { eventId, guestToken: jo.token, exposureNumber: 1 });
    const ids = await pictureIds(t, eventId);
    const page = await askDeployment(t, "/web/page", { code: joinCode });
    expect(page.body.album).toEqual([
      { number: 1, removed: false, pictureId: ids[0], shooterName: "Sam", captureTime: start + 1_000, contentType: "image/jpeg", size: first.file.size, crc32: crc32(first.file.bytes) },
      { number: 2, removed: true },
      expect.objectContaining({ number: 3, removed: false, pictureId: ids[2], shooterName: "Sam" }),
    ]);
    expect(JSON.stringify(page.body)).not.toMatch(/storageKey|X-Amz|sha256/);
    const full = await askDeployment(t, "/web/picture", { code: joinCode, pictureId: ids[0], copy: "full" });
    expect(full.body).toMatchObject({ granted: true, contentType: "image/jpeg", size: first.file.size, expiresInSeconds: 60 });
    expect(new Uint8Array(await (await fetch(full.body.url)).arrayBuffer())).toEqual(first.file.bytes);
    const view = await askDeployment(t, "/web/picture", { code: joinCode, pictureId: ids[0], copy: "view" });
    expect(view.body.size).toBe(first.view.size);
    expect(new Uint8Array(await (await fetch(view.body.url)).arrayBuffer())).toEqual(first.view.bytes);
    // The picture its shooter removed is gone from the web too.
    expect((await askDeployment(t, "/web/picture", { code: joinCode, pictureId: ids[1], copy: "full" })).status).toBe(404);
  });

  test("switched off again, nothing is listed and no address is signed, at once", async () => {
    const { t, host, eventId, joinCode, jo } = await party();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    await host.mutation(api.hosting.setWebAlbum, { eventId, on: true });
    const ids = await pictureIds(t, eventId);
    expect((await askDeployment(t, "/web/picture", { code: joinCode, pictureId: ids[0], copy: "view" })).status).toBe(200);
    await host.mutation(api.hosting.setWebAlbum, { eventId, on: false });
    await expectNoPicture(t, joinCode, ids);
    // The members' album is unaffected.
    expect((await t.action(api.reads.album, { eventId, guestToken: jo.token })).entries).toHaveLength(1);
  });

  test("a picture the Host or support removed, and every picture of a removed guest, leave the web album with a gap", async () => {
    const { t, host, eventId, joinCode, jo, sam } = await party();
    const start = Date.now() - 60_000;
    await storePicture(t, eventId, 1, { guestToken: jo.token, captureTime: start + 1_000 });
    await storePicture(t, eventId, 1, { guestToken: sam.token, captureTime: start + 2_000 });
    await storePicture(t, eventId, 2, { guestToken: sam.token, captureTime: start + 3_000 });
    await storePicture(t, eventId, 2, { guestToken: jo.token, captureTime: start + 4_000 });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    await host.mutation(api.hosting.setWebAlbum, { eventId, on: true });
    const ids = await pictureIds(t, eventId);
    await host.mutation(api.hosting.removePictureAsHost, { eventId, pictureId: ids[0]! });
    await t.mutation(internal.support.removePictureForSupport, { pictureId: ids[3]! });
    const samsPlace = await t.run(async (ctx) => (await ctx.db.query("memberships").collect()).find((m) => m.guestName === "Sam")!._id);
    await host.mutation(api.hosting.removeGuest, { eventId, membershipId: samsPlace });
    const page = await askDeployment(t, "/web/page", { code: joinCode });
    expect(page.body.album).toEqual([1, 2, 3, 4].map((number) => ({ number, removed: true })));
    for (const pictureId of ids) {
      expect((await askDeployment(t, "/web/picture", { code: joinCode, pictureId, copy: "full" })).status).toBe(404);
    }
  });

  test("a deleted event, an album that has ended, and a replaced code give nothing", async () => {
    const { t, host, eventId, joinCode, jo } = await party();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    await host.mutation(api.hosting.setWebAlbum, { eventId, on: true });
    const ids = await pictureIds(t, eventId);
    // An album that has ended (V2-FR-48), before its purge has run.
    await t.run((ctx) => ctx.db.patch(eventId, { state: "gone" }));
    await expectNoPicture(t, joinCode, ids);
    expect((await askDeployment(t, "/web/page", { code: joinCode })).body).toEqual({ status: "unavailable" });
    await t.run((ctx) => ctx.db.patch(eventId, { state: "revealed" }));
    expect((await askDeployment(t, "/web/picture", { code: joinCode, pictureId: ids[0], copy: "view" })).status).toBe(200);
    await host.mutation(api.hosting.deleteEvent, { eventId });
    await expectNoPicture(t, joinCode, ids);
  });

  test("a picture is granted only through its own event's current code", async () => {
    const { t, host, eventId, joinCode, jo } = await party();
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    await host.mutation(api.hosting.setWebAlbum, { eventId, on: true });
    const [pictureId] = await pictureIds(t, eventId);
    // Another shared album's code does not open this event's picture.
    const { host: sam } = await newHost(t, "user_sam", "Sam");
    const second = await loadFilm(sam, { rolls: 1, title: "Sam's" });
    await t.mutation(internal.proofs.revealProofEvent, { eventId: second.eventId });
    await sam.mutation(api.hosting.setWebAlbum, { eventId: second.eventId, on: true });
    expect((await askDeployment(t, "/web/picture", { code: second.joinCode, pictureId, copy: "full" })).status).toBe(404);
    for (const wrong of ["", "nonsense", eventId, "x".repeat(200)]) {
      expect((await askDeployment(t, "/web/picture", { code: joinCode, pictureId: wrong, copy: "full" })).status).toBe(404);
    }
    expect((await askDeployment(t, "/web/picture", { code: joinCode, pictureId, copy: "full" })).status).toBe(200);
  });
});
