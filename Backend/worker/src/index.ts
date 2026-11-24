// The join page and the view-only web album (v2 PRD V2-FR-15, V2-FR-18, V2-FR-20, V2-FR-47, section 9.4): a Cloudflare
// Worker on the join host, the one host a Group Film's link and QR code name (https://<join host>/j/<code>).
//
// It serves:
//
// - `/j/<code>`: what the link shows in a browser. On an iPhone that can shoot, the way into the mini-app or the full
//   app; for everyone who cannot join here, why, in V2-FR-18's words; after the reveal, the album while the Host shares
//   it on the web, and only the event's title and the not-shared message while the Host does not.
// - `/j/<code>/v/<picture>`, `/j/<code>/p/<picture>/view|full` and `/j/<code>/album.zip`: one picture with its
//   details, its bytes, and the album as a ZIP file, all only while the album is shared.
// - `/.well-known/apple-app-site-association`: the file Apple reads to let the link open the full app and the App
//   Clip, made from configuration.
//
// The Worker decides nothing and holds no storage credential. For every page and every picture it asks the Convex
// deployment (Backend/convex/web.ts), which alone knows whether the event has revealed and whether its web album is
// on, and which alone signs a read address. So switching the album off stops the next picture, and a bug here cannot
// read a sealed picture. Every value that names the operator's services is configuration (wrangler.jsonc), never in
// the repository.
import { deviceFor } from "./device";
import {
  type AlbumEntry,
  type AlbumPart,
  type AppLinks,
  joinPage,
  type LivePage,
  messagePage,
  type Page,
  picturePage,
} from "./pages";
import { partsOf, type ZipEntry, zipSize, zipStream } from "./zip";

// Cloudflare's rate limiting binding: `limit` answers whether this key is still within its allowance.
type RateLimiter = { limit(options: { key: string }): Promise<{ success: boolean }> };

export interface Env {
  // The Convex deployment's HTTP actions address, https://<name>.convex.site, and the secret shared with it.
  CONVEX_SITE_URL?: string;
  WEB_GATEWAY_SECRET?: string;
  // Apple's identifiers for the association file and the App Clip card.
  APPLE_TEAM_ID?: string;
  APP_BUNDLE_ID?: string;
  APP_CLIP_BUNDLE_ID?: string;
  APP_STORE_ID?: string;
  // The support address shown on every page (V2-FR-54).
  SUPPORT_ADDRESS?: string;
  // How many pictures one part of the album's download holds. The Worker makes two requests of its own for each, so
  // this stays under half the plan's limit on them.
  ALBUM_PART_PICTURES?: string;
  // Per-address limit on opening links, which is where a Join Code could be guessed at (V2-FR-15, RK-V2-10).
  JOIN_LIMITER?: RateLimiter;
}

const JOIN_CODE = /^[A-Za-z0-9_-]{22}$/;
const PICTURE_ID = /^[A-Za-z0-9_-]{1,64}$/;
// One part of the download stays far below the ZIP format's 4 GiB, and small enough for a phone to keep.
const PART_BYTES = 1_000_000_000;
const DEFAULT_PART_PICTURES = 20;

type Fetch = (input: string, init?: RequestInit) => Promise<Response>;

function nonce(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return btoa(String.fromCharCode(...bytes));
}

// Nothing is cached, nothing is indexed, the link (which carries the Join Code) is never sent on as a referrer, and
// the page loads nothing from anywhere else and runs only its own script.
function pageHeaders(scriptNonce: string): Headers {
  return new Headers({
    "content-type": "text/html; charset=utf-8",
    "cache-control": "no-store",
    "referrer-policy": "no-referrer",
    "x-robots-tag": "noindex, nofollow",
    "x-content-type-options": "nosniff",
    "x-frame-options": "DENY",
    "content-security-policy": `default-src 'none'; img-src 'self'; style-src 'nonce-${scriptNonce}'; script-src 'nonce-${scriptNonce}'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`,
  });
}

function html(body: string, status: number, scriptNonce: string): Response {
  return new Response(body, { status, headers: pageHeaders(scriptNonce) });
}

function links(env: Env): AppLinks {
  const clean = (value: string | undefined) => (value !== undefined && value.trim() !== "" ? value.trim() : undefined);
  const digits = clean(env.APP_STORE_ID);
  return {
    appStoreId: digits !== undefined && /^\d{6,12}$/.test(digits) ? digits : undefined,
    appClipBundleId: clean(env.APP_CLIP_BUNDLE_ID),
    supportAddress: clean(env.SUPPORT_ADDRESS),
  };
}

function message(text: string, status: number, env: Env): Response {
  const scriptNonce = nonce();
  return html(messagePage(text, links(env), scriptNonce), status, scriptNonce);
}

// Apple's association file: the full app opens the link as a universal link, and the App Clip is allowed to open from
// it. Served only once the identifiers are configured.
function associationFile(env: Env): Response {
  const team = env.APPLE_TEAM_ID?.trim();
  const app = env.APP_BUNDLE_ID?.trim();
  const clip = env.APP_CLIP_BUNDLE_ID?.trim();
  if (!team || !app) return new Response("Not configured", { status: 404 });
  const file: Record<string, unknown> = {
    applinks: { details: [{ appIDs: [`${team}.${app}`], components: [{ "/": "/j/*" }] }] },
  };
  if (clip) file.appclips = { apps: [`${team}.${clip}`] };
  return new Response(JSON.stringify(file), {
    headers: { "content-type": "application/json", "cache-control": "public, max-age=3600" },
  });
}

async function askConvex(env: Env, fetcher: Fetch, path: string, body: unknown): Promise<Response | null> {
  if (!env.CONVEX_SITE_URL || !env.WEB_GATEWAY_SECRET) return null;
  try {
    return await fetcher(`${env.CONVEX_SITE_URL.replace(/\/+$/, "")}${path}`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${env.WEB_GATEWAY_SECRET}` },
      body: JSON.stringify(body),
    });
  } catch {
    return null;
  }
}

async function pageFor(env: Env, fetcher: Fetch, code: string): Promise<Page | null> {
  const response = await askConvex(env, fetcher, "/web/page", { code });
  if (response === null || !response.ok) return null;
  try {
    return (await response.json()) as Page;
  } catch {
    return null;
  }
}

type Stored = Extract<AlbumEntry, { removed: false }>;

function partPictures(env: Env): number {
  const value = Number(env.ALBUM_PART_PICTURES);
  return Number.isInteger(value) && value >= 1 && value <= 400 ? value : DEFAULT_PART_PICTURES;
}

// The album's download in parts. Only pictures whose checksum the server holds can be written to a ZIP file.
function downloadParts(env: Env, entries: AlbumEntry[]): Stored[][] {
  const stored = entries.filter((entry): entry is Stored => !entry.removed && entry.crc32 !== null);
  return partsOf(stored, partPictures(env), PART_BYTES);
}

function describeParts(parts: Stored[][]): AlbumPart[] {
  return parts.map((part, index) => ({
    number: index + 1,
    from: part[0]!.number,
    to: part[part.length - 1]!.number,
    bytes: part.reduce((sum, entry) => sum + entry.size, 0),
  }));
}

function extension(contentType: string): string {
  return contentType === "image/heic" ? "heic" : "jpg";
}

function fileName(entry: Stored, count: number): string {
  const width = Math.max(3, String(count).length);
  return `${String(entry.number).padStart(width, "0")}.${extension(entry.contentType)}`;
}

// One picture's bytes, through a read address the server signed for this request alone. The address never leaves the
// Worker.
async function pictureBytes(env: Env, fetcher: Fetch, code: string, pictureId: string, copy: "view" | "full") {
  const grant = await askConvex(env, fetcher, "/web/picture", { code, pictureId, copy });
  if (grant === null) return { status: 503 as const };
  if (!grant.ok) return { status: 404 as const };
  const granted = (await grant.json()) as { granted: boolean; url?: string; contentType?: string; size?: number };
  if (!granted.granted || !granted.url) return { status: 404 as const };
  let stored: Response;
  try {
    stored = await fetcher(granted.url);
  } catch {
    return { status: 503 as const };
  }
  if (!stored.ok || stored.body === null) return { status: 404 as const };
  return { status: 200 as const, body: stored.body, contentType: granted.contentType ?? "image/jpeg", size: granted.size ?? 0 };
}

const NOT_SHARED = "This event's pictures are not shared on the web.";
const UNREACHABLE = "Immerse could not be reached just now. Try again in a moment.";

async function handle(request: Request, env: Env, fetcher: Fetch): Promise<Response> {
  const url = new URL(request.url);
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method not allowed", { status: 405, headers: { allow: "GET, HEAD" } });
  }
  if (url.pathname === "/.well-known/apple-app-site-association") return associationFile(env);
  if (url.pathname === "/robots.txt") {
    return new Response("User-agent: *\nDisallow: /\n", { headers: { "content-type": "text/plain; charset=utf-8" } });
  }
  if (url.pathname === "/") {
    return message("Open a Group Film's link or scan its QR code to join.", 200, env);
  }
  const parts = url.pathname.split("/").filter((part) => part !== "");
  if (parts[0] !== "j" || parts.length < 2 || !JOIN_CODE.test(parts[1]!)) {
    return message("This event is no longer available.", 404, env);
  }
  const code = parts[1]!;

  // A picture's bytes.
  if (parts.length === 5 && parts[2] === "p" && PICTURE_ID.test(parts[3]!) && (parts[4] === "view" || parts[4] === "full")) {
    const picture = await pictureBytes(env, fetcher, code, parts[3]!, parts[4]);
    if (picture.status !== 200) return new Response(picture.status === 503 ? UNREACHABLE : NOT_SHARED, { status: picture.status, headers: { "cache-control": "no-store" } });
    const headers = new Headers({
      "content-type": picture.contentType,
      "content-length": String(picture.size),
      "cache-control": "private, no-store",
      "referrer-policy": "no-referrer",
      "x-robots-tag": "noindex, nofollow",
      "x-content-type-options": "nosniff",
    });
    if (url.searchParams.get("download") === "1") {
      headers.set("content-disposition", `attachment; filename="immerse-${parts[3]!.slice(0, 8)}.${extension(picture.contentType)}"`);
    }
    return new Response(request.method === "HEAD" ? null : picture.body, { headers });
  }

  // Opening a link is where a Join Code could be guessed at: at most so many a minute from one address.
  if (env.JOIN_LIMITER) {
    const address = request.headers.get("cf-connecting-ip") ?? "unknown";
    if (!(await env.JOIN_LIMITER.limit({ key: address })).success) {
      const response = message("Too many tries from this connection. Wait a minute and open the link again.", 429, env);
      response.headers.set("retry-after", "60");
      return response;
    }
  }

  const page = await pageFor(env, fetcher, code);
  if (page === null) return message(UNREACHABLE, 503, env);
  const device = deviceFor(request.headers.get("user-agent"));
  const scriptNonce = nonce();
  const shared = page.status === "revealed" && page.album !== null ? (page as LivePage & { album: AlbumEntry[] }) : null;

  // The link's page.
  if (parts.length === 2) {
    const rendered = joinPage({
      code,
      page,
      device,
      links: links(env),
      parts: shared ? describeParts(downloadParts(env, shared.album)) : [],
      nonce: scriptNonce,
    });
    return html(rendered.html, rendered.status, scriptNonce);
  }

  // Everything below is the album's, and exists only while it is shared on the web.
  if (shared === null) {
    const live = page.status !== "unknown" && page.status !== "unavailable" && page.status !== "replaced";
    return message(live ? NOT_SHARED : "This event is no longer available.", 404, env);
  }

  // One picture with its details.
  if (parts.length === 4 && parts[2] === "v" && PICTURE_ID.test(parts[3]!)) {
    const entry = shared.album.find((candidate): candidate is Stored => !candidate.removed && candidate.pictureId === parts[3]);
    if (entry === undefined) return message("This picture is no longer in the album.", 404, env);
    return html(picturePage({ code, event: shared.event, entry, links: links(env), nonce: scriptNonce }), 200, scriptNonce);
  }

  // The album, or one part of it, as a ZIP file.
  if (parts.length === 3 && parts[2] === "album.zip") {
    const all = downloadParts(env, shared.album);
    const wanted = Number(url.searchParams.get("part") ?? "1");
    const part = Number.isInteger(wanted) ? all[wanted - 1] : undefined;
    if (part === undefined) return message("This part of the album is not there. Open the album again.", 404, env);
    const entries: ZipEntry[] = part.map((entry) => ({
      name: fileName(entry, shared.album.length),
      size: entry.size,
      crc32: entry.crc32!,
      modified: new Date(entry.captureTime),
      body: async () => {
        const picture = await pictureBytes(env, fetcher, code, entry.pictureId, "full");
        if (picture.status !== 200 || picture.size !== entry.size) throw new Error("The picture is no longer shared");
        return picture.body;
      },
    }));
    const name = all.length === 1 ? "immerse-album.zip" : `immerse-album-part-${wanted}.zip`;
    return new Response(request.method === "HEAD" ? null : zipStream(entries), {
      headers: {
        "content-type": "application/zip",
        "content-length": String(zipSize(entries)),
        "content-disposition": `attachment; filename="${name}"`,
        "cache-control": "private, no-store",
        "referrer-policy": "no-referrer",
        "x-robots-tag": "noindex, nofollow",
      },
    });
  }

  return message("This event is no longer available.", 404, env);
}

// The Worker with the network it uses given to it, so the tests can stand a local server in for Convex's.
export function createWorker(fetcher: Fetch = (input, init) => fetch(input, init)) {
  return {
    fetch: (request: Request, env: Env): Promise<Response> => handle(request, env, fetcher),
  };
}

export default createWorker();
