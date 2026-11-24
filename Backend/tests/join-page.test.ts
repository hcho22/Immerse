// The join page and the web album as a browser gets them (v2 PRD V2-FR-15, V2-FR-18, V2-FR-20, V2-FR-47, V2-FR-48): the
// Worker of Backend/worker, asking the in-memory Convex backend what it may show and reading pictures from the R2
// stand-in. Every row of V2-FR-18's table that a browser can meet has its words here, every route for everyone who can
// join, and the album only while the Host shares it.
import { describe, expect, test } from "vitest";
import { api, internal } from "../convex/_generated/api";
import type { Id } from "../convex/_generated/dataModel";
import { crc32 } from "../convex/lib/crc32";
import { DAY_MS } from "../convex/lib/config";
import { deviceFor } from "../worker/src/device";
import { newBackend, newHost, type Backend } from "./support/convex";
import { joinAsGuest, loadFilm, storePicture } from "./support/events";
import { AGENTS, joinPageWorker, unzip, words } from "./support/web";

async function hosted(setup: Parameters<typeof loadFilm>[1] = {}) {
  const t = newBackend();
  const { host } = await newHost(t, "user_maya", "Maya");
  const { eventId, joinCode } = await loadFilm(host, { rolls: 3, ...setup });
  return { t, host, eventId, joinCode, page: joinPageWorker(t) };
}

async function pictureIds(t: Backend, eventId: Id<"events">) {
  return t.run(async (ctx) =>
    (await ctx.db.query("pictures").withIndex("by_event", (q) => q.eq("eventId", eventId)).collect())
      .sort((a, b) => (a.captureTime ?? 0) - (b.captureTime ?? 0))
      .map((picture) => picture._id as string),
  );
}

// A revealed event with three pictures by two guests, the middle one removed by its shooter.
async function revealedAlbum(options: { shared: boolean } = { shared: true }) {
  const context = await hosted();
  const { t, host, eventId, joinCode } = context;
  const jo = await joinAsGuest(t, joinCode, "Jo <Jones>");
  const sam = await joinAsGuest(t, joinCode, "Sam");
  const start = Date.UTC(2026, 10, 20, 20, 0, 0);
  const first = await storePicture(t, eventId, 1, { guestToken: sam.token, captureTime: start });
  await storePicture(t, eventId, 1, { guestToken: jo.token, captureTime: start + 60_000 });
  const third = await storePicture(t, eventId, 2, { guestToken: jo.token, captureTime: start + 120_000 });
  await t.mutation(internal.proofs.revealProofEvent, { eventId });
  await t.mutation(api.joining.removeMyPicture, { eventId, guestToken: jo.token, exposureNumber: 1 });
  if (options.shared) await host.mutation(api.hosting.setWebAlbum, { eventId, on: true });
  return { ...context, jo, sam, first, third, ids: await pictureIds(t, eventId) };
}

describe("who is opening the link", () => {
  test("an iPhone that can shoot, one that is too old, one that cannot be told, and everything else", () => {
    expect(deviceFor(AGENTS.iphone26)).toBe("iphone");
    expect(deviceFor(AGENTS.iphone18)).toBe("iphoneTooOld");
    expect(deviceFor(AGENTS.iphone15)).toBe("iphoneTooOld");
    expect(deviceFor(AGENTS.iphoneInApp)).toBe("iphoneUnknown");
    expect(deviceFor(AGENTS.android)).toBe("android");
    expect(deviceFor(AGENTS.mac)).toBe("other");
    expect(deviceFor(AGENTS.firefox)).toBe("other");
    expect(deviceFor(null)).toBe("other");
    expect(deviceFor("Mozilla/5.0 (iPhone; CPU iPhone OS 26_1 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148")).toBe("iphone");
    expect(deviceFor("Mozilla/5.0 (iPad; CPU OS 18_6 like Mac OS X) AppleWebKit/605.1.15 Version/26.0 Mobile/15E148 Safari/604.1")).toBe("other");
  });
});

describe("the message for everyone who cannot join (V2-FR-18)", () => {
  test("an iPhone on an iOS before 26 is told to update", async () => {
    const { page, joinCode } = await hosted();
    const response = await page.get(`/j/${joinCode}`, AGENTS.iphone18);
    expect(response.status).toBe(200);
    const text = await words(response);
    expect(text).toContain("Shooting needs iOS 26 or later. Update this iPhone to join.");
    expect(text).not.toContain("Join on this iPhone");
  });

  test("an Android phone and a computer are told shooting needs an iPhone, and where the pictures will be", async () => {
    const { page, joinCode } = await hosted();
    for (const agent of [AGENTS.android, AGENTS.mac, AGENTS.firefox]) {
      const response = await page.get(`/j/${joinCode}`, agent);
      const html = await response.clone().text();
      const text = await words(response);
      expect(text).toContain("Ana & Leo");
      expect(text).toContain("Hosted by Maya");
      expect(text).toContain("Shooting needs an iPhone on iOS 26. The pictures will be on this page after the reveal if the Host shares them.");
      expect(text).not.toContain("Join on this iPhone");
      expect(html).not.toContain("apple-itunes-app");
    }
  });

  test("before the Start Time, with the time for the reader's own time zone", async () => {
    const startsAt = Date.UTC(2031, 5, 14, 15, 30);
    const { page, joinCode } = await hosted({ startsAt, endsAt: startsAt + DAY_MS });
    const response = await page.get(`/j/${joinCode}`, AGENTS.iphone26);
    const html = await response.clone().text();
    const text = await words(response);
    expect(text).toContain("This event opens 14 June 2031 at 15:30 UTC. Come back then.");
    expect(html).toContain(`<time datetime="2031-06-14T15:30:00.000Z" data-local="moment">`);
    expect(text).not.toContain("Join on this iPhone");
  });

  test("while joining is paused, and when every Roll is taken", async () => {
    const { t, host, eventId, page, joinCode } = await hosted({ rolls: 1 });
    await host.mutation(api.hosting.setJoiningPaused, { eventId, paused: true });
    expect(await words(await page.get(`/j/${joinCode}`, AGENTS.iphone26))).toContain("Joining is paused for now.");
    await host.mutation(api.hosting.setJoiningPaused, { eventId, paused: false });
    await joinAsGuest(t, joinCode, "Jo");
    const text = await words(await page.get(`/j/${joinCode}`, AGENTS.iphone26));
    expect(text).toContain("Every Roll has been taken. The Host can add more.");
    expect(text).not.toContain("Join on this iPhone");
  });

  test("after the End Time, with the reveal time, and after the reveal with the album not shared", async () => {
    const { t, eventId, page, joinCode } = await hosted();
    await t.mutation(internal.proofs.endProofEvent, { eventId });
    const ended = await words(await page.get(`/j/${joinCode}`, AGENTS.android));
    expect(ended).toMatch(/Shooting has ended\. The album reveals \d+ \w+ \d{4} at \d\d:\d\d UTC\./);
    expect(ended).toContain("The pictures will be on this page after the reveal if the Host shares them.");
    await t.mutation(internal.proofs.revealProofEvent, { eventId });
    const revealed = await words(await page.get(`/j/${joinCode}`, AGENTS.android));
    expect(revealed).toContain("Ana & Leo");
    expect(revealed).toContain("This event's pictures are not shared on the web.");
  });

  test("a deleted event, an album that has ended and a code that never was say the event is no longer available", async () => {
    const { t, host, eventId, page, joinCode } = await hosted();
    await t.run((ctx) => ctx.db.patch(eventId, { state: "gone" }));
    const gone = await page.get(`/j/${joinCode}`, AGENTS.iphone26);
    expect(gone.status).toBe(404);
    expect(await words(gone)).toContain("This event is no longer available.");
    await t.run((ctx) => ctx.db.patch(eventId, { state: "open" }));
    await host.mutation(api.hosting.deleteEvent, { eventId });
    for (const path of [`/j/${joinCode}`, "/j/NoSuchEventCodeAtAll00", "/j/short", "/elsewhere", "/j/"]) {
      const response = await page.get(path, AGENTS.android);
      expect(response.status).toBe(404);
      const text = await words(response);
      expect(text).toContain("This event is no longer available.");
      expect(text).not.toContain("Ana");
    }
  });

  test("a replaced code says the link no longer works, and names nothing of the event", async () => {
    const { host, eventId, page, joinCode } = await hosted();
    const { joinCode: next } = await host.mutation(api.hosting.replaceJoinCode, { eventId, generation: 1 });
    const old = await page.get(`/j/${joinCode}`, AGENTS.iphone26);
    expect(old.status).toBe(410);
    const text = await words(old);
    expect(text).toContain("This link no longer works. Ask the Host for the new one.");
    expect(text).not.toContain("Ana");
    expect(await words(await page.get(`/j/${next}`, AGENTS.iphone26))).toContain("Join on this iPhone");
  });

  test("no case is an empty page or an error code: the server out of reach, a method the page does not take, too many tries", async () => {
    const { t, page, joinCode } = await hosted();
    const unreachable = joinPageWorker(t, { CONVEX_SITE_URL: undefined });
    const response = await unreachable.get(`/j/${joinCode}`);
    expect(response.status).toBe(503);
    expect(await words(response)).toContain("Immerse could not be reached just now. Try again in a moment.");
    const wrongSecret = joinPageWorker(t, { WEB_GATEWAY_SECRET: "not-the-secret-not-the-secret-not-the-secret" });
    expect(await words(await wrongSecret.get(`/j/${joinCode}`))).toContain("Immerse could not be reached just now.");
    expect((await page.request(`/j/${joinCode}`, { method: "POST" })).status).toBe(405);
    let asked = 0;
    const limited = joinPageWorker(t, { JOIN_LIMITER: { limit: async ({ key }) => ({ success: key !== "203.0.113.9" || (asked += 1) <= 2 }) } });
    const from = { "cf-connecting-ip": "203.0.113.9" };
    expect((await limited.get(`/j/${joinCode}`, AGENTS.mac, from)).status).toBe(200);
    expect((await limited.get(`/j/${joinCode}`, AGENTS.mac, from)).status).toBe(200);
    const third = await limited.get(`/j/NoSuchEventCodeAtAll00`, AGENTS.mac, from);
    expect(third.status).toBe(429);
    expect(third.headers.get("retry-after")).toBe("60");
    expect(await words(third)).toContain("Too many tries from this connection.");
    // Another address is not held back.
    expect((await limited.get(`/j/${joinCode}`, AGENTS.mac, { "cf-connecting-ip": "198.51.100.7" })).status).toBe(200);
  });
});

describe("the route for everyone who can join (V2-FR-19, V2-FR-21)", () => {
  test("an iPhone on iOS 26 gets the mini-app's card, the way in, and the full app for an account that cannot use App Clips", async () => {
    const { page, joinCode } = await hosted({ camera: "6x6", filmStock: "color" });
    const response = await page.get(`/j/${joinCode}`, AGENTS.iphone26);
    const html = await response.clone().text();
    const text = await words(response);
    expect(html).toContain(
      `<meta name="apple-itunes-app" content="app-id=1234567890, app-clip-bundle-id=com.immerse.FilmJournal.Clip, app-clip-display=card">`,
    );
    expect(text).toContain("Ana & Leo");
    expect(text).toContain("Hosted by Maya");
    expect(text).toContain("6×6 · 12 exposures a Roll · Color");
    expect(text).toMatch(/Shooting ends .* The album reveals /);
    expect(text).toContain("Every picture stays sealed until the reveal.");
    expect(text).toContain("Tap Open on the Immerse card to join with nothing to install");
    expect(text).toContain("an Apple Account that cannot use App Clips, such as a child's account or one with Ask to Buy");
    expect(text).toContain("Install Immerse, then open this link again.");
    expect(html).toContain(`href="https://apps.apple.com/app/id1234567890"`);
    expect(text).not.toContain("Shooting needs");
  });

  test("an iPhone whose iOS cannot be told, as inside another app's browser, gets the way in with the requirement", async () => {
    const { page, joinCode } = await hosted();
    const text = await words(await page.get(`/j/${joinCode}`, AGENTS.iphoneInApp));
    expect(text).toContain("Join on this iPhone");
    expect(text).toContain("Shooting needs iOS 26 or later.");
  });

  test("until the app has an App Store id, the page names no store and shows no card", async () => {
    const { t, joinCode } = await hosted();
    const page = joinPageWorker(t, { APP_STORE_ID: "", APP_CLIP_BUNDLE_ID: "" });
    const html = await (await page.get(`/j/${joinCode}`, AGENTS.iphone26)).text();
    expect(html).not.toContain("apple-itunes-app");
    expect(html).not.toContain("apps.apple.com");
    expect(html).toContain("Join on this iPhone");
  });

  test("Apple's association file names the app and the App Clip from configuration", async () => {
    const { t, page } = await hosted();
    const response = await page.get("/.well-known/apple-app-site-association");
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("application/json");
    expect(await response.json()).toEqual({
      applinks: { details: [{ appIDs: ["TEAM123456.com.immerse.FilmJournal"], components: [{ "/": "/j/*" }] }] },
      appclips: { apps: ["TEAM123456.com.immerse.FilmJournal.Clip"] },
    });
    expect((await joinPageWorker(t, { APPLE_TEAM_ID: "" }).get("/.well-known/apple-app-site-association")).status).toBe(404);
    const noClip = await joinPageWorker(t, { APP_CLIP_BUNDLE_ID: "" }).get("/.well-known/apple-app-site-association");
    expect(Object.keys(await noClip.json())).toEqual(["applinks"]);
  });
});

describe("what the page never does (V2-FR-15, V2-FR-20)", () => {
  test("no camera, upload or file picker, nothing from another site, and a preview of the title only", async () => {
    const { page, joinCode, ids } = await revealedAlbum();
    for (const path of [`/j/${joinCode}`, `/j/${joinCode}/v/${ids[0]}`]) {
      const response = await page.get(path, AGENTS.iphone26);
      const html = await response.text();
      expect(html).not.toMatch(/<input|<form|<button|capture=|getUserMedia|type="file"|<iframe|<video|<canvas/i);
      expect(html).not.toMatch(/(src|href)="https?:\/\/(?!apps\.apple\.com\/)/);
      expect(html).not.toMatch(/og:image|twitter:image/);
      expect(html).toContain("<title>Ana &amp; Leo</title>");
      expect(html).toContain(`<meta property="og:title" content="Ana &amp; Leo">`);
      expect(response.headers.get("cache-control")).toBe("no-store");
      expect(response.headers.get("referrer-policy")).toBe("no-referrer");
      expect(response.headers.get("x-robots-tag")).toBe("noindex, nofollow");
      const policy = response.headers.get("content-security-policy")!;
      expect(policy).toContain("default-src 'none'");
      expect(policy).toContain("img-src 'self'");
      expect(policy).not.toContain("unsafe");
      const nonce = /script-src 'nonce-([^']+)'/.exec(policy)![1];
      expect(html).toContain(`<script nonce="${nonce}">`);
    }
  });

  test("a title or a name is shown as written, never as markup", async () => {
    const { page, joinCode, ids } = await revealedAlbum();
    const html = await (await page.get(`/j/${joinCode}/v/${ids[2]}`)).text();
    expect(html).toContain("Jo &lt;Jones&gt;");
    expect(html).not.toContain("<Jones>");
  });
});

describe("the view-only web album (V2-FR-47)", () => {
  test("off, the page shows only the event's title and that its pictures are not shared, and every picture address gives nothing", async () => {
    const { page, joinCode, ids } = await revealedAlbum({ shared: false });
    const response = await page.get(`/j/${joinCode}`, AGENTS.android);
    const html = await response.clone().text();
    const text = await words(response);
    expect(text).toContain("Ana & Leo");
    expect(text).toContain("This event's pictures are not shared on the web.");
    expect(html).not.toMatch(/<img|album\.zip|\/p\//);
    expect(text).not.toMatch(/Jo|Sam/);
    for (const id of ids) {
      for (const path of [`/j/${joinCode}/p/${id}/view`, `/j/${joinCode}/p/${id}/full`, `/j/${joinCode}/v/${id}`]) {
        const picture = await page.get(path);
        expect(picture.status).toBe(404);
        expect(await picture.text()).toContain("not shared on the web");
      }
    }
    expect((await page.get(`/j/${joinCode}/album.zip`)).status).toBe(404);
  });

  test("before the reveal the page shows no picture and every picture address gives nothing", async () => {
    const { t, eventId, joinCode, page } = await hosted();
    const jo = await joinAsGuest(t, joinCode, "Jo");
    await storePicture(t, eventId, 1, { guestToken: jo.token });
    const [id] = await pictureIds(t, eventId);
    const html = await (await page.get(`/j/${joinCode}`, AGENTS.android)).text();
    expect(html).not.toMatch(/<img|album\.zip|\/p\//);
    for (const path of [`/j/${joinCode}/p/${id}/view`, `/j/${joinCode}/p/${id}/full`, `/j/${joinCode}/v/${id}`, `/j/${joinCode}/album.zip`]) {
      expect((await page.get(path)).status).toBe(404);
    }
  });

  test("on, anyone with the link sees the pictures in capture order with numbered gaps, on an Android phone and a computer", async () => {
    const { page, joinCode, ids, first, third } = await revealedAlbum();
    for (const agent of [AGENTS.android, AGENTS.mac, AGENTS.firefox, AGENTS.iphone26]) {
      const response = await page.get(`/j/${joinCode}`, agent);
      expect(response.status).toBe(200);
      const html = await response.clone().text();
      const text = await words(response);
      expect(text).toContain("Ana & Leo");
      expect(text).toContain("2 pictures, in the order they were taken.");
      const order = [...html.matchAll(/<li(?: class="gap" aria-label="Picture (\d+), removed"|><a href="\/j\/[^"]+\/v\/([^"]+)">)/g)].map(
        (match) => match[1] ?? match[2],
      );
      expect(order).toEqual([ids[0], "2", ids[2]]);
      // Guest Names are in each picture's details, not on the album.
      expect(text).not.toMatch(/Sam|Jones/);
      if (agent !== AGENTS.iphone26) expect(text).toContain("Shooting needs an iPhone on iOS 26.");
      expect(text).toContain("support@immerse.test");
    }
    const view = await page.get(`/j/${joinCode}/p/${ids[0]}/view`);
    expect(view.headers.get("content-type")).toBe("image/jpeg");
    expect(view.headers.get("cache-control")).toBe("private, no-store");
    expect(new Uint8Array(await view.arrayBuffer())).toEqual(first.view.bytes);
    const full = await page.get(`/j/${joinCode}/p/${ids[2]}/full?download=1`);
    expect(full.headers.get("content-disposition")).toMatch(/^attachment; filename="immerse-[^"]+\.jpg"$/);
    expect(new Uint8Array(await full.arrayBuffer())).toEqual(third.file.bytes);
  });

  test("a picture's details give its Guest Name, when it was taken and the Camera, and a way to save it", async () => {
    const { page, joinCode, ids } = await revealedAlbum();
    const response = await page.get(`/j/${joinCode}/v/${ids[0]}`, AGENTS.android);
    const html = await response.clone().text();
    const text = await words(response);
    expect(text).toContain("Picture 1");
    expect(text).toContain("Taken by Sam");
    expect(text).toContain("Taken 20 November 2026 at 20:00 UTC");
    expect(text).toContain("Camera Disposable");
    expect(html).toContain(`href="/j/${joinCode}/p/${ids[0]}/full?download=1" download`);
    expect((await page.get(`/j/${joinCode}/v/${ids[1]}`)).status).toBe(404);
  });

  test("the album downloads as a ZIP of the pictures as uploaded, named by number and carrying no Guest Name", async () => {
    const { page, joinCode, first, third } = await revealedAlbum();
    const html = await (await page.get(`/j/${joinCode}`)).text();
    expect(html).toContain(`href="/j/${joinCode}/album.zip"`);
    const response = await page.get(`/j/${joinCode}/album.zip`);
    expect(response.headers.get("content-type")).toBe("application/zip");
    expect(response.headers.get("content-disposition")).toBe(`attachment; filename="immerse-album.zip"`);
    const bytes = new Uint8Array(await response.arrayBuffer());
    expect(Number(response.headers.get("content-length"))).toBe(bytes.length);
    const entries = unzip(bytes);
    expect(entries.map((entry) => entry.name)).toEqual(["001.jpg", "003.jpg"]);
    expect(entries[0]!.bytes).toEqual(first.file.bytes);
    expect(entries[1]!.bytes).toEqual(third.file.bytes);
    expect(entries.map((entry) => entry.crc32)).toEqual([crc32(first.file.bytes), crc32(third.file.bytes)]);
    expect(new TextDecoder("latin1").decode(bytes)).not.toMatch(/Sam|Jones/);
  });

  test("a large album downloads in parts, each a whole ZIP", async () => {
    const { t, joinCode, first, third } = await revealedAlbum();
    const page = joinPageWorker(t, { ALBUM_PART_PICTURES: "1" });
    const html = await (await page.get(`/j/${joinCode}`)).text();
    expect(html).toContain(`href="/j/${joinCode}/album.zip?part=1"`);
    expect(html).toContain(`href="/j/${joinCode}/album.zip?part=2"`);
    expect(html).toContain("Pictures 3 to 3");
    const one = unzip(new Uint8Array(await (await page.get(`/j/${joinCode}/album.zip?part=1`)).arrayBuffer()));
    const two = unzip(new Uint8Array(await (await page.get(`/j/${joinCode}/album.zip?part=2`)).arrayBuffer()));
    expect(one.map((entry) => entry.name)).toEqual(["001.jpg"]);
    expect(one[0]!.bytes).toEqual(first.file.bytes);
    expect(two[0]!.bytes).toEqual(third.file.bytes);
    expect((await page.get(`/j/${joinCode}/album.zip?part=3`)).status).toBe(404);
    expect((await page.get(`/j/${joinCode}/album.zip?part=x`)).status).toBe(404);
  });

  test("switched off while someone is viewing, their next picture load fails and the page says the pictures are no longer shared", async () => {
    const { host, eventId, page, joinCode, ids } = await revealedAlbum();
    expect((await page.get(`/j/${joinCode}/p/${ids[0]}/view`)).status).toBe(200);
    await host.mutation(api.hosting.setWebAlbum, { eventId, on: false });
    for (const path of [`/j/${joinCode}/p/${ids[0]}/view`, `/j/${joinCode}/p/${ids[0]}/full`, `/j/${joinCode}/album.zip`, `/j/${joinCode}/v/${ids[0]}`]) {
      expect((await page.get(path)).status).toBe(404);
    }
    const again = await page.get(`/j/${joinCode}`);
    const html = await again.clone().text();
    expect(await words(again)).toContain("This event's pictures are not shared on the web.");
    expect(html).not.toMatch(/<img|\/p\//);
    // And on again shows them again.
    await host.mutation(api.hosting.setWebAlbum, { eventId, on: true });
    expect((await page.get(`/j/${joinCode}/p/${ids[0]}/view`)).status).toBe(200);
  });

  test("a download that is under way stops when the album is switched off, and is never a whole file", async () => {
    const { t, host, eventId, joinCode } = await revealedAlbum();
    const page = joinPageWorker(t);
    const response = await page.get(`/j/${joinCode}/album.zip`);
    const reader = response.body!.getReader();
    await reader.read();
    await host.mutation(api.hosting.setWebAlbum, { eventId, on: false });
    await expect((async () => {
      for (;;) if ((await reader.read()).done) return "whole";
    })()).rejects.toThrow();
  });

  test("the notice before the album ends shows on the web album too (V2-FR-48)", async () => {
    const { t, eventId, page, joinCode } = await revealedAlbum();
    expect(await words(await page.get(`/j/${joinCode}`))).not.toContain("This album ends on");
    const revealsAt = Date.now() - 350 * DAY_MS;
    await t.run((ctx) => ctx.db.patch(eventId, { endsAt: revealsAt, revealsAt, revealedAt: revealsAt }));
    expect(await words(await page.get(`/j/${joinCode}`))).toMatch(/This album ends on \d+ \w+ \d{4}\. Save the pictures you want to keep\./);
  });
});
