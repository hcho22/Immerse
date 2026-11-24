// Buying Rolls (v2 PRD V2-FR-60, V2-FR-61, V2-FR-64, V2-FR-65, section 9.7), against stand-ins for the App Store's
// signatures and its server API (support/apple-double.ts): a purchase is credited once, only after Apple confirms it,
// to the Account that bought it; Apple's refund removes its Rolls and a reversal brings them back, in Apple's order;
// and nothing that Apple did not sign changes anything.
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { api, internal } from "../convex/_generated/api";
import type { Id } from "../convex/_generated/dataModel";
import {
  type AppleDouble,
  BUNDLE_ID,
  makeChain,
  MONTHLY,
  PACK_LARGE,
  PACK_SMALL,
  signWith,
  startAppleDouble,
  transactionPayload,
} from "./support/apple-double";
import { type Backend, newBackend, newGuest, newHost, refusalCode, signedIn } from "./support/convex";

let apple: AppleDouble;
beforeEach(async () => {
  apple = await startAppleDouble();
});
afterEach(async () => {
  await apple.close();
});

async function balance(host: ReturnType<typeof signedIn>) {
  return (await host.query(api.rolls.balance, {})).rolls;
}

async function tokenOf(host: ReturnType<typeof signedIn>) {
  return (await host.mutation(api.purchases.shoppingToken, {})).appAccountToken;
}

async function ledgerFor(t: Backend, transactionId: string) {
  return t.run((ctx) =>
    ctx.db
      .query("rollLedger")
      .withIndex("by_transaction", (q) => q.eq("appleTransactionId", transactionId))
      .collect(),
  );
}

let nextId = 2_000_000_100_000_000;
function transactionId() {
  nextId += 1;
  return String(nextId);
}

async function hostWithToken(t: Backend, clerkUserId = "user_maya") {
  const { host, accountId } = await newHost(t, clerkUserId);
  return { host, accountId, token: await tokenOf(host) };
}

async function notify(t: Backend, signedPayload: string) {
  const response = await t.fetch("/apple/notifications", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ signedPayload }),
  });
  return { status: response.status, body: await response.json() };
}

describe("what is on sale", () => {
  test("the packs and their Rolls come from the deployment's configuration, never a price", async () => {
    const t = newBackend();
    const { host } = await hostWithToken(t);
    const catalog = await host.query(api.purchases.catalog, {});
    expect(catalog.packs).toEqual([
      { productId: PACK_SMALL, rolls: 5 },
      { productId: PACK_LARGE, rolls: 25 },
    ]);
    expect(catalog.subscriber).toEqual({ offered: true, credited: null });
    expect(JSON.stringify(catalog)).not.toMatch(/price|\$/i);
  });

  test("an unset or placeholder configuration sells nothing and offers no subscriber Rolls", async () => {
    const t = newBackend();
    const { host } = await hostWithToken(t);
    for (const packs of [undefined, "com.immerse.FilmJournal.rolls.REPLACE_ME:REPLACE_WITH_ROLLS", `${PACK_SMALL}:0`, `${PACK_SMALL}:5,${PACK_SMALL}:6`]) {
      if (packs === undefined) delete process.env.ROLL_PACKS;
      else process.env.ROLL_PACKS = packs;
      expect((await host.query(api.purchases.catalog, {})).packs).toEqual([]);
    }
    process.env.ROLL_PACKS = apple.settings.ROLL_PACKS;
    delete process.env.APP_STORE_PRIVATE_KEY;
    expect(await host.query(api.purchases.catalog, {})).toEqual({ packs: [], subscriber: { offered: false, credited: null } });
    const signedTransaction = await apple.purchase({ transactionId: transactionId(), productId: PACK_SMALL });
    expect(await refusalCode(host.action(api.appStore.creditPurchase, { signedTransaction }))).toBe("purchasesUnavailable");
    process.env.APP_STORE_PRIVATE_KEY = apple.settings.APP_STORE_PRIVATE_KEY!;
    delete process.env.FREE_ROLLS_SUBSCRIBER;
    expect((await host.query(api.purchases.catalog, {})).subscriber.offered).toBe(false);
    const subscription = await apple.subscribe({ transactionId: transactionId(), productId: MONTHLY });
    expect(await refusalCode(host.action(api.appStore.linkSubscription, { signedTransaction: subscription }))).toBe(
      "subscriberRollsNotOffered",
    );
  });

  test("every Account has its own purchase token, made once", async () => {
    const t = newBackend();
    const maya = await hostWithToken(t, "user_maya");
    const ana = await hostWithToken(t, "user_ana");
    expect(maya.token).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    expect(ana.token).not.toBe(maya.token);
    expect(await tokenOf(maya.host)).toBe(maya.token);
    // An Account made before Stage 4 gets one the first time it shops.
    await t.run((ctx) => ctx.db.patch(ana.accountId, { appAccountToken: undefined }));
    const made = await tokenOf(ana.host);
    expect(made).not.toBe(ana.token);
    expect(await tokenOf(ana.host)).toBe(made);
  });
});

describe("a purchase is credited once, after Apple confirms it", () => {
  test("a purchase adds its pack's Rolls to the Account that bought it, once however often it is reported", async () => {
    const t = newBackend();
    const { host, token } = await hostWithToken(t);
    const before = await balance(host);
    const id = transactionId();
    const signedTransaction = await apple.purchase({ transactionId: id, productId: PACK_SMALL, appAccountToken: token });
    const first = await host.action(api.appStore.creditPurchase, { signedTransaction });
    expect(first).toMatchObject({ state: "credited", rolls: 5, toCaller: true, balance: before + 5 });
    // Reported again, and three times at once: still once (V2-FR-60, V2-FR-81).
    await host.action(api.appStore.creditPurchase, { signedTransaction });
    await Promise.all([1, 2, 3].map(() => host.action(api.appStore.creditPurchase, { signedTransaction })));
    expect(await balance(host)).toBe(before + 5);
    const rows = await ledgerFor(t, id);
    expect(rows.map((row) => [row.kind, row.rolls])).toEqual([["purchase", 5]]);
    // The server asked Apple before it credited.
    expect(apple.requests.some((request) => request.path === `/inApps/v1/transactions/${id}`)).toBe(true);
    // The history shows it (V2-FR-28).
    const history = await host.query(api.rolls.history, {});
    expect(history[0]).toMatchObject({ kind: "purchase", rolls: 5 });
  });

  test("it goes to the Account its token names, whoever reports it, and to the reporter only when the token names none", async () => {
    const t = newBackend();
    const maya = await hostWithToken(t, "user_maya");
    const ana = await hostWithToken(t, "user_ana");
    const mayaBefore = await balance(maya.host);
    const anaBefore = await balance(ana.host);
    // Maya bought it; Ana's session reports it: Maya's.
    const bought = await apple.purchase({ transactionId: transactionId(), productId: PACK_SMALL, appAccountToken: maya.token });
    expect(await ana.host.action(api.appStore.creditPurchase, { signedTransaction: bought })).toMatchObject({
      state: "credited",
      toCaller: false,
      balance: anaBefore,
    });
    // Reported with nobody signed in: still Maya's.
    const signedOut = await apple.purchase({ transactionId: transactionId(), productId: PACK_LARGE, appAccountToken: maya.token });
    expect(await t.action(api.appStore.creditPurchase, { signedTransaction: signedOut })).toMatchObject({
      state: "credited",
      balance: null,
    });
    expect(await balance(maya.host)).toBe(mayaBefore + 30);
    // A token no Account holds: the signed-in reporter's.
    const orphan = await apple.purchase({
      transactionId: transactionId(),
      productId: PACK_SMALL,
      appAccountToken: crypto.randomUUID(),
    });
    expect(await ana.host.action(api.appStore.creditPurchase, { signedTransaction: orphan })).toMatchObject({
      state: "credited",
      toCaller: true,
    });
    expect(await balance(ana.host)).toBe(anaBefore + 5);
    // Reported later by Maya too, it stays Ana's: a credited purchase never moves.
    await maya.host.action(api.appStore.creditPurchase, { signedTransaction: orphan });
    expect(await balance(ana.host)).toBe(anaBefore + 5);
    expect(await balance(maya.host)).toBe(mayaBefore + 30);
  });

  test("Apple's view now, not the app's copy, decides: a purchase Apple already refunded adds nothing", async () => {
    const t = newBackend();
    const { host, token } = await hostWithToken(t);
    const before = await balance(host);
    const id = transactionId();
    const stale = await apple.purchase({ transactionId: id, productId: PACK_SMALL, appAccountToken: token });
    await apple.update(id, { revocationDate: Date.now() });
    expect(await host.action(api.appStore.creditPurchase, { signedTransaction: stale })).toMatchObject({ state: "refunded" });
    expect(await balance(host)).toBe(before);
    expect(await ledgerFor(t, id)).toEqual([]);
  });

  test("while Apple cannot be asked, nothing is credited, and the next report credits it", async () => {
    const t = newBackend();
    const { host, token } = await hostWithToken(t);
    const before = await balance(host);
    const signedTransaction = await apple.purchase({ transactionId: transactionId(), productId: PACK_SMALL, appAccountToken: token });
    apple.unavailable = true;
    expect(await refusalCode(host.action(api.appStore.creditPurchase, { signedTransaction }))).toBe("storeUnavailable");
    expect(await balance(host)).toBe(before);
    apple.unavailable = false;
    // Apple does not know a transaction yet: not credited either.
    const unknown = await signWith(apple.chain, transactionPayload({ transactionId: transactionId(), productId: PACK_SMALL }));
    expect(await refusalCode(host.action(api.appStore.creditPurchase, { signedTransaction: unknown }))).toBe("storeUnavailable");
    expect(await host.action(api.appStore.creditPurchase, { signedTransaction })).toMatchObject({ state: "credited" });
    expect(await balance(host)).toBe(before + 5);
  });

  test("a consumable that is no pack on sale credits nothing until the packs name it", async () => {
    const t = newBackend();
    const { host, token } = await hostWithToken(t);
    const before = await balance(host);
    const id = transactionId();
    const signedTransaction = await apple.purchase({ transactionId: id, productId: "test.immerse.rolls.retired", appAccountToken: token });
    expect(await host.action(api.appStore.creditPurchase, { signedTransaction })).toMatchObject({ state: "notOnSale" });
    expect(await balance(host)).toBe(before);
    process.env.ROLL_PACKS = `${apple.settings.ROLL_PACKS},test.immerse.rolls.retired:7`;
    expect(await host.action(api.appStore.creditPurchase, { signedTransaction })).toMatchObject({ state: "credited", rolls: 7 });
    // Its size is fixed once seen: a later change to the packs changes nothing.
    process.env.ROLL_PACKS = `${apple.settings.ROLL_PACKS},test.immerse.rolls.retired:70`;
    await host.action(api.appStore.creditPurchase, { signedTransaction });
    expect(await balance(host)).toBe(before + 7);
  });
});

describe("only what Apple signed for this app counts", () => {
  test("a forged, altered or foreign transaction is refused and changes nothing", async () => {
    const t = newBackend();
    const { host, token } = await hostWithToken(t);
    const before = await balance(host);
    const id = transactionId();
    await apple.purchase({ transactionId: id, productId: PACK_SMALL, appAccountToken: token });
    const fields = { transactionId: id, productId: PACK_SMALL, appAccountToken: token };
    const genuine = await apple.sign(fields);
    const [header, , signature] = genuine.split(".");
    const altered = `${header}.${Buffer.from(JSON.stringify(transactionPayload({ ...fields, productId: PACK_LARGE }))).toString("base64url")}.${signature}`;
    const forged = await signWith(apple.forger, transactionPayload(fields));
    const noLeafMarker = await signWith(await makeChain({ leafMarker: false }), transactionPayload(fields));
    const unsigned = `${Buffer.from(JSON.stringify({ alg: "none" })).toString("base64url")}.${Buffer.from(JSON.stringify(transactionPayload(fields))).toString("base64url")}.`;
    const otherApp = await apple.sign({ ...fields, bundleId: "com.example.other" });
    const xcode = await apple.sign({ ...fields, environment: "Xcode" });
    const subscription = await apple.sign({ transactionId: transactionId(), productId: MONTHLY });
    for (const signedTransaction of [altered, forged, noLeafMarker, unsigned, otherApp, xcode, subscription, "not a jws"]) {
      expect(await refusalCode(host.action(api.appStore.creditPurchase, { signedTransaction }))).toBe("purchaseRefused");
    }
    // A chain made under the test root but expired when it signed.
    const expired = await makeChain({ expired: true });
    process.env.APPLE_ROOT_CA_PEM = expired.rootPem;
    expect(
      await refusalCode(host.action(api.appStore.creditPurchase, { signedTransaction: await signWith(expired, transactionPayload(fields)) })),
    ).toBe("purchaseRefused");
    process.env.APPLE_ROOT_CA_PEM = apple.settings.APPLE_ROOT_CA_PEM!;
    expect(await balance(host)).toBe(before);
    expect(await t.run((ctx) => ctx.db.query("purchases").collect())).toEqual([]);
  });

  test("a deployment credits only the environments it names", async () => {
    const t = newBackend();
    const { host, token } = await hostWithToken(t);
    process.env.APPLE_ENVIRONMENTS = "Sandbox";
    const production = await apple.purchase({
      transactionId: transactionId(),
      productId: PACK_SMALL,
      appAccountToken: token,
      environment: "Production",
    });
    expect(await refusalCode(host.action(api.appStore.creditPurchase, { signedTransaction: production }))).toBe("purchaseRefused");
    // Production needs the app's Apple ID.
    process.env.APPLE_ENVIRONMENTS = "Production,Sandbox";
    delete process.env.APPLE_APP_APPLE_ID;
    expect(await refusalCode(host.action(api.appStore.creditPurchase, { signedTransaction: production }))).toBe(
      "purchasesUnavailable",
    );
  });

  test("the pinned root is Apple Root CA - G3", async () => {
    const { APPLE_ROOT_CA_G3_PEM } = await import("../convex/lib/appleSigned");
    const { X509Certificate } = await import("node:crypto");
    const root = new X509Certificate(APPLE_ROOT_CA_G3_PEM);
    expect(root.fingerprint256).toBe(
      "63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79",
    );
    expect(root.subject).toContain("CN=Apple Root CA - G3");
  });
});

describe("Apple's server notifications", () => {
  test("a purchase the app never reports, such as an Ask to Buy approved later, is credited from Apple's notification", async () => {
    const t = newBackend();
    const { host, token } = await hostWithToken(t);
    const before = await balance(host);
    const id = transactionId();
    // Pending: Apple has no completed transaction and sends nothing, so nothing is added.
    expect(await balance(host)).toBe(before);
    // Approved: Apple completes it and notifies.
    const fields = { transactionId: id, productId: PACK_LARGE, appAccountToken: token };
    const signedTransaction = await apple.purchase(fields);
    expect(await notify(t, await apple.notification("ONE_TIME_CHARGE", fields))).toEqual({ status: 200, body: { handled: "credited" } });
    expect(await balance(host)).toBe(before + 25);
    // The app reports it later, when it next opens: once.
    expect(await host.action(api.appStore.creditPurchase, { signedTransaction })).toMatchObject({ state: "credited" });
    expect(await notify(t, await apple.notification("ONE_TIME_CHARGE", fields))).toMatchObject({ status: 200 });
    expect(await balance(host)).toBe(before + 25);
  });

  test("a refund removes the Rolls, may take the balance below zero and blocks set-asides, and never touches an event", async () => {
    const t = newBackend();
    const { host, token } = await hostWithToken(t);
    const id = transactionId();
    const fields = { transactionId: id, productId: PACK_LARGE, appAccountToken: token, purchaseDate: Date.now() - 60_000 };
    await host.action(api.appStore.creditPurchase, { signedTransaction: await apple.purchase(fields) });
    const start = await balance(host);
    // Every Roll set aside for an event, and a guest takes one.
    const eventId: Id<"events"> = (
      await host.mutation(api.hosting.create, {
        requestId: "load-film-request-1",
        title: "Ana & Leo",
        camera: "disposable",
        rolls: start,
        endsAt: Date.now() + 3_600_000,
        revealDelayMs: 0,
        treatmentVersion: "5",
      })
    ).eventId;
    const guest = await newGuest(t, eventId);
    expect(await balance(host)).toBe(0);
    // Apple refunds the purchase.
    const refundedAt = Date.now();
    await apple.update(id, { revocationDate: refundedAt });
    const refund = await apple.notification("REFUND", { ...fields, revocationDate: refundedAt, signedDate: refundedAt });
    expect(await notify(t, refund)).toEqual({ status: 200, body: { handled: "refunded" } });
    expect(await balance(host)).toBe(-25);
    // The event and the guest's Roll are untouched.
    const event = await t.run((ctx) => ctx.db.get(eventId));
    expect(event).toMatchObject({ rollsSetAside: start });
    const places = await t.run((ctx) => ctx.db.query("memberships").withIndex("by_event", (q) => q.eq("eventId", eventId)).collect());
    expect(places.map((place) => place.status)).toEqual(["joined"]);
    expect(guest.token).toBeTruthy();
    // No new set-aside while the balance is not above zero.
    expect(
      await refusalCode(host.mutation(api.hosting.addRolls, { eventId, rolls: 1, requestId: "add-rolls-request-1" })),
    ).toBe("balanceTooLow");
    // The refund again changes nothing further.
    expect(await notify(t, refund)).toMatchObject({ status: 200 });
    expect(await balance(host)).toBe(-25);
    // Apple reverses the refund: the Rolls come back.
    const reversedAt = refundedAt + 1_000;
    const reversal = await apple.notification("REFUND_REVERSED", { ...fields, signedDate: reversedAt });
    expect(await notify(t, reversal)).toEqual({ status: 200, body: { handled: "credited" } });
    expect(await balance(host)).toBe(0);
    // The refund, retried late by Apple, is older than the reversal and changes nothing.
    expect(await notify(t, refund)).toMatchObject({ status: 200 });
    expect(await balance(host)).toBe(0);
    expect((await ledgerFor(t, id)).map((row) => [row.kind, row.rolls])).toEqual([
      ["purchase", 25],
      ["refund", -25],
      ["refundReversed", 25],
    ]);
    const kinds = (await host.query(api.rolls.history, {})).map((row) => row.kind);
    expect(kinds).toEqual(expect.arrayContaining(["purchase", "refund", "refundReversed", "setAside"]));
  });

  test("a refund that reaches the server before the purchase leaves nothing credited", async () => {
    const t = newBackend();
    const { host, token } = await hostWithToken(t);
    const before = await balance(host);
    const id = transactionId();
    const fields = { transactionId: id, productId: PACK_SMALL, appAccountToken: token };
    const signedTransaction = await apple.purchase(fields);
    const refundedAt = Date.now();
    await apple.update(id, { revocationDate: refundedAt });
    await notify(t, await apple.notification("REFUND", { ...fields, revocationDate: refundedAt }));
    await notify(t, await apple.notification("ONE_TIME_CHARGE", { ...fields, signedDate: refundedAt - 5_000 }));
    expect(await host.action(api.appStore.creditPurchase, { signedTransaction })).toMatchObject({ state: "refunded" });
    expect(await balance(host)).toBe(before);
  });

  test("a notification for a token no Account holds waits for a signed-in report", async () => {
    const t = newBackend();
    const { host } = await hostWithToken(t);
    const before = await balance(host);
    const fields = { transactionId: transactionId(), productId: PACK_SMALL, appAccountToken: crypto.randomUUID() };
    const signedTransaction = await apple.purchase(fields);
    expect(await notify(t, await apple.notification("ONE_TIME_CHARGE", fields))).toEqual({ status: 200, body: { handled: "unassigned" } });
    expect(await t.action(api.appStore.creditPurchase, { signedTransaction })).toMatchObject({ state: "unassigned" });
    expect(await host.action(api.appStore.creditPurchase, { signedTransaction })).toMatchObject({ state: "credited", toCaller: true });
    expect(await balance(host)).toBe(before + 5);
  });

  test("an unsigned, forged or foreign notification changes nothing", async () => {
    const t = newBackend();
    const { host, token } = await hostWithToken(t);
    const fields = { transactionId: transactionId(), productId: PACK_LARGE, appAccountToken: token };
    await apple.purchase(fields);
    const before = await balance(host);
    const forged = await apple.notification("ONE_TIME_CHARGE", fields, { chain: apple.forger });
    expect((await notify(t, forged)).status).toBe(401);
    const genuine = await apple.notification("ONE_TIME_CHARGE", fields);
    const [header, payload] = genuine.split(".");
    expect((await notify(t, `${header}.${payload}.AAAA`)).status).toBe(401);
    expect((await notify(t, "not a jws")).status).toBe(401);
    expect(
      (await t.fetch("/apple/notifications", { method: "POST", body: "{}" })).status,
    ).toBe(400);
    expect((await notify(t, await apple.notification("ONE_TIME_CHARGE", fields, { bundleId: "com.example.other" }))).status).toBe(400);
    expect(
      (await notify(t, await apple.notification("ONE_TIME_CHARGE", { ...fields, environment: "Production" }, { appAppleId: 1 }))).status,
    ).toBe(400);
    expect(await balance(host)).toBe(before);
    expect(await t.run((ctx) => ctx.db.query("purchases").collect())).toEqual([]);
    // Apple's test notification is answered, and changes nothing.
    expect(await notify(t, await apple.notification("TEST", null))).toEqual({ status: 200, body: { handled: "test" } });
    // A subscription's notification needs nothing.
    const subscription = { transactionId: transactionId(), productId: MONTHLY };
    expect(await notify(t, await apple.notification("DID_RENEW", subscription))).toEqual({ status: 200, body: { handled: "ignored" } });
    expect(await notify(t, await apple.notification("REFUND", subscription))).toEqual({
      status: 200,
      body: { handled: "notARollPurchase" },
    });
  });

  test("an unconfigured deployment asks Apple to send notifications again later", async () => {
    const t = newBackend();
    const fields = { transactionId: transactionId(), productId: PACK_SMALL };
    const notification = await apple.notification("ONE_TIME_CHARGE", fields);
    delete process.env.APPLE_BUNDLE_ID;
    expect((await notify(t, notification)).status).toBe(503);
  });
});

describe("Delete Account and purchases", () => {
  test("a deleted Account's purchases stay without it, and a later refund or report credits nobody", async () => {
    const t = newBackend();
    const { host, token, accountId } = await hostWithToken(t);
    const id = transactionId();
    const fields = { transactionId: id, productId: PACK_SMALL, appAccountToken: token };
    const signedTransaction = await apple.purchase(fields);
    await host.action(api.appStore.creditPurchase, { signedTransaction });
    // The server's own removal, as Delete Account and Clerk's webhook run it.
    await t.action(internal.deletion.userDeletedAtClerk, { clerkUserId: "user_maya" });
    expect(await t.run((ctx) => ctx.db.get(accountId))).toBeNull();
    const later = await hostWithToken(t, "user_maya_again");
    const before = await balance(later.host);
    expect(await later.host.action(api.appStore.creditPurchase, { signedTransaction })).toMatchObject({ state: "credited", toCaller: false });
    const refundedAt = Date.now();
    await apple.update(id, { revocationDate: refundedAt });
    expect(await notify(t, await apple.notification("REFUND", { ...fields, revocationDate: refundedAt }))).toMatchObject({ status: 200 });
    expect(await balance(later.host)).toBe(before);
    const purchase = await t.run((ctx) => ctx.db.query("purchases").withIndex("by_transaction", (q) => q.eq("transactionId", id)).unique());
    expect(purchase).toMatchObject({ revoked: true, rolls: 5 });
    expect(purchase!.accountId).toBeUndefined();
    expect((await ledgerFor(t, id)).every((row) => row.accountId === undefined)).toBe(true);
  });
});

describe("the internal ledger", () => {
  test("applying the same view twice writes one row", async () => {
    const t = newBackend();
    const { token } = await hostWithToken(t);
    const transaction = {
      transactionId: transactionId(),
      originalTransactionId: "1",
      productId: PACK_SMALL,
      environment: "Sandbox" as const,
      purchaseDate: Date.now(),
      signedDate: Date.now(),
      appAccountToken: token,
    };
    await t.mutation(internal.purchases.applyTransaction, { transaction });
    await t.mutation(internal.purchases.applyTransaction, { transaction });
    expect(await ledgerFor(t, transaction.transactionId)).toHaveLength(1);
    expect(BUNDLE_ID).toBe("com.immerse.FilmJournal");
  });
});
