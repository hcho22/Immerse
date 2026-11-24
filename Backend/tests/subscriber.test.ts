// The subscriber's free Rolls (v2 PRD V2-FR-62, V2-FR-63, section 9.7): credited to an Account only after Apple's
// App Store Server API confirms the v1 subscription is active, once ever, and never to a second Account presenting the
// same subscription; a lapse or refund credits nothing further and takes nothing back.
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { api, internal } from "../convex/_generated/api";
import { type AppleDouble, MONTHLY, PACK_SMALL, signWith, startAppleDouble, transactionPayload, YEARLY } from "./support/apple-double";
import { type Backend, newBackend, newHost, refusalCode, signedIn } from "./support/convex";

let apple: AppleDouble;
beforeEach(async () => {
  apple = await startAppleDouble();
});
afterEach(async () => {
  await apple.close();
});

let nextId = 2_000_000_200_000_000;
function transactionId() {
  nextId += 1;
  return String(nextId);
}

async function balance(host: ReturnType<typeof signedIn>) {
  return (await host.query(api.rolls.balance, {})).rolls;
}

async function link(host: ReturnType<typeof signedIn>, signedTransaction: string) {
  return host.action(api.appStore.linkSubscription, { signedTransaction });
}

async function subscriber(t: Backend, clerkUserId: string) {
  const { host, accountId } = await newHost(t, clerkUserId);
  return { host, accountId };
}

describe("a subscriber's free Rolls", () => {
  test("are credited once Apple confirms the subscription, once ever, and a renewal or second report adds none", async () => {
    const t = newBackend();
    const { host } = await subscriber(t, "user_maya");
    const before = await balance(host);
    const original = transactionId();
    const subscription = await apple.subscribe({ transactionId: original, productId: MONTHLY });
    expect(await link(host, subscription)).toMatchObject({ state: "credited", rolls: 20, balance: before + 20 });
    // The server asked Apple for the subscription's status before it credited.
    expect(apple.requests.some((request) => request.path === `/inApps/v1/subscriptions/${original}`)).toBe(true);
    expect(await link(host, subscription)).toMatchObject({ state: "alreadyCredited", rolls: 20 });
    // A renewal is a new transaction of the same subscription: nothing more (V2-FR-62).
    const renewal = await apple.subscribe({ transactionId: transactionId(), originalTransactionId: original, productId: YEARLY });
    expect(await link(host, renewal)).toMatchObject({ state: "alreadyCredited" });
    expect(await balance(host)).toBe(before + 20);
    expect(await host.query(api.purchases.catalog, {})).toMatchObject({ subscriber: { offered: true, credited: 20 } });
    const history = await host.query(api.rolls.history, {});
    expect(history.filter((row) => row.kind === "free")).toEqual([expect.objectContaining({ freeGrant: "subscriber", rolls: 20 })]);
  });

  test("a second Account presenting the same subscription gets none, and is not told which Account holds it", async () => {
    const t = newBackend();
    const maya = await subscriber(t, "user_maya");
    const ana = await subscriber(t, "user_ana");
    const subscription = await apple.subscribe({ transactionId: transactionId(), productId: MONTHLY });
    const anaBefore = await balance(ana.host);
    expect(await link(maya.host, subscription)).toMatchObject({ state: "credited" });
    const refused = await link(ana.host, subscription);
    expect(refused).toEqual({ state: "linkedElsewhere", balance: anaBefore });
    expect(JSON.stringify(refused)).not.toContain(maya.accountId);
    expect(await balance(ana.host)).toBe(anaBefore);
  });

  test("two Accounts presenting the same subscription at once: exactly one gets the Rolls", async () => {
    const t = newBackend();
    const maya = await subscriber(t, "user_maya");
    const ana = await subscriber(t, "user_ana");
    const subscription = await apple.subscribe({ transactionId: transactionId(), productId: MONTHLY });
    const outcomes = await Promise.all([link(maya.host, subscription), link(ana.host, subscription)]);
    expect(outcomes.map((outcome) => outcome.state).sort()).toEqual(["credited", "linkedElsewhere"]);
  });

  test("nothing before Apple's confirmation: an expired, retrying or refunded subscription credits none", async () => {
    const t = newBackend();
    const { host } = await subscriber(t, "user_maya");
    const before = await balance(host);
    for (const status of [2, 3, 5]) {
      const subscription = await apple.subscribe({ transactionId: transactionId(), productId: MONTHLY }, status);
      expect(await link(host, subscription)).toMatchObject({ state: "notActive" });
    }
    // Active at Apple, but its latest transaction refunded.
    const refunded = transactionId();
    const subscription = await apple.subscribe({ transactionId: refunded, productId: MONTHLY });
    await apple.update(refunded, { revocationDate: Date.now() });
    expect(await link(host, subscription)).toMatchObject({ state: "notActive" });
    // While Apple cannot be asked, nothing either.
    const later = await apple.subscribe({ transactionId: transactionId(), productId: MONTHLY });
    apple.unavailable = true;
    expect(await refusalCode(link(host, later))).toBe("storeUnavailable");
    apple.unavailable = false;
    expect(await balance(host)).toBe(before);
    // The billing grace period still counts as subscribed.
    const grace = await apple.subscribe({ transactionId: transactionId(), productId: MONTHLY }, 4);
    expect(await link(host, grace)).toMatchObject({ state: "credited" });
  });

  test("a lapse or refund after the link credits nothing further, and the Rolls credited stay", async () => {
    const t = newBackend();
    const { host } = await subscriber(t, "user_maya");
    const original = transactionId();
    const subscription = await apple.subscribe({ transactionId: original, productId: MONTHLY });
    await link(host, subscription);
    const after = await balance(host);
    apple.setSubscriptionStatus(original, 2);
    expect(await link(host, subscription)).toMatchObject({ state: "notActive" });
    await apple.update(original, { revocationDate: Date.now() });
    const refund = await apple.notification("REFUND", { transactionId: original, productId: MONTHLY, revocationDate: Date.now() });
    const response = await t.fetch("/apple/notifications", { method: "POST", body: JSON.stringify({ signedPayload: refund }) });
    expect(response.status).toBe(200);
    expect(await balance(host)).toBe(after);
  });

  test("an Account that had a subscriber's Rolls gets none for a second subscription, which stays free to feed another Account", async () => {
    const t = newBackend();
    const maya = await subscriber(t, "user_maya");
    const ana = await subscriber(t, "user_ana");
    await link(maya.host, await apple.subscribe({ transactionId: transactionId(), productId: MONTHLY }));
    const second = await apple.subscribe({ transactionId: transactionId(), productId: YEARLY });
    expect(await link(maya.host, second)).toMatchObject({ state: "accountAlreadyCredited" });
    expect(await link(ana.host, second)).toMatchObject({ state: "credited" });
  });

  test("after Delete Account the subscription's Rolls do not come again to a new Account", async () => {
    const t = newBackend();
    const maya = await subscriber(t, "user_maya");
    const subscription = await apple.subscribe({ transactionId: transactionId(), productId: MONTHLY });
    await link(maya.host, subscription);
    await t.action(internal.deletion.userDeletedAtClerk, { clerkUserId: "user_maya" });
    const again = await subscriber(t, "user_maya_new");
    const before = await balance(again.host);
    expect(await link(again.host, subscription)).toMatchObject({ state: "linkedElsewhere" });
    expect(await balance(again.host)).toBe(before);
  });

  test("only a signed-in Account, with this app's subscription, signed by Apple", async () => {
    const t = newBackend();
    const { host } = await subscriber(t, "user_maya");
    const subscription = await apple.subscribe({ transactionId: transactionId(), productId: MONTHLY });
    expect(await refusalCode(t.action(api.appStore.linkSubscription, { signedTransaction: subscription }))).toBe("unauthenticated");
    expect(await refusalCode(signedIn(t, "user_nobody").action(api.appStore.linkSubscription, { signedTransaction: subscription }))).toBe(
      "noAccount",
    );
    const forged = await signWith(apple.forger, transactionPayload({ transactionId: transactionId(), productId: MONTHLY }));
    const rollPack = await apple.purchase({ transactionId: transactionId(), productId: PACK_SMALL });
    const otherProduct = await apple.subscribe({ transactionId: transactionId(), productId: "test.immerse.other", type: "Auto-Renewable Subscription" });
    for (const signedTransaction of [forged, rollPack, otherProduct]) {
      expect(await refusalCode(link(host, signedTransaction))).toBe("purchaseRefused");
    }
  });
});
