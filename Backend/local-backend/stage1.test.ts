// Stage 1 end to end on Convex's own backend, through the HTTP API the app uses: sign-in verified against a Clerk
// issuer, the age-confirmed Account, a picture-sized upload to the R2 stand-in through a one-time address, its
// confirmation by size and checksum, sealing until the reveal, the push to an HTTP/2 stand-in for Apple's service
// from a Node action, and Delete Account. The convex-test suites (tests/) hold every case; this run shows the same
// functions work on the real runtime, with real token verification and real network calls.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { createHash, randomBytes } from "node:crypto";
import { resolve } from "node:path";
import { afterAll, beforeAll, describe, expect, inject, test } from "vitest";
import { startApnsDouble } from "../tests/support/apns-double";
import { deployFunctions, httpApi, type LocalBackend, startClerkIssuer, startConvexBackend } from "./support/stack";

let backend: LocalBackend;
let clerk: Awaited<ReturnType<typeof startClerkIssuer>>;
let apns: Awaited<ReturnType<typeof startApnsDouble>>;
let api: ReturnType<typeof httpApi>;

beforeAll(async () => {
  const storage = inject("storage");
  clerk = await startClerkIssuer();
  apns = await startApnsDouble();
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
    ...apns.config,
  });
  api = httpApi(backend);
}, 240_000);

afterAll(async () => {
  backend?.stop();
  await clerk?.close();
  await apns?.close();
});

const picture = randomBytes(4 * 1024 * 1024);
const pictureSha256 = createHash("sha256").update(picture).digest("base64");

describe("Stage 1 on Convex's local backend", () => {
  let eventId: string;

  test("a request without a valid Clerk session is refused", async () => {
    expect(await api.as(undefined).query("accounts:me")).toMatchObject({ ok: true, value: { state: "signedOut" } });
    const refused = await api.as(undefined).mutation("accounts:setDisplayName", { displayName: "X" });
    expect(refused).toMatchObject({ ok: false, code: "unauthenticated" });
    // A token signed by anyone else, or expired, fails verification before any function runs.
    const forged = clerk.sessionToken("user_maya").replace(/\.[^.]+$/, ".AAAA");
    expect((await api.as(forged).query("accounts:me")).ok).toBe(false);
    const expired = clerk.sessionToken("user_maya", -120);
    expect((await api.as(expired).query("accounts:me")).ok).toBe(false);
  });

  test("a Host signs up behind the age confirmation, and a second iPhone's session reaches the same Account", async () => {
    const maya = api.as(clerk.sessionToken("user_maya"));
    expect(await maya.query("accounts:me")).toMatchObject({ ok: true, value: { state: "noAccount" } });
    expect(await maya.mutation("accounts:createAccount", { displayName: "Maya", ageConfirmed: false, ageConfirmation: "birthMonthAndYear" })).toMatchObject({ ok: false });
    expect(await maya.mutation("accounts:createAccount", { displayName: "Maya", ageConfirmed: true, ageConfirmation: "birthMonthAndYear" })).toMatchObject({ ok: true, value: { created: true } });
    const secondPhone = api.as(clerk.sessionToken("user_maya"));
    expect(await secondPhone.query("accounts:me")).toMatchObject({ ok: true, value: { state: "signedIn", account: { displayName: "Maya" } } });
    const created = await api.admin.mutation("proofs:createProofEvent", { clerkUserId: "user_maya" });
    expect(created.ok).toBe(true);
    eventId = (created as { value: { eventId: string } }).value.eventId;
  });

  test("a picture-sized file goes to R2 through a one-time address and is stored after its size and checksum match", async () => {
    const maya = api.as(clerk.sessionToken("user_maya"));
    const args = { eventId, exposureNumber: 1, captureTime: Date.now(), contentType: "image/jpeg", size: picture.length, sha256: pictureSha256 };
    const address = await maya.action("pictures:requestUpload", args);
    expect(address).toMatchObject({ ok: true, value: { status: "upload", method: "PUT" } });
    const { url, headers } = (address as { value: { url: string; headers: Record<string, string> } }).value;
    expect((await fetch(url, { method: "PUT", headers, body: picture })).status).toBe(200);
    expect(await maya.action("pictures:confirmUpload", { eventId, exposureNumber: 1 })).toMatchObject({ ok: true, value: { status: "stored" } });
    // Sent again after a lost reply, it is stored once.
    expect(await maya.action("pictures:requestUpload", args)).toMatchObject({ ok: true, value: { status: "stored" } });
  });

  test("the iPhone's own Swift client sends a picture-sized file with URLSession, and is refused a sealed read", async () => {
    // The ImmerseServer package's LocalBackendTests, pointed at these stand-ins; a session token that outlasts the
    // Swift build is minted for it.
    // Asynchronously: the Clerk issuer stand-in answers Convex's key requests from this process's event loop.
    let output: string;
    try {
      output = (await runSwift()).stdout;
    } catch (error) {
      const failed = error as { stdout?: string; stderr?: string };
      throw new Error(`The Swift client's test failed:\n${failed.stdout ?? ""}\n${failed.stderr ?? ""}`.slice(-6000));
    }
    expect(output).toMatch(/LocalBackendTests.*passed/);
    expect(output).not.toMatch(/skipped/);
  }, 900_000);

  function runSwift() {
    return promisify(execFile)("swift", ["test", "--package-path", resolve(import.meta.dirname, "../../Packages/ImmerseServer"), "--filter", "LocalBackendTests"], {
      env: {
        ...process.env,
        IMMERSE_LOCAL_CONVEX_URL: backend.url,
        IMMERSE_LOCAL_SESSION_TOKEN: clerk.sessionToken("user_maya", 30 * 60),
        IMMERSE_LOCAL_EVENT_ID: eventId,
      },
      encoding: "utf8",
      maxBuffer: 16 * 1024 * 1024,
    });
  }

  test("it cannot be read without a grant, and a grant is given only after the reveal", async () => {
    const maya = api.as(clerk.sessionToken("user_maya"));
    expect(await maya.action("reads:readAddresses", { eventId })).toMatchObject({ ok: false, code: "sealed" });
    expect((await api.admin.mutation("proofs:revealProofEvent", { eventId })).ok).toBe(true);
    const grant = await maya.action("reads:readAddresses", { eventId });
    expect(grant.ok).toBe(true);
    const addresses = (grant as { value: Array<{ url: string; sha256: string; exposureNumber: number }> }).value;
    expect(addresses.map((a) => a.exposureNumber).sort()).toEqual([1, 2]);
    const address = addresses.find((a) => a.exposureNumber === 1);
    const bytes = Buffer.from(await (await fetch(address!.url)).arrayBuffer());
    expect(createHash("sha256").update(bytes).digest("base64")).toBe(pictureSha256);
    // The same object without the signature reads nothing.
    expect((await fetch(address!.url.split("?")[0]!)).status).toBe(403);
  });

  test("a push notification reaches Apple's service from a Convex Node action, over HTTP/2", async () => {
    const maya = api.as(clerk.sessionToken("user_maya"));
    const installationId = randomBytes(18).toString("base64url");
    const token = "c3".repeat(32);
    expect((await maya.mutation("pushTokens:register", { installationId, token, environment: "sandbox" })).ok).toBe(true);
    const accountId = await accountIdOf("user_maya");
    const sent = await api.admin.action("push:sendTestAlert", { accountId });
    expect(sent).toMatchObject({ ok: true, value: [{ token, status: 200 }] });
    const request = apns.requests.at(-1)!;
    expect(request.httpVersion).toBe("2.0");
    expect(request.path).toBe(`/3/device/${token}`);
    expect(apns.verifyProviderToken(String(request.headers.authorization).slice("bearer ".length)).valid).toBe(true);
  });

  test("Delete Account removes the Host's pictures and Account, and deletes the Clerk user", async () => {
    const maya = api.as(clerk.sessionToken("user_maya"));
    const objectUrl = (await maya.action("reads:readAddresses", { eventId })) as { value: Array<{ url: string }> };
    expect(await maya.action("deletion:deleteAccount")).toMatchObject({ ok: true, value: { deleted: true } });
    expect(clerk.deletions).toEqual(["user_maya"]);
    expect(await maya.query("accounts:me")).toMatchObject({ ok: true, value: { state: "noAccount" } });
    // Repeated, it changes nothing further; Clerk may be asked again for the same user.
    expect(await maya.action("deletion:deleteAccount")).toMatchObject({ ok: true, value: { deleted: true } });
    expect(new Set(clerk.deletions)).toEqual(new Set(["user_maya"]));
    expect(await maya.query("accounts:me")).toMatchObject({ ok: true, value: { state: "noAccount" } });
    // Within a minute, the picture's media is gone from storage.
    let status = 0;
    for (let attempt = 0; attempt < 600 && status !== 404; attempt += 1) {
      status = (await fetch(objectUrl.value[0]!.url)).status;
      if (status !== 404) await new Promise((r) => setTimeout(r, 100));
    }
    expect(status).toBe(404);
  });
});

// The Account id, which only the deployment's key can read.
async function accountIdOf(clerkUserId: string): Promise<string> {
  const result = await api.admin.query("proofs:accountIdForClerkUser", { clerkUserId });
  if (!result.ok) throw new Error(result.message);
  return result.value as string;
}
