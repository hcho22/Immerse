// Stage 2 end to end on Convex's own backend, through the HTTP API the app uses, with the backend's real scheduler: a
// Host loads a Group Film, guests join through its Join Code, pictures go up sealed with their viewing copies, nobody
// reads one before the reveal, shooting stops and unclaimed Rolls return at the End Time, the album reveals at End
// Time plus Reveal Delay with no client acting, "Your Film is ready" reaches the members' phones through the HTTP/2
// stand-in, a guest who shot "offline" comes online after the reveal and every picture taken reaches the album in
// capture order, a report reaches the support relay, and deleting the event removes its pictures from storage.
//
// It also measures what the event used in the units section 10 prices (open check OC-2): the Convex function calls
// the clients made, and R2 Class A and Class B operations and bytes through a counting proxy in front of the R2
// stand-in. IMMERSE_COST_REPORT names a file to write the counts to. The stand-ins are not the real services;
// Evidence/NativeApp says what only Convex's and Cloudflare's own meters can confirm.
import { createHash, randomBytes } from "node:crypto";
import { writeFileSync } from "node:fs";
import { afterAll, beforeAll, describe, expect, inject, test } from "vitest";
import { startApnsDouble } from "../tests/support/apns-double";
import { startSupportRelay } from "../tests/support/webhook-double";
import { startCountingProxy } from "./support/counting-proxy";
import { deployFunctions, httpApi, type LocalBackend, startClerkIssuer, startConvexBackend } from "./support/stack";

let backend: LocalBackend;
let clerk: Awaited<ReturnType<typeof startClerkIssuer>>;
let apns: Awaited<ReturnType<typeof startApnsDouble>>;
let relay: Awaited<ReturnType<typeof startSupportRelay>>;
let proxy: Awaited<ReturnType<typeof startCountingProxy>>;
let api: ReturnType<typeof httpApi>;
// Public function calls the clients made, by function.
const calls = new Map<string, number>();

type Caller = ReturnType<ReturnType<typeof httpApi>["as"]>;

function counted(caller: Caller): Caller {
  const count = (path: string) => calls.set(path, (calls.get(path) ?? 0) + 1);
  return {
    query: (path, args = {}) => (count(path), caller.query(path, args)),
    mutation: (path, args = {}) => (count(path), caller.mutation(path, args)),
    action: (path, args = {}) => (count(path), caller.action(path, args)),
  };
}

beforeAll(async () => {
  const storage = inject("storage");
  proxy = await startCountingProxy(storage.endpoint);
  clerk = await startClerkIssuer();
  apns = await startApnsDouble();
  relay = await startSupportRelay();
  backend = await startConvexBackend();
  deployFunctions(backend, {
    CLERK_JWT_ISSUER_DOMAIN: clerk.issuer,
    CLERK_API_URL: clerk.issuer,
    CLERK_SECRET_KEY: "sk_test_stand_in",
    R2_ENDPOINT: proxy.endpoint,
    R2_BUCKET: storage.bucket,
    R2_ACCESS_KEY_ID: storage.accessKeyId,
    R2_SECRET_ACCESS_KEY: storage.secretAccessKey,
    R2_REGION: storage.region,
    JOIN_CODE_SECRET: randomBytes(32).toString("base64url"),
    SUPPORT_REPORT_WEBHOOK_URL: process.env.SUPPORT_REPORT_WEBHOOK_URL!,
    SUPPORT_REPORT_WEBHOOK_SECRET: process.env.SUPPORT_REPORT_WEBHOOK_SECRET!,
    ...apns.config,
  });
  api = httpApi(backend);
}, 240_000);

afterAll(async () => {
  backend?.stop();
  await clerk?.close();
  await apns?.close();
  await relay?.close();
  await proxy?.close();
});

type Guest = { publicId: string; secret: string };
const newGuest = (): Guest => ({ publicId: randomBytes(18).toString("base64url"), secret: randomBytes(32).toString("base64url") });
const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
const sha256 = (bytes: Buffer) => createHash("sha256").update(bytes).digest("base64");

// Sizes for the run: small, so it stays quick; the cost model scales the measured counts by real sizes.
const PICTURE_BYTES = 256 * 1024;
const VIEW_BYTES = 32 * 1024;
const PER_SHOOTER = 3;

// One developed picture and its viewing copy through the upload path, as the app's PictureUploader sends them.
async function send(caller: Caller, eventId: string, exposureNumber: number, captureTime: number, guestToken?: string) {
  const bytes = randomBytes(PICTURE_BYTES);
  const view = randomBytes(VIEW_BYTES);
  const token = guestToken ? { guestToken } : {};
  const address = await caller.action("pictures:requestUpload", {
    eventId, exposureNumber, captureTime, contentType: "image/jpeg", size: bytes.length, sha256: sha256(bytes),
    view: { size: view.length, sha256: sha256(view) }, ...token,
  });
  if (!address.ok) throw new Error(`requestUpload refused: ${address.code ?? address.message}`);
  const value = address.value as { url: string; headers: Record<string, string>; view: { url: string; headers: Record<string, string> } };
  expect((await fetch(value.url, { method: "PUT", headers: value.headers, body: bytes })).status).toBe(200);
  expect((await fetch(value.view.url, { method: "PUT", headers: value.view.headers, body: view })).status).toBe(200);
  expect(await caller.action("pictures:confirmUpload", { eventId, exposureNumber, ...token })).toMatchObject({
    ok: true, value: { status: "stored" },
  });
}

type AlbumEntry = { number: number; removed: boolean; shooterName?: string; url?: string; viewUrl?: string; pictureId?: string };

describe("a whole event on Convex's local backend with its real scheduler", () => {
  let eventId: string;
  let joinCode: string;
  let revealsAt: number;
  let startedAt: number;
  const guests: Record<string, Guest> = {};
  const tokens: Record<string, string> = {};
  let taken = 0;
  const maya = () => counted(api.as(clerk.sessionToken("user_maya", 30 * 60)));
  const anyone = () => counted(api.as(undefined));

  test("the Host loads a Film, guests join with a name only, pictures go up sealed, and nobody can read one", async () => {
    expect(await maya().mutation("accounts:createAccount", { displayName: "Maya", ageConfirmed: true, ageConfirmation: "birthMonthAndYear" })).toMatchObject({ ok: true });
    calls.clear();
    proxy.reset();
    startedAt = Date.now();
    const created = await maya().mutation("hosting:create", {
      requestId: randomBytes(16).toString("base64url"), title: "Ana & Leo", camera: "disposable", rolls: 3,
      endsAt: startedAt + 30_000, revealDelayMs: 10_000, treatmentVersion: "film-look-5",
    });
    expect(created.ok).toBe(true);
    ({ eventId, joinCode } = created.value as { eventId: string; joinCode: string });
    revealsAt = startedAt + 40_000;
    for (const name of ["Jo", "Sam"]) {
      guests[name] = newGuest();
      expect(await anyone().query("joining:preview", { code: joinCode, guest: guests[name] })).toMatchObject({
        ok: true, value: { status: "open", event: { title: "Ana & Leo", hostName: "Maya", exposuresPerRoll: 27 } },
      });
      const joined = await anyone().mutation("joining:join", { code: joinCode, guestName: name, guest: guests[name] });
      expect(joined.ok).toBe(true);
      tokens[name] = (joined.value as { guestToken: string }).guestToken;
    }
    expect(await maya().mutation("joining:join", { code: joinCode, guestName: "Maya" })).toMatchObject({ ok: true });
    expect(await anyone().query("joining:preview", { code: joinCode })).toMatchObject({ ok: true, value: { status: "full" } });
    await maya().mutation("pushTokens:register", { installationId: randomBytes(18).toString("base64url"), token: "a1".repeat(32), environment: "sandbox" });
    await anyone().mutation("pushTokens:registerGuest", {
      installationId: randomBytes(18).toString("base64url"), token: "b2".repeat(32), environment: "sandbox", guest: guests.Jo,
    });
    // Jo and the Host upload while the event is open; Sam shoots offline, and sends later.
    for (let exposure = 1; exposure <= PER_SHOOTER; exposure += 1) {
      await send(anyone(), eventId, exposure, Date.now(), tokens.Jo);
      await send(maya(), eventId, exposure, Date.now());
    }
    taken = 3 * PER_SHOOTER;
    expect(await maya().action("reads:album", { eventId })).toMatchObject({ ok: false, code: "sealed" });
    expect(await anyone().action("reads:album", { eventId, guestToken: tokens.Jo })).toMatchObject({ ok: false, code: "sealed" });
    expect(await maya().query("hosting:view", { eventId })).toMatchObject({
      ok: true, value: { phase: "open", picturesArrived: 2 * PER_SHOOTER, rolls: { taken: 3, free: 0 } },
    });
  }, 120_000);

  test("the event ends and reveals on time with every client idle, and the alert reaches the members once", async () => {
    // No client calls anything until after the reveal: the backend's scheduler runs the end and the reveal.
    while (Date.now() < revealsAt + 3_000) await sleep(500);
    const measures = await api.admin.query("measures:eventMeasures", { eventId });
    expect(measures.ok).toBe(true);
    const counts = measures.value as { revealLateByMs: number; rollsTaken: number };
    // Within a minute of its time (success measure M-3, on the stand-in).
    expect(counts.revealLateByMs).toBeGreaterThanOrEqual(0);
    expect(counts.revealLateByMs).toBeLessThan(60_000);
    expect(await maya().query("hosting:view", { eventId })).toMatchObject({ ok: true, value: { phase: "revealed" } });
    for (let attempt = 0; attempt < 50 && apns.requests.length < 2; attempt += 1) await sleep(200);
    expect(apns.requests.map((request) => request.path.split("/").pop()).sort()).toEqual(["a1".repeat(32), "b2".repeat(32)]);
  }, 120_000);

  test("a guest who shot offline comes online after the reveal: every picture taken reaches the album in capture order", async () => {
    const session = await anyone().mutation("guests:startSession", { ...guests.Sam, eventId });
    expect(session.ok).toBe(true);
    const token = (session.value as { token: string }).token;
    // Sam's pictures were taken first, right as the event opened, before anyone else's.
    for (let exposure = 1; exposure <= PER_SHOOTER; exposure += 1) {
      await send(anyone(), eventId, exposure, startedAt + exposure, token);
    }
    // Every member loads the album once (viewing copies) and saves every picture once (full pictures).
    const josToken = ((await anyone().mutation("guests:startSession", { ...guests.Jo, eventId })).value as { token: string }).token;
    const readers: Array<[Caller, Record<string, string>]> = [
      [maya(), {}],
      [anyone(), { guestToken: josToken }],
      [anyone(), { guestToken: token }],
    ];
    let album: AlbumEntry[] = [];
    for (const [reader, extra] of readers) {
      const reply = await reader.action("reads:album", { eventId, ...extra });
      expect(reply.ok).toBe(true);
      album = (reply.value as { entries: AlbumEntry[] }).entries;
      for (const entry of album) expect((await fetch(entry.viewUrl!)).status).toBe(200);
      for (const entry of album) expect((await fetch(entry.url!)).status).toBe(200);
    }
    // M-1 on the stand-in: every picture taken is in the album.
    expect(album.filter((entry) => !entry.removed)).toHaveLength(taken);
    expect(album[0]!.shooterName).toBe("Sam");
    expect(album.map((entry) => entry.number)).toEqual(Array.from({ length: taken }, (_, index) => index + 1));
  }, 120_000);

  test("a report reaches the support relay; deleting the event removes its pictures from storage", async () => {
    const jo = (await anyone().mutation("guests:startSession", { ...guests.Jo, eventId })).value as { token: string };
    const album = (await maya().action("reads:album", { eventId })).value as { entries: AlbumEntry[] };
    const samsPicture = album.entries.find((entry) => entry.shooterName === "Sam")!;
    expect(await anyone().mutation("reports:report", { eventId, guestToken: jo.token, pictureId: samsPicture.pictureId, reason: "other" })).toMatchObject({ ok: true });
    for (let attempt = 0; attempt < 50 && relay.received.length === 0; attempt += 1) await sleep(200);
    expect(relay.received[0]!.body).toMatchObject({ type: "picture.reported", eventTitle: "Ana & Leo", reason: "other" });
    const report = {
      functionCalls: Object.fromEntries([...calls].sort()),
      storage: { ...proxy.counts },
      measures: (await api.admin.query("measures:eventMeasures", { eventId })).value,
      shooters: 3,
      picturesPerShooter: PER_SHOOTER,
      members: 3,
      pictureBytes: PICTURE_BYTES,
      viewBytes: VIEW_BYTES,
    };
    if (process.env.IMMERSE_COST_REPORT) writeFileSync(process.env.IMMERSE_COST_REPORT, `${JSON.stringify(report, null, 2)}\n`);
    expect(await maya().mutation("hosting:deleteEvent", { eventId })).toMatchObject({ ok: true });
    let status = 0;
    for (let attempt = 0; attempt < 300 && status !== 404; attempt += 1) {
      status = (await fetch(samsPicture.url!)).status;
      if (status !== 404) await sleep(200);
    }
    expect(status).toBe(404);
    expect(await anyone().query("joining:preview", { code: joinCode })).toMatchObject({ ok: true, value: { status: "unavailable" } });
  }, 120_000);
});
