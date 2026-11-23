// Push tokens for the one alert, "Your Film is ready" (V2-FR-70). One row per installation of the full app, owned
// by its signed-in Account, by the guest identity that joined from it, or by both. Kept until sign-out, Delete
// Account, removal, or Apple's rejection of the token (section 8).
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { internalMutation, internalQuery, mutation, type MutationCtx } from "./_generated/server";
import { guestCredentials, identityForCredentials, maySeeAlbum, requireAccount } from "./lib/callers";
import { refuse } from "./lib/errors";

const INSTALLATION_ID = /^[A-Za-z0-9_-]{22,64}$/;
// An APNs device token is hex; Apple says not to assume its length, so only its alphabet and a sane bound are held.
const DEVICE_TOKEN = /^[0-9a-f]{32,400}$/;

export const environmentValidator = v.union(v.literal("sandbox"), v.literal("production"));

type Owner = { accountId: Id<"accounts"> } | { guestIdentityId: Id<"guestIdentities"> };

// Stores an installation's token for an owner, keeping the other owner the installation already has: one row per
// installation, which can carry both the Account signed in on it and the phone's guest identity.
async function upsert(ctx: MutationCtx, installationId: string, token: string, environment: Doc<"pushTokens">["environment"], owner: Owner) {
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
  const fields = { token, environment, updatedAt: now, ...owner };
  if (existing === null) await ctx.db.insert("pushTokens", { installationId, ...fields });
  else await ctx.db.patch(existing._id, fields);
}

// Registers this installation's token for the signed-in Account.
export const register = mutation({
  args: { installationId: v.string(), token: v.string(), environment: environmentValidator },
  handler: async (ctx, { installationId, token, environment }) => {
    const account = await requireAccount(ctx);
    await upsert(ctx, installationId, token, environment, { accountId: account._id });
    return { registered: true };
  },
});

// Registers this installation's token for the phone's guest identity, so a guest with the full app gets the alert at
// each event's reveal (V2-FR-70).
export const registerGuest = mutation({
  args: { installationId: v.string(), token: v.string(), environment: environmentValidator, guest: guestCredentials },
  handler: async (ctx, { installationId, token, environment, guest }) => {
    const identity = await identityForCredentials(ctx, guest);
    if (identity === null) refuse("guestTokenRefused");
    await upsert(ctx, installationId, token, environment, { guestIdentityId: identity._id });
    return { registered: true };
  },
});

// Drops the signed-in Account from this installation's token at sign-out; the row goes once nothing owns it. Repeating
// it, or calling it with nothing registered, does nothing.
export const unregister = mutation({
  args: { installationId: v.string() },
  handler: async (ctx, { installationId }) => {
    const account = await requireAccount(ctx);
    const existing = await ctx.db
      .query("pushTokens")
      .withIndex("by_installation", (q) => q.eq("installationId", installationId))
      .unique();
    if (existing !== null && existing.accountId === account._id) {
      if (existing.guestIdentityId === undefined) await ctx.db.delete(existing._id);
      else await ctx.db.patch(existing._id, { accountId: undefined });
    }
    return { unregistered: true };
  },
});

// Marks the event's alert sent and returns where it goes: the title, and the token of every installation of a member
// who may see the album (a guest who left included, a removed guest not) and of the Host. Null once it was sent, so
// the alert goes out once per event (V2-FR-70).
export const claimFilmReadyAlert = internalMutation({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const event = await ctx.db.get(eventId);
    if (event === null || event.state !== "revealed" || event.alertSentAt !== undefined) return null;
    await ctx.db.patch(eventId, { alertSentAt: Date.now() });
    const owners: Owner[] = [];
    if (event.hostAccountId !== undefined) owners.push({ accountId: event.hostAccountId });
    for (const membership of await ctx.db
      .query("memberships")
      .withIndex("by_event", (q) => q.eq("eventId", eventId))
      .collect()) {
      if (!maySeeAlbum(membership)) continue;
      if (membership.accountId !== undefined) owners.push({ accountId: membership.accountId });
      if (membership.guestIdentityId !== undefined) owners.push({ guestIdentityId: membership.guestIdentityId });
    }
    const tokens = new Map<string, Doc<"pushTokens">["environment"]>();
    for (const owner of owners) {
      const rows =
        "accountId" in owner
          ? await ctx.db.query("pushTokens").withIndex("by_account", (q) => q.eq("accountId", owner.accountId)).collect()
          : await ctx.db
              .query("pushTokens")
              .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", owner.guestIdentityId))
              .collect();
      for (const row of rows) tokens.set(row.token, row.environment);
    }
    return { title: event.title, tokens: [...tokens].map(([token, environment]) => ({ token, environment })) };
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
