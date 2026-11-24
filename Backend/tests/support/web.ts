// The join page's Worker (worker/src) run in the test's own process against the in-memory Convex backend: its requests
// to the deployment go to the backend's HTTP routes, and its requests to storage go to the R2 stand-in. The same
// Worker runs in Cloudflare's own runtime in local-backend/stage3.test.ts.
import { createWorker, type Env } from "../../worker/src/index";
import type { Backend } from "./convex";

export const CONVEX_SITE = "https://deployment.convex.site";
export const JOIN_HOST = "https://join.immerse.test";

export const AGENTS = {
  iphone26: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1",
  iphone18: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1",
  iphone15: "Mozilla/5.0 (iPhone; CPU iPhone OS 15_8 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
  iphoneInApp: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
  android: "Mozilla/5.0 (Linux; Android 16; Pixel 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36",
  mac: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15",
  firefox: "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0",
};

export function gatewayHeaders(secret = process.env.WEB_GATEWAY_SECRET) {
  return { "content-type": "application/json", authorization: `Bearer ${secret}` };
}

// The deployment's answer to the Worker's own question, asked directly.
export async function askDeployment(t: Backend, path: "/web/page" | "/web/picture", body: unknown, secret?: string) {
  const response = await t.fetch(path, { method: "POST", headers: gatewayHeaders(secret), body: JSON.stringify(body) });
  return { status: response.status, body: (await response.json()) as Record<string, any> };
}

export function joinPageWorker(t: Backend, overrides: Partial<Env> = {}) {
  const worker = createWorker((input, init) =>
    input.startsWith(CONVEX_SITE) ? t.fetch(input.slice(CONVEX_SITE.length), init) : fetch(input, init),
  );
  const env: Env = {
    CONVEX_SITE_URL: CONVEX_SITE,
    WEB_GATEWAY_SECRET: process.env.WEB_GATEWAY_SECRET,
    APPLE_TEAM_ID: "TEAM123456",
    APP_BUNDLE_ID: "com.immerse.FilmJournal",
    APP_CLIP_BUNDLE_ID: "com.immerse.FilmJournal.Clip",
    APP_STORE_ID: "1234567890",
    SUPPORT_ADDRESS: "support@immerse.test",
    ...overrides,
  };
  return {
    env,
    get: (path: string, userAgent: string = AGENTS.mac, headers: Record<string, string> = {}) =>
      worker.fetch(new Request(`${JOIN_HOST}${path}`, { headers: { "user-agent": userAgent, ...headers } }), env),
    request: (path: string, init: RequestInit) => worker.fetch(new Request(`${JOIN_HOST}${path}`, init), env),
  };
}

// A page's words as a reader gets them: tags and the page's own style and script removed.
export async function words(response: Response): Promise<string> {
  const html = await response.text();
  return html
    .replace(/<style[\s\S]*?<\/style>/g, " ")
    .replace(/<script[\s\S]*?<\/script>/g, " ")
    .replace(/<\/?(time|strong|a|span)\b[^>]*>/g, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}

// The entries of a ZIP file that stores its entries, read back from its central directory.
export function unzip(bytes: Uint8Array) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const end = bytes.length - 22;
  if (view.getUint32(end, true) !== 0x06054b50) throw new Error("no end record");
  const count = view.getUint16(end + 10, true);
  let at = view.getUint32(end + 16, true);
  const entries: Array<{ name: string; crc32: number; bytes: Uint8Array }> = [];
  for (let index = 0; index < count; index += 1) {
    if (view.getUint32(at, true) !== 0x02014b50) throw new Error("no central header");
    const crc32 = view.getUint32(at + 16, true);
    const size = view.getUint32(at + 24, true);
    const nameLength = view.getUint16(at + 28, true);
    const local = view.getUint32(at + 42, true);
    const name = new TextDecoder().decode(bytes.subarray(at + 46, at + 46 + nameLength));
    if (view.getUint32(local, true) !== 0x04034b50) throw new Error("no local header");
    const dataAt = local + 30 + view.getUint16(local + 26, true) + view.getUint16(local + 28, true);
    entries.push({ name, crc32, bytes: bytes.subarray(dataAt, dataAt + size) });
    at += 46 + nameLength;
  }
  return entries;
}
