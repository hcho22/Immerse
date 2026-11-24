// Stage 4's server end to end on Convex's own local backend: the functions pushed with Convex's CLI as a real deployment
// is, run in the backend's own runtimes (Apple's signatures are checked in its Node runtime), and called through the
// HTTP API the app uses, including by the app's own Swift client (`Packages/ImmerseServer`). Apple is the stand-in of
// tests/support/apple-double.ts: a certificate chain made for the run, which the deployment is told to trust, and the
// App Store Server API's answers on 127.0.0.1. Nothing reaches Apple; section B of the manual validation plan is what
// Apple's sandbox shows.
import { execFile } from "node:child_process";
import { randomBytes } from "node:crypto";
import { resolve } from "node:path";
import { promisify } from "node:util";
import { afterAll, beforeAll, describe, expect, inject, test } from "vitest";
import { type AppleDouble, MONTHLY, PACK_LARGE, PACK_SMALL, startAppleDouble } from "../tests/support/apple-double";
import { deployFunctions, httpApi, type LocalBackend, startClerkIssuer, startConvexBackend } from "./support/stack";

let backend: LocalBackend;
let clerk: Awaited<ReturnType<typeof startClerkIssuer>>;
let apple: AppleDouble;
let api: ReturnType<typeof httpApi>;

beforeAll(async () => {
  const storage = inject("storage");
  clerk = await startClerkIssuer();
  apple = await startAppleDouble();
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
    ...apple.settings,
  });
  api = httpApi(backend);
}, 240_000);

afterAll(async () => {
  backend?.stop();
  await apple?.close();
  await clerk?.close();
});

async function newAccount(userId: string) {
  const person = api.as(clerk.sessionToken(userId, 30 * 60));
  expect(
    await person.mutation("accounts:createAccount", { displayName: userId, ageConfirmed: true, ageConfirmation: "birthMonthAndYear" }),
  ).toMatchObject({ ok: true });
  const token = await person.mutation("purchases:shoppingToken");
  return { person, token: (token.value as { appAccountToken: string }).appAccountToken };
}

async function balance(person: ReturnType<typeof api.as>) {
  const reply = await person.query("rolls:balance");
  return (reply.value as { rolls: number }).rolls;
}

function notify(signedPayload: string) {
  return fetch(`${backend.siteUrl}/apple/notifications`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ signedPayload }),
  });
}

describe("buying Rolls on Convex's local backend", () => {
  test("a purchase is credited once, a refund notification removes it and its reversal brings it back", async () => {
    const { person, token } = await newAccount("user_maya");
    const catalog = await person.query("purchases:catalog");
    expect(catalog.value).toMatchObject({ packs: [{ productId: PACK_SMALL, rolls: 5 }, { productId: PACK_LARGE, rolls: 25 }] });
    const start = await balance(person);
    const fields = { transactionId: "2000000300000001", productId: PACK_LARGE, appAccountToken: token };
    const signedTransaction = await apple.purchase(fields);
    const replies = await Promise.all([1, 2, 3].map(() => person.action("appStore:creditPurchase", { signedTransaction })));
    for (const reply of replies) expect(reply).toMatchObject({ ok: true, value: { state: "credited", rolls: 25 } });
    expect(await balance(person)).toBe(start + 25);

    const refundedAt = Date.now();
    await apple.update(fields.transactionId, { revocationDate: refundedAt });
    expect((await notify(await apple.notification("REFUND", { ...fields, revocationDate: refundedAt, signedDate: refundedAt }))).status).toBe(200);
    expect(await balance(person)).toBe(start);
    expect((await notify(await apple.notification("REFUND", fields, { chain: apple.forger }))).status).toBe(401);
    expect((await notify(await apple.notification("REFUND_REVERSED", { ...fields, signedDate: refundedAt + 1_000 }))).status).toBe(200);
    expect(await balance(person)).toBe(start + 25);

    const forged = await person.action("appStore:creditPurchase", { signedTransaction: signedTransaction.replace(/\.[^.]+$/, ".AAAA") });
    expect(forged).toMatchObject({ ok: false, code: "purchaseRefused" });
  });

  test("the subscriber's free Rolls go to one Account, after Apple confirms the subscription", async () => {
    const maya = await newAccount("user_maya_subscriber");
    const ana = await newAccount("user_ana_subscriber");
    const subscription = await apple.subscribe({ transactionId: "2000000300000101", productId: MONTHLY });
    const mayaStart = await balance(maya.person);
    const anaStart = await balance(ana.person);
    expect(await maya.person.action("appStore:linkSubscription", { signedTransaction: subscription })).toMatchObject({
      ok: true,
      value: { state: "credited", rolls: 20 },
    });
    expect(await ana.person.action("appStore:linkSubscription", { signedTransaction: subscription })).toMatchObject({
      ok: true,
      value: { state: "linkedElsewhere" },
    });
    expect(await balance(maya.person)).toBe(mayaStart + 20);
    expect(await balance(ana.person)).toBe(anaStart);
  });

  test("the app's own Swift client buys, reports and links through the HTTP API", async () => {
    const { token } = await newAccount("user_swift");
    const purchase = await apple.purchase({ transactionId: "2000000300000201", productId: PACK_SMALL, appAccountToken: token });
    const subscription = await apple.subscribe({ transactionId: "2000000300000301", productId: MONTHLY });
    const { stdout } = await promisify(execFile)(
      "swift",
      ["test", "--package-path", resolve(import.meta.dirname, "../../Packages/ImmerseServer"), "--filter", "LocalBackendRollTests"],
      {
        env: {
          ...process.env,
          IMMERSE_LOCAL_CONVEX_URL: backend.url,
          IMMERSE_LOCAL_SESSION_TOKEN: clerk.sessionToken("user_swift", 30 * 60),
          IMMERSE_LOCAL_APP_ACCOUNT_TOKEN: token,
          IMMERSE_LOCAL_SIGNED_PURCHASE: purchase,
          IMMERSE_LOCAL_SIGNED_SUBSCRIPTION: subscription,
        },
        encoding: "utf8",
        maxBuffer: 16 * 1024 * 1024,
      },
    );
    expect(stdout).toMatch(/LocalBackendRollTests.*passed/);
    expect(stdout).not.toMatch(/skipped/);
  });
});
