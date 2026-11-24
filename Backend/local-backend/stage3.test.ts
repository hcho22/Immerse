// Stage 3's web surfaces end to end, in the form Cloudflare hosts them: the join page's Worker running in workerd,
// asking Convex's own local backend over HTTP what it may show, and reading pictures from the R2 stand-in through the
// one-minute addresses the backend signs for it. A Host loads a Group Film, guests join and send pictures through the
// HTTP API the app and the mini-app use, and a browser on an iPhone, an Android phone and a computer opens the link at
// every step: before the reveal, after it with the web album off, on, and off again.
//
// The stand-ins are not Cloudflare, Convex's cloud or a browser: Evidence/NativeApp says what only the real domain, the
// real Worker and real browsers can show.
import { execFile } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { resolve } from "node:path";
import { promisify } from "node:util";
import { afterAll, beforeAll, describe, expect, inject, test } from "vitest";
import { AGENTS, unzip, words } from "../tests/support/web";
import { type JoinPage, startJoinPage } from "./support/join-page";
import { deployFunctions, httpApi, type LocalBackend, startClerkIssuer, startConvexBackend } from "./support/stack";

let backend: LocalBackend;
let clerk: Awaited<ReturnType<typeof startClerkIssuer>>;
let page: JoinPage;
let limited: JoinPage;
let api: ReturnType<typeof httpApi>;
const gatewaySecret = randomBytes(32).toString("base64url");

beforeAll(async () => {
  const storage = inject("storage");
  clerk = await startClerkIssuer();
  backend = await startConvexBackend();
  deployFunctions(backend, {
    CLERK_JWT_ISSUER_DOMAIN: clerk.issuer,
    CLERK_API_URL: clerk.issuer,
    CLERK_SECRET_KEY: "sk_test_stand_in",
    R2_ENDPOINT: storage.endpoint,
    R2_BUCKET: storage.bucket,
    R2_ACCESS_KEY_ID: storage.accessKeyId,
    R2_SECRET_ACCESS_KEY: storage.secretAccessKey,
    R2_REGION: storage.region,
    JOIN_CODE_SECRET: randomBytes(32).toString("base64url"),
    WEB_GATEWAY_SECRET: gatewaySecret,
  });
  api = httpApi(backend);
  page = await startJoinPage({ convexSiteUrl: backend.siteUrl, gatewaySecret });
  limited = await startJoinPage({ convexSiteUrl: backend.siteUrl, gatewaySecret, limit: 3 });
}, 240_000);

afterAll(async () => {
  await page?.stop();
  await limited?.stop();
  backend?.stop();
  await clerk?.close();
});

const sha256 = (bytes: Buffer) => createHash("sha256").update(bytes).digest("base64");
const get = (path: string, agent: string = AGENTS.mac, from: JoinPage = page) =>
  fetch(`${from.url}${path}`, { headers: { "user-agent": agent }, redirect: "manual" });

type Sent = { bytes: Buffer; view: Buffer };

async function send(eventId: string, exposureNumber: number, captureTime: number, guestToken: string): Promise<Sent> {
  const bytes = randomBytes(96 * 1024);
  const view = randomBytes(12 * 1024);
  const anyone = api.as(undefined);
  const address = await anyone.action("pictures:requestUpload", {
    eventId, exposureNumber, captureTime, contentType: "image/jpeg", size: bytes.length, sha256: sha256(bytes),
    view: { size: view.length, sha256: sha256(view) }, guestToken,
  });
  if (!address.ok) throw new Error(`requestUpload refused: ${address.code ?? address.message}`);
  const value = address.value as { url: string; headers: Record<string, string>; view: { url: string; headers: Record<string, string> } };
  expect((await fetch(value.url, { method: "PUT", headers: value.headers, body: bytes })).status).toBe(200);
  expect((await fetch(value.view.url, { method: "PUT", headers: value.view.headers, body: view })).status).toBe(200);
  expect(await anyone.action("pictures:confirmUpload", { eventId, exposureNumber, guestToken })).toMatchObject({ ok: true, value: { status: "stored" } });
  return { bytes, view };
}

describe("the join page and the web album in Cloudflare's runtime, on Convex's local backend", () => {
  let eventId: string;
  let joinCode: string;
  const sent: Sent[] = [];
  let ids: string[] = [];
  const maya = () => api.as(clerk.sessionToken("user_maya", 30 * 60));

  test("an open event: an iPhone gets the way in, an Android phone and a computer the right message, and Apple its files", async () => {
    expect(await maya().mutation("accounts:createAccount", { displayName: "Maya", ageConfirmed: true, ageConfirmation: "birthMonthAndYear" })).toMatchObject({ ok: true });
    const created = await maya().mutation("hosting:create", {
      requestId: randomBytes(16).toString("base64url"), title: "Ana & Leo", camera: "instant", rolls: 2,
      endsAt: Date.now() + 3_600_000, revealDelayMs: 3_600_000, treatmentVersion: "film-look-5",
    });
    expect(created.ok).toBe(true);
    ({ eventId, joinCode } = created.value as { eventId: string; joinCode: string });

    const iphone = await get(`/j/${joinCode}`, AGENTS.iphone26);
    expect(iphone.status).toBe(200);
    expect(iphone.headers.get("cache-control")).toBe("no-store");
    const html = await iphone.clone().text();
    expect(html).toContain(`<meta name="apple-itunes-app" content="app-id=1234567890, app-clip-bundle-id=com.immerse.FilmJournal.Clip, app-clip-display=card">`);
    const text = await words(iphone);
    expect(text).toContain("Ana & Leo");
    expect(text).toContain("Hosted by Maya");
    expect(text).toContain("Instant · 10 exposures a Roll");
    expect(text).toContain("Join on this iPhone");

    for (const agent of [AGENTS.android, AGENTS.mac, AGENTS.firefox]) {
      const response = await get(`/j/${joinCode}`, agent);
      const other = await words(response);
      expect(other).toContain("Shooting needs an iPhone on iOS 26. The pictures will be on this page after the reveal if the Host shares them.");
      expect(other).not.toContain("Join on this iPhone");
    }
    expect(await words(await get(`/j/${joinCode}`, AGENTS.iphone18))).toContain("Shooting needs iOS 26 or later. Update this iPhone to join.");

    const association = await get("/.well-known/apple-app-site-association");
    expect(association.status).toBe(200);
    expect(association.headers.get("content-type")).toBe("application/json");
    expect(await association.json()).toEqual({
      applinks: { details: [{ appIDs: ["TEAM123456.com.immerse.FilmJournal"], components: [{ "/": "/j/*" }] }] },
      appclips: { apps: ["TEAM123456.com.immerse.FilmJournal.Clip"] },
    });
    const missing = await get("/j/NoSuchEventCodeAtAll00", AGENTS.android);
    expect(missing.status).toBe(404);
    expect(await words(missing)).toContain("This event is no longer available.");
  }, 120_000);

  test("before the reveal the page shows no picture, whatever arrived", async () => {
    const tokens: string[] = [];
    for (const name of ["Jo", "Sam"]) {
      const guest = { publicId: randomBytes(18).toString("base64url"), secret: randomBytes(32).toString("base64url") };
      const joined = await api.as(undefined).mutation("joining:join", { code: joinCode, guestName: name, guest });
      expect(joined.ok).toBe(true);
      tokens.push((joined.value as { guestToken: string }).guestToken);
    }
    const start = Date.now() - 60_000;
    sent.push(await send(eventId, 1, start, tokens[1]!));
    sent.push(await send(eventId, 1, start + 1_000, tokens[0]!));
    sent.push(await send(eventId, 2, start + 2_000, tokens[1]!));
    const html = await (await get(`/j/${joinCode}`, AGENTS.android)).text();
    expect(html).not.toMatch(/<img|album\.zip|\/p\//);
    expect((await get(`/j/${joinCode}/album.zip`)).status).toBe(404);
  }, 120_000);

  test("after the reveal, with the web album off, an Android phone and a computer see the title and nothing else", async () => {
    expect(await maya().mutation("hosting:endEarly", { eventId })).toMatchObject({ ok: true });
    const album = await maya().action("reads:album", { eventId });
    expect(album.ok).toBe(true);
    ids = (album.value as { entries: Array<{ pictureId: string }> }).entries.map((entry) => entry.pictureId);
    expect(ids).toHaveLength(3);
    for (const agent of [AGENTS.android, AGENTS.mac]) {
      const response = await get(`/j/${joinCode}`, agent);
      const html = await response.clone().text();
      const text = await words(response);
      expect(text).toContain("Ana & Leo");
      expect(text).toContain("This event's pictures are not shared on the web.");
      expect(html).not.toMatch(/<img|album\.zip|\/p\//);
    }
    for (const id of ids) {
      for (const path of [`/j/${joinCode}/p/${id}/view`, `/j/${joinCode}/p/${id}/full`, `/j/${joinCode}/v/${id}`]) {
        expect((await get(path)).status).toBe(404);
      }
    }
    expect((await get(`/j/${joinCode}/album.zip`)).status).toBe(404);
  }, 120_000);

  test("switched on, they see every picture in capture order, each picture's details, and save one or all", async () => {
    expect(await maya().mutation("hosting:setWebAlbum", { eventId, on: true })).toMatchObject({ ok: true, value: { on: true } });
    for (const agent of [AGENTS.android, AGENTS.mac, AGENTS.firefox]) {
      const response = await get(`/j/${joinCode}`, agent);
      const html = await response.clone().text();
      const text = await words(response);
      expect(text).toContain("3 pictures, in the order they were taken.");
      expect([...html.matchAll(/\/v\/([^"]+)">/g)].map((match) => match[1])).toEqual(ids);
      expect(text).toContain("Shooting needs an iPhone on iOS 26.");
    }
    for (const [index, id] of ids.entries()) {
      const view = await get(`/j/${joinCode}/p/${id}/view`);
      expect(view.status).toBe(200);
      expect(Buffer.from(await view.arrayBuffer()).equals(sent[index]!.view)).toBe(true);
      const full = await get(`/j/${joinCode}/p/${id}/full?download=1`);
      expect(full.headers.get("content-disposition")).toMatch(/^attachment/);
      expect(Buffer.from(await full.arrayBuffer()).equals(sent[index]!.bytes)).toBe(true);
    }
    const details = await words(await get(`/j/${joinCode}/v/${ids[1]}`, AGENTS.android));
    expect(details).toContain("Taken by Jo");
    expect(details).toContain("Camera Instant");
    const zip = await get(`/j/${joinCode}/album.zip`);
    expect(zip.status).toBe(200);
    const entries = unzip(new Uint8Array(await zip.arrayBuffer()));
    expect(entries.map((entry) => entry.name)).toEqual(["001.jpg", "002.jpg", "003.jpg"]);
    for (const [index, entry] of entries.entries()) expect(Buffer.from(entry.bytes).equals(sent[index]!.bytes)).toBe(true);
  }, 120_000);

  test("switched off again, the next picture load fails at once and the page says the pictures are not shared", async () => {
    expect(await maya().mutation("hosting:setWebAlbum", { eventId, on: false })).toMatchObject({ ok: true });
    for (const id of ids) {
      expect((await get(`/j/${joinCode}/p/${id}/view`)).status).toBe(404);
      expect((await get(`/j/${joinCode}/p/${id}/full`)).status).toBe(404);
    }
    expect((await get(`/j/${joinCode}/album.zip`)).status).toBe(404);
    expect(await words(await get(`/j/${joinCode}`, AGENTS.android))).toContain("This event's pictures are not shared on the web.");
  }, 120_000);

  test("a mini-app guest's place and waiting pictures go on from the full app, and the server holds each picture once", async () => {
    // The hand-off on the phone's own Swift client and upload queue (Packages/ImmerseServer, HandOffLocalBackendTests),
    // against this backend: an event of its own, with the one Roll the Host's free Rolls still hold.
    const created = await maya().mutation("hosting:create", {
      requestId: randomBytes(16).toString("base64url"), title: "Hand-off", camera: "disposable", rolls: 1,
      endsAt: Date.now() + 3_600_000, revealDelayMs: 0, treatmentVersion: "film-look-5",
    });
    expect(created.ok).toBe(true);
    const handOff = created.value as { eventId: string; joinCode: string };
    let output: string;
    try {
      output = (
        await promisify(execFile)(
          "swift",
          ["test", "--package-path", resolve(import.meta.dirname, "../../Packages/ImmerseServer"), "--filter", "HandOffLocalBackendTests"],
          {
            env: { ...process.env, IMMERSE_LOCAL_CONVEX_URL: backend.url, IMMERSE_LOCAL_HANDOFF_CODE: handOff.joinCode },
            encoding: "utf8",
            maxBuffer: 16 * 1024 * 1024,
          },
        )
      ).stdout;
    } catch (error) {
      const failed = error as { stdout?: string; stderr?: string };
      throw new Error(`The Swift hand-off test failed:\n${failed.stdout ?? ""}\n${failed.stderr ?? ""}`.slice(-6000));
    }
    expect(output).toMatch(/HandOffLocalBackendTests.*passed/);
    expect(output).not.toMatch(/skipped/);
    // The server's own record: three pictures in the event, no more.
    expect(await maya().mutation("hosting:endEarly", { eventId: handOff.eventId })).toMatchObject({ ok: true });
    const album = await maya().action("reads:album", { eventId: handOff.eventId });
    expect((album.value as { entries: Array<{ shooterName: string }> }).entries.map((entry) => entry.shooterName)).toEqual(["Lee", "Lee", "Lee"]);
  }, 900_000);

  test("one address opening links too fast is told to wait; the Worker without the deployment's secret shows nothing", async () => {
    const statuses: number[] = [];
    for (let attempt = 0; attempt < 5; attempt += 1) {
      statuses.push((await get(`/j/${randomBytes(16).toString("base64url")}`, AGENTS.mac, limited)).status);
    }
    expect(statuses.slice(0, 3)).toEqual([404, 404, 404]);
    expect(statuses.slice(3)).toEqual([429, 429]);
    const stranger = await startJoinPage({ convexSiteUrl: backend.siteUrl, gatewaySecret: randomBytes(32).toString("base64url") });
    try {
      const response = await get(`/j/${joinCode}`, AGENTS.android, stranger);
      expect(response.status).toBe(503);
      expect(await words(response)).not.toContain("Ana");
    } finally {
      await stranger.stop();
    }
  }, 120_000);
});
