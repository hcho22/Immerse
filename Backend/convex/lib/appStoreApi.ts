"use node";
// Apple's App Store Server API, which the server asks for a transaction's current state before it credits Rolls and
// for a subscription's current status before it gives a subscriber's free Rolls (v2 PRD V2-FR-60, V2-FR-63, section
// 9.7). Every request is authorized with a token signed by the deployment's In-App Purchase key, and every signed
// answer is verified as Apple's (appleSigned.ts) before it is believed.
//
// Only Node modules are used, so this file is imported only from Node actions and the tests.
import { sign } from "node:crypto";
import type { AppleEnvironment, AppStoreApiCredentials } from "./appStoreConfig";
import { SignedDataRefused, verifyAppleSigned } from "./appleSigned";

export const APP_STORE_API_ORIGINS: Record<AppleEnvironment, string> = {
  Production: "https://api.storekit.itunes.apple.com",
  Sandbox: "https://api.storekit-sandbox.itunes.apple.com",
};

// Apple's answer could not be had now: the network, a rate limit, Apple's own error. Nothing changed; ask again.
export class AppStoreUnavailable extends Error {}

// A transaction as Apple signed it (JWSTransactionDecodedPayload), with the fields the server reads.
export type AppleTransaction = {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  // "Consumable", "Auto-Renewable Subscription", "Non-Consumable" or "Non-Renewing Subscription".
  type: string;
  environment: string;
  purchaseDate: number;
  signedDate: number;
  revocationDate?: number;
  expiresDate?: number;
  appAccountToken?: string;
};

function text(payload: Record<string, unknown>, key: string): string {
  const value = payload[key];
  if (typeof value !== "string" || value === "") throw new SignedDataRefused(`The transaction has no ${key}`);
  return value;
}

function time(payload: Record<string, unknown>, key: string, required: boolean): number | undefined {
  const value = payload[key];
  if (value === undefined && !required) return undefined;
  if (typeof value !== "number" || !Number.isFinite(value)) throw new SignedDataRefused(`The transaction has no ${key}`);
  return value;
}

// Verifies a signed transaction and reads it.
export function verifiedTransaction(jws: string, now = Date.now()): AppleTransaction {
  const payload = verifyAppleSigned(jws, undefined, now);
  const token = payload.appAccountToken;
  return {
    transactionId: text(payload, "transactionId"),
    originalTransactionId: text(payload, "originalTransactionId"),
    bundleId: text(payload, "bundleId"),
    productId: text(payload, "productId"),
    type: text(payload, "type"),
    environment: text(payload, "environment"),
    purchaseDate: time(payload, "purchaseDate", true)!,
    signedDate: time(payload, "signedDate", true)!,
    revocationDate: time(payload, "revocationDate", false),
    expiresDate: time(payload, "expiresDate", false),
    appAccountToken: typeof token === "string" && token !== "" ? token.toLowerCase() : undefined,
  };
}

// The token the App Store Server API asks for: ES256, signed with the In-App Purchase key, valid for five minutes.
export function appStoreApiToken(credentials: AppStoreApiCredentials, bundleId: string, nowSeconds = Math.floor(Date.now() / 1000)) {
  const segment = (value: object) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const header = segment({ alg: "ES256", kid: credentials.keyId, typ: "JWT" });
  const claims = segment({
    iss: credentials.issuerId,
    iat: nowSeconds,
    exp: nowSeconds + 300,
    aud: "appstoreconnect-v1",
    bid: bundleId,
  });
  const signature = sign("sha256", Buffer.from(`${header}.${claims}`), {
    key: credentials.privateKey,
    dsaEncoding: "ieee-p1363",
  });
  return `${header}.${claims}.${signature.toString("base64url")}`;
}

function origin(environment: AppleEnvironment): string {
  // Only the tests set APP_STORE_API_ORIGIN, to a stand-in for both environments; a real deployment leaves it unset.
  return process.env.APP_STORE_API_ORIGIN || APP_STORE_API_ORIGINS[environment];
}

export type AppStoreAnswer<T> = { found: true; value: T } | { found: false };

async function getJson(
  credentials: AppStoreApiCredentials,
  bundleId: string,
  environment: AppleEnvironment,
  path: string,
): Promise<AppStoreAnswer<Record<string, unknown>>> {
  let response: Response;
  try {
    response = await fetch(`${origin(environment)}${path}`, {
      headers: { authorization: `Bearer ${appStoreApiToken(credentials, bundleId)}` },
      signal: AbortSignal.timeout(20_000),
    });
  } catch (error) {
    throw new AppStoreUnavailable(`The App Store Server API could not be reached: ${(error as Error).message}`);
  }
  const body = await response.text();
  // Apple answers 404 for a transaction it does not know in this environment.
  if (response.status === 404) return { found: false };
  if (!response.ok) {
    // 401 is this deployment's key or settings; 429 and 5xx are Apple's for now. Either way nothing changed here.
    throw new AppStoreUnavailable(`The App Store Server API answered HTTP ${response.status}: ${body.slice(0, 200)}`);
  }
  try {
    const value: unknown = JSON.parse(body);
    if (typeof value !== "object" || value === null) throw new Error("not an object");
    return { found: true, value: value as Record<string, unknown> };
  } catch {
    throw new AppStoreUnavailable("The App Store Server API's answer could not be read");
  }
}

// Get Transaction Info: the transaction's current state, as Apple signs it now.
export async function currentTransaction(
  credentials: AppStoreApiCredentials,
  bundleId: string,
  environment: AppleEnvironment,
  transactionId: string,
): Promise<AppStoreAnswer<AppleTransaction>> {
  const answer = await getJson(credentials, bundleId, environment, `/inApps/v1/transactions/${encodeURIComponent(transactionId)}`);
  if (!answer.found) return answer;
  const signed = answer.value.signedTransactionInfo;
  if (typeof signed !== "string") throw new AppStoreUnavailable("The App Store Server API's answer had no transaction");
  return { found: true, value: verifiedTransaction(signed) };
}

// Apple's subscription statuses: 1 active, 2 expired, 3 in billing retry, 4 in the billing grace period, 5 revoked.
export const SUBSCRIPTION_ACTIVE = 1;
export const SUBSCRIPTION_IN_GRACE_PERIOD = 4;

export type SubscriptionStatus = { status: number; transaction: AppleTransaction };

// Get All Subscription Statuses: the current status of the subscription a transaction belongs to.
export async function subscriptionStatus(
  credentials: AppStoreApiCredentials,
  bundleId: string,
  environment: AppleEnvironment,
  transactionId: string,
  originalTransactionId: string,
): Promise<AppStoreAnswer<SubscriptionStatus>> {
  const answer = await getJson(credentials, bundleId, environment, `/inApps/v1/subscriptions/${encodeURIComponent(transactionId)}`);
  if (!answer.found) return answer;
  const groups = answer.value.data;
  if (!Array.isArray(groups)) throw new AppStoreUnavailable("The App Store Server API's answer had no subscriptions");
  for (const group of groups) {
    const lastTransactions = (group as { lastTransactions?: unknown }).lastTransactions;
    if (!Array.isArray(lastTransactions)) continue;
    for (const entry of lastTransactions) {
      const { originalTransactionId: original, status, signedTransactionInfo } = entry as Record<string, unknown>;
      if (original !== originalTransactionId) continue;
      if (typeof status !== "number" || typeof signedTransactionInfo !== "string") {
        throw new AppStoreUnavailable("The App Store Server API's answer could not be read");
      }
      const transaction = verifiedTransaction(signedTransactionInfo);
      if (transaction.originalTransactionId !== originalTransactionId) {
        throw new SignedDataRefused("The subscription's status names another subscription");
      }
      return { found: true, value: { status, transaction } };
    }
  }
  return { found: false };
}
