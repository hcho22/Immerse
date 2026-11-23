// Stage 1's local stand-ins, started together for the end-to-end run on Convex's own backend:
//
// - Convex's open-source local backend binary, at a pinned release whose download is checked against its SHA-256,
//   started with a fresh instance secret and telemetry off. The CLI's anonymous local deployments need a Convex
//   login since convex 1.51, so the binary is run directly as a self-hosted deployment.
// - A Clerk issuer stand-in serving OpenID discovery and a JWKS, whose session tokens Convex verifies exactly as it
//   verifies Clerk's (auth.config.ts), plus Clerk's Backend API for user deletion.
// - The R2 stand-in (MinIO) and the HTTP/2 stand-in for Apple's push service.
//
// Nothing here reaches a real service.
import { execFileSync, spawn, type ChildProcess } from "node:child_process";
import { createHash, generateKeyPairSync, randomBytes, sign, type KeyObject } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createServer as createHttpServer, type Server } from "node:http";
import { createServer as createNetServer } from "node:net";
import { homedir, tmpdir } from "node:os";
import { join, resolve } from "node:path";

export const CONVEX_BACKEND_RELEASE = "precompiled-2026-11-21-cf39368";
const CONVEX_BACKEND_SHA256: Record<string, string> = {
  "aarch64-apple-darwin": "32530173dcd215b16e296a09f07e17e71f41f3b261136c8469fcb76af6445119",
  "x86_64-apple-darwin": "7e6342aa9fba2d633fbc1f08c282d7b2adaf6dade20683b76292adba65b0c7b5",
  "x86_64-unknown-linux-gnu": "a7bf39daa91535b93a4c59943bcf5c963c3852b021f02be132145500904b5f1d",
  "aarch64-unknown-linux-gnu": "309cab736b37e5af742cf002732d920d453681cc721934c31ff0962a0806a1d7",
};

const backendRoot = resolve(import.meta.dirname, "../..");

export function freePort(): Promise<number> {
  return new Promise((resolvePort, reject) => {
    const server = createNetServer();
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      server.close(() => (typeof address === "object" && address ? resolvePort(address.port) : reject(new Error("no port"))));
    });
  });
}

async function waitFor(url: string, what: string, seconds = 60) {
  for (let attempt = 0; attempt < seconds * 10; attempt += 1) {
    try {
      if ((await fetch(url)).ok) return;
    } catch {
      // Not listening yet.
    }
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error(`${what} did not become ready in ${seconds} seconds`);
}

function platformTriple(): string {
  const arch = process.arch === "arm64" ? "aarch64" : process.arch === "x64" ? "x86_64" : process.arch;
  const os = process.platform === "darwin" ? "apple-darwin" : process.platform === "linux" ? "unknown-linux-gnu" : process.platform;
  return `${arch}-${os}`;
}

// The pinned backend binary, downloaded once into the user's cache and checked before every use.
export async function convexBackendBinary(): Promise<string> {
  const triple = platformTriple();
  const expected = CONVEX_BACKEND_SHA256[triple];
  if (!expected) throw new Error(`No pinned Convex local backend for ${triple}`);
  const cache = join(process.env.XDG_CACHE_HOME || join(homedir(), ".cache"), "immerse", "convex-backend", CONVEX_BACKEND_RELEASE, triple);
  const archive = join(cache, "backend.zip");
  const binary = join(cache, "convex-local-backend");
  const digest = (path: string) => createHash("sha256").update(readFileSync(path)).digest("hex");
  if (!existsSync(archive) || digest(archive) !== expected) {
    mkdirSync(cache, { recursive: true });
    const url = `https://github.com/get-convex/convex-backend/releases/download/${CONVEX_BACKEND_RELEASE}/convex-local-backend-${triple}.zip`;
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Could not download the Convex local backend: HTTP ${response.status}`);
    writeFileSync(archive, Buffer.from(await response.arrayBuffer()));
    if (digest(archive) !== expected) throw new Error("The Convex local backend download does not match its pinned SHA-256");
    rmSync(binary, { force: true });
  }
  if (!existsSync(binary)) execFileSync("unzip", ["-o", "-q", archive, "-d", cache]);
  return binary;
}

// A Clerk stand-in: OpenID discovery and JWKS for session tokens, and the Backend API's user deletion.
export async function startClerkIssuer() {
  const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const kid = randomBytes(8).toString("hex");
  const deletions: string[] = [];
  const port = await freePort();
  const issuer = `http://127.0.0.1:${port}`;
  const server: Server = createHttpServer((request, response) => {
    const send = (status: number, body: unknown) => {
      response.writeHead(status, { "content-type": "application/json" });
      response.end(JSON.stringify(body));
    };
    if (request.url === "/.well-known/openid-configuration") {
      return send(200, { issuer, jwks_uri: `${issuer}/.well-known/jwks.json`, id_token_signing_alg_values_supported: ["RS256"] });
    }
    if (request.url === "/.well-known/jwks.json") {
      return send(200, { keys: [{ ...publicKey.export({ format: "jwk" }), kid, use: "sig", alg: "RS256" }] });
    }
    if (request.method === "DELETE" && request.url?.startsWith("/v1/users/")) {
      deletions.push(decodeURIComponent(request.url.slice("/v1/users/".length)));
      return send(200, { deleted: true });
    }
    send(404, {});
  });
  await new Promise<void>((r) => server.listen(port, "127.0.0.1", r));
  return {
    issuer,
    deletions,
    // A session token as Clerk's Convex integration makes it: RS256, audience "convex", one minute long.
    sessionToken(userId: string, lifetimeSeconds = 60) {
      return signJwt(privateKey, kid, { iss: issuer, sub: userId, aud: "convex", sid: `sess_${userId}` }, lifetimeSeconds);
    },
    close: () => new Promise<void>((r) => server.close(() => r())),
  };
}

function signJwt(key: KeyObject, kid: string, claims: Record<string, unknown>, lifetimeSeconds: number) {
  const now = Math.floor(Date.now() / 1000);
  const encode = (value: unknown) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const header = encode({ alg: "RS256", typ: "JWT", kid });
  const body = encode({ ...claims, iat: now, nbf: now - 5, exp: now + lifetimeSeconds });
  return `${header}.${body}.${sign("RSA-SHA256", Buffer.from(`${header}.${body}`), key).toString("base64url")}`;
}

export type LocalBackend = { url: string; adminKey: string; stop: () => void };

export async function startConvexBackend(): Promise<LocalBackend & { process: ChildProcess }> {
  const binary = await convexBackendBinary();
  const port = await freePort();
  const sitePort = await freePort();
  const state = mkdtempSync(join(tmpdir(), "immerse-convex-"));
  const instanceName = "immerse-local";
  const instanceSecret = randomBytes(32).toString("hex");
  const adminKey = execFileSync(binary, ["keygen", "admin-key", "--instance-name", instanceName, "--instance-secret", instanceSecret]).toString().trim();
  const child = spawn(
    binary,
    [
      "--port", String(port), "--site-proxy-port", String(sitePort),
      "--instance-name", instanceName, "--instance-secret", instanceSecret,
      "--local-storage", join(state, "storage"), "--disable-beacon", join(state, "convex.sqlite3"),
    ],
    { stdio: ["ignore", "ignore", "pipe"] },
  );
  let log = "";
  child.stderr?.on("data", (chunk) => (log = (log + chunk).slice(-20_000)));
  const url = `http://127.0.0.1:${port}`;
  try {
    await waitFor(`${url}/version`, "The Convex local backend");
  } catch (error) {
    child.kill();
    throw new Error(`${(error as Error).message}\n${log}`);
  }
  return {
    url,
    adminKey,
    process: child,
    stop: () => {
      child.kill("SIGTERM");
      rmSync(state, { recursive: true, force: true });
    },
  };
}

// Sets the deployment's environment and pushes the functions with Convex's own CLI, as a real deployment is pushed.
export function deployFunctions(backend: LocalBackend, environment: Record<string, string>) {
  const env = { ...process.env, CONVEX_SELF_HOSTED_URL: backend.url, CONVEX_SELF_HOSTED_ADMIN_KEY: backend.adminKey };
  const cli = join(backendRoot, "node_modules", ".bin", "convex");
  for (const [name, value] of Object.entries(environment)) {
    execFileSync(cli, ["env", "set", "--", name, value], { cwd: backendRoot, env, stdio: ["ignore", "ignore", "pipe"] });
  }
  execFileSync(cli, ["deploy", "--yes", "--codegen", "disable"], { cwd: backendRoot, env, stdio: ["ignore", "ignore", "pipe"] });
}

// Convex's HTTP API, the way the app calls it: a bearer session token, or the deployment key for internal functions.
export function httpApi(backend: LocalBackend) {
  async function call(kind: "query" | "mutation" | "action", path: string, args: object, authorization?: string) {
    const response = await fetch(`${backend.url}/api/${kind}`, {
      method: "POST",
      headers: { "content-type": "application/json", ...(authorization ? { authorization } : {}) },
      body: JSON.stringify({ path, args, format: "json" }),
    });
    const text = await response.text();
    let body: { status?: string; value?: unknown; errorMessage?: string; errorData?: { code?: string } };
    try {
      body = JSON.parse(text);
    } catch {
      return { ok: false as const, httpStatus: response.status, code: undefined, message: text };
    }
    if (response.ok && body.status === "success") return { ok: true as const, httpStatus: response.status, value: body.value };
    return { ok: false as const, httpStatus: response.status, code: body.errorData?.code, message: body.errorMessage ?? text };
  }
  return {
    as: (token: string | undefined) => ({
      query: (path: string, args: object = {}) => call("query", path, args, token ? `Bearer ${token}` : undefined),
      mutation: (path: string, args: object = {}) => call("mutation", path, args, token ? `Bearer ${token}` : undefined),
      action: (path: string, args: object = {}) => call("action", path, args, token ? `Bearer ${token}` : undefined),
    }),
    admin: {
      mutation: (path: string, args: object = {}) => call("mutation", path, args, `Convex ${backend.adminKey}`),
      action: (path: string, args: object = {}) => call("action", path, args, `Convex ${backend.adminKey}`),
      query: (path: string, args: object = {}) => call("query", path, args, `Convex ${backend.adminKey}`),
    },
  };
}
