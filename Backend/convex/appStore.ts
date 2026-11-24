"use node";
// Where the server meets Apple for Rolls (v2 PRD V2-FR-60 to V2-FR-65, section 9.7), in Convex's Node runtime, whose
// crypto reads Apple's certificates.
//
// - `creditPurchase`: the app reports a Roll purchase's signed transaction. The server checks Apple signed it for this
//   app, asks Apple's App Store Server API for the transaction as it stands now, and credits that, once. The app
//   finishes the transaction only after this answers.
// - `linkSubscription`: a signed-in subscriber's app sends the v1 subscription's signed transaction. The server asks
//   Apple for the subscription's status and, only while Apple says it is active, links it to the Account and credits
//   the subscriber's free Rolls, once ever.
// - `receiveNotification`: Apple's App Store Server Notifications (version 2), posted to `/apple/notifications`
//   (http.ts). A purchase, a refund and a refund's reversal each carry the transaction as Apple signed it, which is
//   applied as the app's report is, so a purchase whose app never reports it, such as an Ask to Buy approved later, is
//   still credited, and a refund removes its Rolls without the app.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { action, internalAction, type ActionCtx } from "./_generated/server";
import {
  appStoreApiCredentials,
  appStoreSettings,
  rollPacks,
  type AppleEnvironment,
  type AppStoreSettings,
} from "./lib/appStoreConfig";
import {
  AppStoreUnavailable,
  currentTransaction,
  subscriptionStatus,
  SUBSCRIPTION_ACTIVE,
  SUBSCRIPTION_IN_GRACE_PERIOD,
  verifiedTransaction,
  type AppleTransaction,
} from "./lib/appStoreApi";
import { SignedDataRefused, verifyAppleSigned } from "./lib/appleSigned";
import { freeRollsForSubscribers } from "./lib/config";
import { refuse } from "./lib/errors";
import type { PurchaseOutcome, SubscriptionOutcome } from "./purchases";

const CONSUMABLE = "Consumable";
const AUTO_RENEWABLE = "Auto-Renewable Subscription";

// A transaction this deployment accepts at all: this app's, from an environment it credits.
function accepted(transaction: AppleTransaction, settings: AppStoreSettings): AppleEnvironment | null {
  if (transaction.bundleId !== settings.bundleId) return null;
  const environment = transaction.environment as AppleEnvironment;
  return settings.environments.includes(environment) ? environment : null;
}

function readReported(signedTransaction: string): AppleTransaction {
  try {
    return verifiedTransaction(signedTransaction);
  } catch (error) {
    if (error instanceof SignedDataRefused) refuse("purchaseRefused", error.message);
    throw error;
  }
}

async function askApple<T>(question: () => Promise<T>): Promise<T> {
  try {
    return await question();
  } catch (error) {
    if (error instanceof AppStoreUnavailable) {
      console.warn(error.message);
      refuse("storeUnavailable");
    }
    if (error instanceof SignedDataRefused) {
      // Apple's own answer did not verify: never believed, and never a reason to refuse the purchase for good.
      console.error(`The App Store Server API's answer did not verify: ${error.message}`);
      refuse("storeUnavailable");
    }
    throw error;
  }
}

async function callerAccount(ctx: ActionCtx): Promise<Id<"accounts"> | null> {
  const identity = await ctx.auth.getUserIdentity();
  if (identity === null) return null;
  return ctx.runQuery(internal.purchases.liveAccountFor, { tokenIdentifier: identity.tokenIdentifier });
}

function forApplying(transaction: AppleTransaction, environment: AppleEnvironment) {
  return {
    transactionId: transaction.transactionId,
    originalTransactionId: transaction.originalTransactionId,
    productId: transaction.productId,
    environment,
    purchaseDate: transaction.purchaseDate,
    signedDate: transaction.signedDate,
    revocationDate: transaction.revocationDate,
    appAccountToken: transaction.appAccountToken,
  };
}

export type CreditReply = PurchaseOutcome & {
  // The signed-in caller's balance after it, when the caller has an Account.
  balance: number | null;
};

// The app reports a Roll purchase (V2-FR-60). Signed-out reports are allowed: the purchase names its Account through
// its app account token, so a Host who signed out before the app reported still gets the Rolls.
export const creditPurchase = action({
  args: { signedTransaction: v.string() },
  handler: async (ctx, { signedTransaction }): Promise<CreditReply> => {
    const settings = appStoreSettings();
    const credentials = appStoreApiCredentials();
    if (!settings.ok || !credentials.ok || !rollPacks().ok) refuse("purchasesUnavailable");
    const reported = readReported(signedTransaction);
    const environment = accepted(reported, settings.value);
    if (environment === null || reported.type !== CONSUMABLE) {
      refuse("purchaseRefused", "Not a Roll purchase of this app that this deployment credits");
    }
    const reporter = await callerAccount(ctx);
    const answer = await askApple(() =>
      currentTransaction(credentials.value, settings.value.bundleId, environment, reported.transactionId),
    );
    // Apple has not got it yet, or never had it: nothing is credited, and the app asks again later.
    if (!answer.found) refuse("storeUnavailable");
    const current = answer.value;
    if (
      current.transactionId !== reported.transactionId ||
      current.bundleId !== settings.value.bundleId ||
      current.environment !== environment ||
      current.type !== CONSUMABLE
    ) {
      refuse("purchaseRefused", "Apple's transaction does not match the one reported");
    }
    const outcome: PurchaseOutcome = await ctx.runMutation(internal.purchases.applyTransaction, {
      transaction: forApplying(current, environment),
      reporterAccountId: reporter ?? undefined,
    });
    const balance = reporter === null ? null : await ctx.runQuery(internal.purchases.balanceFor, { accountId: reporter });
    return { ...outcome, balance };
  },
});

export type SubscriptionReply = SubscriptionOutcome & { balance: number };

// A signed-in subscriber's app sends the v1 subscription's signed transaction (V2-FR-63). The subscription stays
// account-free for personal Films: only this link knows the Account, and only for the subscriber Rolls.
export const linkSubscription = action({
  args: { signedTransaction: v.string() },
  handler: async (ctx, { signedTransaction }): Promise<SubscriptionReply> => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) refuse("unauthenticated");
    const accountId = await ctx.runQuery(internal.purchases.liveAccountFor, { tokenIdentifier: identity.tokenIdentifier });
    if (accountId === null) refuse("noAccount");
    const settings = appStoreSettings();
    const credentials = appStoreApiCredentials();
    const rolls = freeRollsForSubscribers();
    if (!settings.ok || !credentials.ok || rolls < 1 || settings.value.subscriptionProductIds.length === 0) {
      refuse("subscriberRollsNotOffered");
    }
    const reported = readReported(signedTransaction);
    const environment = accepted(reported, settings.value);
    if (
      environment === null ||
      reported.type !== AUTO_RENEWABLE ||
      !settings.value.subscriptionProductIds.includes(reported.productId)
    ) {
      refuse("purchaseRefused", "Not the subscription of this app that this deployment accepts");
    }
    const answer = await askApple(() =>
      subscriptionStatus(
        credentials.value,
        settings.value.bundleId,
        environment,
        reported.transactionId,
        reported.originalTransactionId,
      ),
    );
    if (!answer.found) refuse("storeUnavailable");
    const { status, transaction } = answer.value;
    const active =
      (status === SUBSCRIPTION_ACTIVE || status === SUBSCRIPTION_IN_GRACE_PERIOD) &&
      transaction.revocationDate === undefined &&
      transaction.bundleId === settings.value.bundleId &&
      transaction.environment === environment &&
      settings.value.subscriptionProductIds.includes(transaction.productId);
    const outcome: SubscriptionOutcome = active
      ? await ctx.runMutation(internal.purchases.linkSubscription, {
          accountId,
          originalTransactionId: transaction.originalTransactionId,
          environment,
          rolls,
        })
      : { state: "notActive" };
    const balance = await ctx.runQuery(internal.purchases.balanceFor, { accountId });
    return { ...outcome, balance };
  },
});

// The notification types that carry a Roll purchase's state: bought (including an Ask to Buy approved later),
// refunded, and refund reversed.
const PURCHASE_NOTIFICATIONS = new Set(["ONE_TIME_CHARGE", "REFUND", "REFUND_REVERSED"]);

export type NotificationReply = { status: number; handled: string };

// One App Store Server Notification. The HTTP status it returns tells Apple whether to send it again: 200 when it is
// applied or needs nothing, 401 when it is not Apple's, 400 when it is not for this app, and 503 while the deployment
// cannot apply it, so Apple retries.
export const receiveNotification = internalAction({
  args: { signedPayload: v.string() },
  handler: async (ctx, { signedPayload }): Promise<NotificationReply> => {
    const settings = appStoreSettings();
    if (!settings.ok) {
      console.error(`An App Store notification arrived, but ${settings.problem}`);
      return { status: 503, handled: "notConfigured" };
    }
    let notification: Record<string, unknown>;
    try {
      notification = verifyAppleSigned(signedPayload);
    } catch (error) {
      if (error instanceof SignedDataRefused) return { status: 401, handled: "notApples" };
      throw error;
    }
    const type = notification.notificationType;
    const data = notification.data as Record<string, unknown> | undefined;
    if (type === "TEST") return { status: 200, handled: "test" };
    if (data === undefined || typeof data !== "object") return { status: 200, handled: "noData" };
    if (data.bundleId !== settings.value.bundleId) return { status: 400, handled: "otherApp" };
    const environment = data.environment as AppleEnvironment;
    if (!settings.value.environments.includes(environment)) return { status: 200, handled: "otherEnvironment" };
    if (environment === "Production" && data.appAppleId !== settings.value.appAppleId) {
      return { status: 400, handled: "otherApp" };
    }
    if (typeof type !== "string" || !PURCHASE_NOTIFICATIONS.has(type)) return { status: 200, handled: "ignored" };
    if (typeof data.signedTransactionInfo !== "string") return { status: 400, handled: "noTransaction" };
    let transaction: AppleTransaction;
    try {
      transaction = verifiedTransaction(data.signedTransactionInfo);
    } catch (error) {
      if (error instanceof SignedDataRefused) return { status: 401, handled: "notApples" };
      throw error;
    }
    if (transaction.bundleId !== settings.value.bundleId || transaction.environment !== environment) {
      return { status: 400, handled: "otherApp" };
    }
    // A subscription's refund or charge needs nothing: subscriber Rolls are credited once, at the link, and stay
    // (V2-FR-63).
    if (transaction.type !== CONSUMABLE) return { status: 200, handled: "notARollPurchase" };
    // A failure here throws, and the route answers 500, so Apple sends the notification again.
    const outcome: PurchaseOutcome = await ctx.runMutation(internal.purchases.applyTransaction, {
      transaction: forApplying(transaction, environment),
    });
    return { status: 200, handled: outcome.state };
  },
});
