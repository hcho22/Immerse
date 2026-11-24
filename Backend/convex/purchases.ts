// Buying Rolls and the subscriber's free Rolls (v2 PRD V2-FR-60 to V2-FR-65, sections 6.5 and 9.7): what is on sale,
// the token each purchase carries, and how a purchase Apple confirmed reaches the balance, once.
//
// A purchase reaches the server two ways: the app reports its signed transaction (appStore.ts:creditPurchase), and
// Apple's server notification reports it too (appStore.ts:receiveNotification). Both arrive here as Apple's own
// signed view of the transaction, checked first, and `applyTransaction` makes the balance agree with Apple's latest
// view: its Rolls are in the balance once while it stands, out of it while it is refunded, and back when a refund is
// reversed. Repeating a report, or two reports at once, changes nothing further (V2-FR-81).
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { internalMutation, internalQuery, mutation, query, type MutationCtx } from "./_generated/server";
import { requireAccount } from "./lib/callers";
import { appStoreApiCredentials, appStoreSettings, rollPacks } from "./lib/appStoreConfig";
import { freeRollsForSubscribers } from "./lib/config";
import { randomUuid } from "./lib/crypto";
import { refuse } from "./lib/errors";
import { shownBalance } from "./rolls";

const appleEnvironment = v.union(v.literal("Production"), v.literal("Sandbox"));

// The Account's purchase token, made when the Account is (accounts.ts) or, for an Account made before Stage 4, the
// first time it shops.
export async function ensureAppAccountToken(ctx: MutationCtx, account: Doc<"accounts">): Promise<string> {
  if (account.appAccountToken !== undefined) return account.appAccountToken;
  const appAccountToken = randomUuid();
  await ctx.db.patch(account._id, { appAccountToken });
  return appAccountToken;
}

// The token the app sets on a Roll purchase, so Apple returns it in the transaction and the server credits the Account
// that bought it, whoever reports it and whenever.
export const shoppingToken = mutation({
  args: {},
  handler: async (ctx) => {
    const account = await requireAccount(ctx);
    return { appAccountToken: await ensureAppAccountToken(ctx, account) };
  },
});

// What the signed-in Host can buy (V2-FR-60, V2-FR-64): each Roll pack's App Store product and its Rolls, from the
// deployment's configuration. The prices are the App Store's, which the app shows from StoreKit; nothing here is a
// price. Also whether this deployment gives a subscriber's free Rolls, and whether this Account has had them.
export const catalog = query({
  args: {},
  handler: async (ctx) => {
    const account = await requireAccount(ctx);
    const packs = rollPacks();
    const settings = appStoreSettings();
    const credentials = appStoreApiCredentials();
    const ready = settings.ok && credentials.ok;
    for (const problem of [packs, settings, credentials].filter((item) => !item.ok)) {
      console.warn(`Buying Rolls is off: ${(problem as { problem: string }).problem}`);
    }
    const link = await ctx.db
      .query("subscriptionLinks")
      .withIndex("by_account", (q) => q.eq("accountId", account._id))
      .first();
    const subscriberRolls = freeRollsForSubscribers();
    const subscriberOffered = ready && subscriberRolls > 0 && settings.value.subscriptionProductIds.length > 0;
    return {
      packs: ready && packs.ok ? packs.value : [],
      subscriber: {
        // Whether this deployment gives subscribers free Rolls at all (the pricing decision, OC-5).
        offered: subscriberOffered,
        // The subscriber Rolls this Account has had, once ever, or null when it has had none.
        credited: link === null ? null : link.rollsCredited,
      },
    };
  },
});

// The live Account a signed-in caller holds, for the Node actions, which cannot read the database themselves.
export const liveAccountFor = internalQuery({
  args: { tokenIdentifier: v.string() },
  handler: async (ctx, { tokenIdentifier }) => {
    const account = await ctx.db
      .query("accounts")
      .withIndex("by_token", (q) => q.eq("tokenIdentifier", tokenIdentifier))
      .unique();
    if (account === null || account.deletionRequestedAt !== undefined) return null;
    return account._id;
  },
});

// The balance an Account's Host sees, for the Node actions' replies.
export const balanceFor = internalQuery({
  args: { accountId: v.id("accounts") },
  handler: async (ctx, { accountId }) => shownBalance(ctx, accountId),
});

// A transaction as Apple last signed it, already verified (appStore.ts).
export const verifiedTransaction = v.object({
  transactionId: v.string(),
  originalTransactionId: v.string(),
  productId: v.string(),
  environment: appleEnvironment,
  purchaseDate: v.number(),
  signedDate: v.number(),
  revocationDate: v.optional(v.number()),
  appAccountToken: v.optional(v.string()),
});

export type PurchaseOutcome =
  // Its Rolls are in an Account's balance.
  | { state: "credited"; rolls: number; toCaller: boolean }
  // Apple refunded it: its Rolls are out of the balance, which may be below zero (V2-FR-65).
  | { state: "refunded"; rolls: number; toCaller: boolean }
  // No Account to credit yet: a notification for a token no Account holds. The next report from a signed-in Account
  // credits it.
  | { state: "unassigned" }
  // A consumable of this app that is no Roll pack on sale. Kept, and credited once the packs name it.
  | { state: "notOnSale" };

async function accountForToken(ctx: MutationCtx, appAccountToken: string | undefined) {
  if (appAccountToken === undefined) return null;
  const account = await ctx.db
    .query("accounts")
    .withIndex("by_app_account_token", (q) => q.eq("appAccountToken", appAccountToken))
    .unique();
  return account !== null && account.deletionRequestedAt === undefined ? account : null;
}

async function liveAccount(ctx: MutationCtx, accountId: Id<"accounts"> | undefined) {
  if (accountId === undefined) return null;
  const account = await ctx.db.get(accountId);
  return account !== null && account.deletionRequestedAt === undefined ? account : null;
}

// Makes the balance agree with Apple's latest view of one Roll purchase (V2-FR-60, V2-FR-65).
//
// - The purchase is credited to the Account its app account token names; when that names no Account, to the
//   signed-in Account that reported it; and once credited it never moves, not even after that Account is deleted.
// - Its Rolls are fixed when it is first seen.
// - A view Apple signed earlier than one already applied changes nothing, so a refund and its reversal apply in
//   Apple's order.
// - The purchase's ledger rows always add up to its Rolls while it stands and to nothing while it is refunded. A
//   refund only lowers the balance: Rolls set aside or taken in events stay as they are, and the balance may go
//   below zero.
export const applyTransaction = internalMutation({
  args: { transaction: verifiedTransaction, reporterAccountId: v.optional(v.id("accounts")) },
  handler: async (ctx, { transaction, reporterAccountId }): Promise<PurchaseOutcome> => {
    const now = Date.now();
    const packs = rollPacks();
    const pack = packs.ok ? packs.value.find((candidate) => candidate.productId === transaction.productId) : undefined;
    let purchase = await ctx.db
      .query("purchases")
      .withIndex("by_transaction", (q) => q.eq("transactionId", transaction.transactionId))
      .unique();
    const revoked = transaction.revocationDate !== undefined;
    if (purchase === null) {
      const id = await ctx.db.insert("purchases", {
        transactionId: transaction.transactionId,
        originalTransactionId: transaction.originalTransactionId,
        productId: transaction.productId,
        environment: transaction.environment,
        rolls: pack?.rolls,
        appAccountToken: transaction.appAccountToken,
        purchasedAt: transaction.purchaseDate,
        revoked,
        revokedAt: transaction.revocationDate,
        stateSignedAt: transaction.signedDate,
        firstSeenAt: now,
      });
      purchase = (await ctx.db.get(id))!;
    } else {
      const changes: Partial<Doc<"purchases">> = {};
      if (transaction.signedDate > purchase.stateSignedAt) {
        changes.revoked = revoked;
        changes.revokedAt = transaction.revocationDate;
        changes.stateSignedAt = transaction.signedDate;
      }
      if (purchase.rolls === undefined && pack !== undefined) changes.rolls = pack.rolls;
      if (Object.keys(changes).length > 0) {
        await ctx.db.patch(purchase._id, changes);
        purchase = { ...purchase, ...changes };
      }
    }

    // The Account it credits, decided once.
    if (purchase.assignedAt === undefined) {
      const owner =
        (await accountForToken(ctx, purchase.appAccountToken)) ?? (await liveAccount(ctx, reporterAccountId));
      if (owner !== null) {
        await ctx.db.patch(purchase._id, { accountId: owner._id, assignedAt: now });
        purchase = { ...purchase, accountId: owner._id, assignedAt: now };
      }
    }
    if (purchase.rolls === undefined) return { state: "notOnSale" };
    if (purchase.assignedAt === undefined) return { state: "unassigned" };
    const toCaller = reporterAccountId !== undefined && purchase.accountId === reporterAccountId;

    // The ledger, made to agree with the purchase's current state. A deleted Account's rows stay without it, and
    // nothing more is written for it.
    if (purchase.accountId !== undefined) {
      const rows = await ctx.db
        .query("rollLedger")
        .withIndex("by_transaction", (q) => q.eq("appleTransactionId", purchase.transactionId))
        .collect();
      const current = rows.reduce((total, row) => total + row.rolls, 0);
      const target = purchase.revoked ? 0 : purchase.rolls;
      const delta = target - current;
      if (delta !== 0) {
        await ctx.db.insert("rollLedger", {
          accountId: purchase.accountId,
          kind: rows.length === 0 ? "purchase" : delta < 0 ? "refund" : "refundReversed",
          rolls: delta,
          appleTransactionId: purchase.transactionId,
          at: now,
        });
      }
    }
    return purchase.revoked
      ? { state: "refunded", rolls: purchase.rolls, toCaller }
      : { state: "credited", rolls: purchase.rolls, toCaller };
  },
});

export type SubscriptionOutcome =
  // The subscription is now linked to this Account and its subscriber Rolls credited, once.
  | { state: "credited"; rolls: number }
  // This Account already holds the link, and had its subscriber Rolls when it was made.
  | { state: "alreadyCredited"; rolls: number }
  // Another Account holds the link, or held it before it was deleted; it is never named (V2-FR-63).
  | { state: "linkedElsewhere" }
  // This Account already had a subscriber's Rolls through another subscription: once ever per Account (V2-FR-62).
  | { state: "accountAlreadyCredited" }
  // Apple says the subscription is not active now: lapsed, in billing retry or refunded.
  | { state: "notActive" };

// Links a subscription Apple confirmed active to one Account and credits its subscriber Rolls, once ever for the
// Account and once ever for the subscription (V2-FR-62, V2-FR-63). Moving a link is support's, never the app's.
export const linkSubscription = internalMutation({
  args: {
    accountId: v.id("accounts"),
    originalTransactionId: v.string(),
    environment: appleEnvironment,
    rolls: v.number(),
  },
  handler: async (ctx, { accountId, originalTransactionId, environment, rolls }): Promise<SubscriptionOutcome> => {
    const account = await liveAccount(ctx, accountId);
    if (account === null) refuse("accountDeleted");
    const existing = await ctx.db
      .query("subscriptionLinks")
      .withIndex("by_original_transaction", (q) =>
        q.eq("environment", environment).eq("originalTransactionId", originalTransactionId),
      )
      .unique();
    if (existing !== null) {
      return existing.accountId === accountId
        ? { state: "alreadyCredited", rolls: existing.rollsCredited }
        : { state: "linkedElsewhere" };
    }
    const own = await ctx.db
      .query("subscriptionLinks")
      .withIndex("by_account", (q) => q.eq("accountId", accountId))
      .first();
    if (own !== null) return { state: "accountAlreadyCredited" };
    if (!Number.isInteger(rolls) || rolls < 1) refuse("subscriberRollsNotOffered");
    const now = Date.now();
    await ctx.db.insert("subscriptionLinks", {
      accountId,
      originalTransactionId,
      environment,
      linkedAt: now,
      rollsCredited: rolls,
    });
    await ctx.db.insert("rollLedger", { accountId, kind: "free", freeGrant: "subscriber", rolls, at: now });
    return { state: "credited", rolls };
  },
});
