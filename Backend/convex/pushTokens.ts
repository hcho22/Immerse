// Push tokens for the one alert, "Your Film is ready" (V2-FR-70). One row per installation of the full app, owned
// by its signed-in Account or, from Stage 2, by the guest identity that joined from it. Kept until sign-out, Delete
// Account, removal, or Apple's rejection of the token (section 8).
import { v } from "convex/values";
import { internalMutation, internalQuery, mutation } from "./_generated/server";
import { requireAccount } from "./lib/callers";
import { refuse } from "./lib/errors";

const INSTALLATION_ID = /^[A-Za-z0-9_-]{22,64}$/;
// An APNs device token is hex; Apple says not to assume its length, so only its alphabet and a sane bound are held.
const DEVICE_TOKEN = /^[0-9a-f]{32,400}$/;

export const environmentValidator = v.union(v.literal("sandbox"), v.literal("production"));

// Registers this installation's token for the signed-in Account, replacing whatever the installation held before.
export const register = mutation({
  args: { installationId: v.string(), token: v.string(), environment: environmentValidator },
  handler: async (ctx, { installationId, token, environment }) => {
    const account = await requireAccount(ctx);
    if (!INSTALLATION_ID.test(installationId) || !DEVICE_TOKEN.test(token)) refuse("invalid", "Malformed push token");
    const now = Date.now();
    // A token belongs to one installation: an older row with the same token (a reinstall) is dropped.
    for (const stale of await ctx.db.query("pushTokens").withIndex("by_token", (q) => q.eq("token", token)).collect()) {
      if (stale.installationId !== installationId) await ctx.db.delete(stale._id);
    }
    const existing = await ctx.db
      .query("pushTokens")
      .withIndex("by_installation", (q) => q.eq("installationId", installationId))
      .unique();
    const fields = { token, environment, accountId: account._id, guestIdentityId: undefined, updatedAt: now };
    if (existing === null) await ctx.db.insert("pushTokens", { installationId, ...fields });
    else await ctx.db.patch(existing._id, fields);
    return { registered: true };
  },
});

// Drops this installation's token at sign-out. Repeating it, or calling it with nothing registered, does nothing.
export const unregister = mutation({
  args: { installationId: v.string() },
  handler: async (ctx, { installationId }) => {
    const account = await requireAccount(ctx);
    const existing = await ctx.db
      .query("pushTokens")
      .withIndex("by_installation", (q) => q.eq("installationId", installationId))
      .unique();
    if (existing !== null && existing.accountId === account._id) await ctx.db.delete(existing._id);
    return { unregistered: true };
  },
});

export const tokensForAccount = internalQuery({
  args: { accountId: v.id("accounts") },
  handler: (ctx, { accountId }) =>
    ctx.db
      .query("pushTokens")
      .withIndex("by_account", (q) => q.eq("accountId", accountId))
      .collect(),
});

// Apple rejected a token as no longer valid: it is deleted (section 8).
export const dropRejected = internalMutation({
  args: { token: v.string() },
  handler: async (ctx, { token }) => {
    for (const row of await ctx.db.query("pushTokens").withIndex("by_token", (q) => q.eq("token", token)).collect()) {
      await ctx.db.delete(row._id);
    }
  },
});
