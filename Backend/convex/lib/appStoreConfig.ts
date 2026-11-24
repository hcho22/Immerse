// What the server needs to sell Rolls and confirm the subscription (v2 PRD V2-FR-60 to V2-FR-65, section 9.7), read from
// the deployment's environment. Nothing here is a number of the pricing decision (V2-FR-64, open check OC-5): the Roll
// packs and their sizes, the subscription's products and the subscriber's free Rolls are configuration, and a
// deployment without them sells nothing and links no subscription. Backend/SETUP.md says where each value comes from.
//
// This file has no Node import, so both the default runtime's functions and the Node actions read it.
import { MAX_ROLLS_PER_EVENT } from "./config";

export type AppleEnvironment = "Production" | "Sandbox";
export const APPLE_ENVIRONMENTS: readonly AppleEnvironment[] = ["Production", "Sandbox"];

// A pack of Rolls on sale: an App Store Connect consumable and how many Rolls it adds.
export type RollPack = { productId: string; rolls: number };

// The most Rolls one pack may add. It only guards against a mistyped configuration: the pack sizes are OC-5's.
export const MAX_ROLLS_PER_PACK = 50 * MAX_ROLLS_PER_EVENT;

const PRODUCT_ID = /^[A-Za-z0-9._-]{1,100}$/;

export type Configured<T> = { ok: true; value: T } | { ok: false; problem: string };

function setting(name: string): string | undefined {
  const raw = process.env[name];
  return raw === undefined || raw.trim() === "" ? undefined : raw.trim();
}

// The Roll packs on sale, from ROLL_PACKS: "<product id>:<Rolls>" entries separated by commas. A placeholder, a
// malformed entry, a repeated product or a size out of range leaves nothing on sale and says why, so a configuration
// copied from `.env.example` can never sell a pack.
export function rollPacks(): Configured<RollPack[]> {
  const raw = setting("ROLL_PACKS");
  if (raw === undefined) return { ok: false, problem: "ROLL_PACKS is not set" };
  const packs: RollPack[] = [];
  for (const entry of raw.split(",")) {
    const [productId, rolls, extra] = entry.trim().split(":");
    const count = Number(rolls);
    if (
      productId === undefined ||
      !PRODUCT_ID.test(productId) ||
      extra !== undefined ||
      rolls === undefined ||
      !/^\d+$/.test(rolls) ||
      !Number.isInteger(count) ||
      count < 1 ||
      count > MAX_ROLLS_PER_PACK
    ) {
      return { ok: false, problem: `ROLL_PACKS has a malformed entry: "${entry.trim()}"` };
    }
    if (packs.some((pack) => pack.productId === productId)) {
      return { ok: false, problem: `ROLL_PACKS names ${productId} twice` };
    }
    packs.push({ productId, rolls: count });
  }
  return { ok: true, value: packs };
}

// What the server checks every signed transaction and notification against.
export type AppStoreSettings = {
  // The app's bundle identifier, which every transaction must carry.
  bundleId: string;
  // The app's Apple ID in App Store Connect, which a production notification must carry.
  appAppleId?: number;
  // The environments whose transactions this deployment credits: Sandbox for a development deployment, both for the
  // production one, where App Review buys in the sandbox.
  environments: AppleEnvironment[];
  // The v1 subscription's products (the monthly and the yearly), whose transactions confirm a subscriber.
  subscriptionProductIds: string[];
};

export function appStoreSettings(): Configured<AppStoreSettings> {
  const bundleId = setting("APPLE_BUNDLE_ID");
  if (bundleId === undefined || !PRODUCT_ID.test(bundleId)) {
    return { ok: false, problem: "APPLE_BUNDLE_ID is not set" };
  }
  const environments = (setting("APPLE_ENVIRONMENTS") ?? "").split(",").map((name) => name.trim());
  if (environments.length === 0 || !environments.every((name) => (APPLE_ENVIRONMENTS as string[]).includes(name))) {
    return { ok: false, problem: "APPLE_ENVIRONMENTS must name Production, Sandbox or both" };
  }
  const appleId = setting("APPLE_APP_APPLE_ID");
  const appAppleId = appleId === undefined ? undefined : Number(appleId);
  if (appAppleId !== undefined && (!/^\d+$/.test(appleId!) || !Number.isSafeInteger(appAppleId))) {
    return { ok: false, problem: "APPLE_APP_APPLE_ID must be the app's numeric Apple ID" };
  }
  if (environments.includes("Production") && appAppleId === undefined) {
    return { ok: false, problem: "APPLE_APP_APPLE_ID is needed to accept Production transactions" };
  }
  const subscriptionProductIds = (setting("SUBSCRIPTION_PRODUCT_IDS") ?? "")
    .split(",")
    .map((id) => id.trim())
    .filter((id) => id !== "");
  if (!subscriptionProductIds.every((id) => PRODUCT_ID.test(id))) {
    return { ok: false, problem: "SUBSCRIPTION_PRODUCT_IDS has a malformed product id" };
  }
  return {
    ok: true,
    value: { bundleId, appAppleId, environments: environments as AppleEnvironment[], subscriptionProductIds },
  };
}

// The App Store Server API's credentials: an In-App Purchase key from App Store Connect.
export type AppStoreApiCredentials = { keyId: string; issuerId: string; privateKey: string };

export function appStoreApiCredentials(): Configured<AppStoreApiCredentials> {
  const keyId = setting("APP_STORE_KEY_ID");
  const issuerId = setting("APP_STORE_ISSUER_ID");
  const privateKey = setting("APP_STORE_PRIVATE_KEY")?.replace(/\\n/g, "\n");
  if (keyId === undefined || issuerId === undefined || privateKey === undefined) {
    return { ok: false, problem: "APP_STORE_KEY_ID, APP_STORE_ISSUER_ID and APP_STORE_PRIVATE_KEY must all be set" };
  }
  return { ok: true, value: { keyId, issuerId, privateKey } };
}
