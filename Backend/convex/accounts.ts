// Accounts (V2-FR-01 to V2-FR-05). Only hosting needs one; nothing here is ever asked of a guest or a personal
// Film, and none of it is reached unless a person chooses to sign in.
import { v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { requireAccount, signedInIdentity } from "./lib/callers";
import { refuse } from "./lib/errors";
import { ageConfirmationValidator } from "./schema";

export const DISPLAY_NAME_LIMIT = 40;

export function cleanDisplayName(raw: string): string {
  const name = raw.trim().replace(/\s+/g, " ");
  if (name.length === 0 || [...name].length > DISPLAY_NAME_LIMIT) refuse("invalid", "A name is 1 to 40 characters");
  return name;
}

// The signed-in person's Account, or what stands in its way. Signed out is not an error here: the app reads this
// to decide whether to confirm age and create the Account.
export const me = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) return { state: "signedOut" as const };
    const pendingClerkDeletion = await ctx.db
      .query("clerkDeletions")
      .withIndex("by_clerk_user", (q) => q.eq("clerkUserId", identity.subject))
      .unique();
    if (pendingClerkDeletion !== null) return { state: "accountDeleted" as const };
    const account = await ctx.db
      .query("accounts")
      .withIndex("by_token", (q) => q.eq("tokenIdentifier", identity.tokenIdentifier))
      .unique();
    if (account === null) return { state: "noAccount" as const };
    if (account.deletionRequestedAt !== undefined) return { state: "accountDeleted" as const };
    return {
      state: "signedIn" as const,
      account: {
        displayName: account.displayName,
        ageConfirmedAt: account.ageConfirmedAt,
        createdAt: account.createdAt,
      },
    };
  },
});

// Creates the signed-in person's Account after they confirmed they are 13 or over (V2-FR-03). The age is never
// sent: only that it was confirmed, and how. Repeating it returns the same Account and changes nothing, so an app
// that lost the reply can send it again (V2-FR-81).
export const createAccount = mutation({
  args: {
    displayName: v.string(),
    ageConfirmed: v.literal(true),
    ageConfirmation: ageConfirmationValidator,
  },
  handler: async (ctx, args) => {
    const identity = await signedInIdentity(ctx);
    const existing = await ctx.db
      .query("accounts")
      .withIndex("by_token", (q) => q.eq("tokenIdentifier", identity.tokenIdentifier))
      .unique();
    if (existing !== null) {
      if (existing.deletionRequestedAt !== undefined) refuse("accountDeleted");
      return { created: false };
    }
    // A Clerk user whose Account was deleted is being deleted at Clerk too; it cannot start a new Account. Signing
    // in again makes a new Clerk user, and so a new, empty Account (V2-FR-05).
    const pendingClerkDeletion = await ctx.db
      .query("clerkDeletions")
      .withIndex("by_clerk_user", (q) => q.eq("clerkUserId", identity.subject))
      .unique();
    if (pendingClerkDeletion !== null) refuse("accountDeleted");
    const now = Date.now();
    await ctx.db.insert("accounts", {
      tokenIdentifier: identity.tokenIdentifier,
      clerkUserId: identity.subject,
      displayName: cleanDisplayName(args.displayName),
      ageConfirmedAt: now,
      ageConfirmation: args.ageConfirmation,
      createdAt: now,
    });
    return { created: true };
  },
});

// The name guests see as the Host's. Setting the same name again changes nothing.
export const setDisplayName = mutation({
  args: { displayName: v.string() },
  handler: async (ctx, args) => {
    const account = await requireAccount(ctx);
    const displayName = cleanDisplayName(args.displayName);
    if (displayName !== account.displayName) await ctx.db.patch(account._id, { displayName });
    return { displayName };
  },
});
