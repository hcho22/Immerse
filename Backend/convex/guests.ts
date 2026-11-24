// The guest identity and its short-lived token (V2-FR-23, section 9.2, open check OC-4).
//
// A guest identity is a random id and a secret the phone makes at joining; the server keeps only a SHA-256
// verifier of the secret (the secret is 32 random bytes, so a fast hash is enough). In exchange for the secret, a
// member is given a token for one event, which every guest function takes as an argument (lib/callers.ts). The
// token rather than Convex's own authentication carries the guest because it needs no second token issuer, and
// revoking it is deleting its row: a removed guest's token stops working at once.
//
// Joining (joining.ts) makes the identity and its place; claiming and deleting it are in identities.ts.
import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";
import { internalMutation, mutation, type MutationCtx } from "./_generated/server";
import { constantTimeEqual, randomToken, sha256Hex } from "./lib/crypto";
import { identityForCredentials, liveEvent, maySendPictures, wellFormedCredentials } from "./lib/callers";
import { refuse } from "./lib/errors";

// A guest token lasts one hour; the app asks for a new one with the secret when it runs out.
export const GUEST_TOKEN_MS = 60 * 60 * 1000;

// Makes a guest identity, or returns the one with this id when the secret matches, so a retried join does not make
// a second one. Joining calls it.
export async function ensureGuestIdentity(
  ctx: MutationCtx,
  publicId: string,
  secret: string,
): Promise<Id<"guestIdentities">> {
  if (!wellFormedCredentials({ publicId, secret })) refuse("invalid", "Malformed guest identity");
  const secretVerifier = await sha256Hex(secret);
  const existing = await ctx.db
    .query("guestIdentities")
    .withIndex("by_public_id", (q) => q.eq("publicId", publicId))
    .unique();
  if (existing !== null) {
    if (!constantTimeEqual(existing.secretVerifier, secretVerifier)) refuse("guestTokenRefused");
    return existing._id;
  }
  return ctx.db.insert("guestIdentities", { publicId, secretVerifier, createdAt: Date.now() });
}

// A new token for a guest identity in one event, dropping its expired ones.
export async function issueSession(
  ctx: MutationCtx,
  guestIdentityId: Id<"guestIdentities">,
  eventId: Id<"events">,
): Promise<{ token: string; expiresAt: number }> {
  const now = Date.now();
  const sessions = await ctx.db
    .query("guestSessions")
    .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", guestIdentityId))
    .collect();
  for (const session of sessions) if (session.expiresAt <= now) await ctx.db.delete(session._id);
  const token = randomToken();
  const expiresAt = now + GUEST_TOKEN_MS;
  await ctx.db.insert("guestSessions", { tokenHash: await sha256Hex(token), guestIdentityId, eventId, expiresAt });
  return { token, expiresAt };
}

// Exchanges a guest identity's secret for a token in one event where it holds a current place. The same answer is
// given for an unknown identity, a wrong secret, and an identity with no place, so the endpoint reveals nothing. A
// place the identity's Account claimed acts through the Account from then on (section 9.2: the phone's secret is
// retired for it), so the identity no longer holds it; a place it kept, because the Account already had one in that
// event (V2-FR-04), still answers to the secret.
export const startSession = mutation({
  args: { publicId: v.string(), secret: v.string(), eventId: v.id("events") },
  handler: async (ctx, { publicId, secret, eventId }) => {
    const identity = await identityForCredentials(ctx, { publicId, secret });
    if (identity === null) refuse("guestTokenRefused");
    await liveEvent(ctx, eventId);
    const membership = await ctx.db
      .query("memberships")
      .withIndex("by_event_and_guest_identity", (q) => q.eq("eventId", eventId).eq("guestIdentityId", identity._id))
      .unique();
    if (!maySendPictures(membership)) refuse("guestTokenRefused");
    return issueSession(ctx, identity._id, eventId);
  },
});

// Ends every token a guest identity holds in one event.
export async function endSessionsIn(ctx: MutationCtx, guestIdentityId: Id<"guestIdentities">, eventId: Id<"events">) {
  const sessions = await ctx.db
    .query("guestSessions")
    .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", guestIdentityId))
    .collect();
  for (const session of sessions) if (session.eventId === eventId) await ctx.db.delete(session._id);
}

// Deletes a guest identity once no place refers to it any more: 12 months after the last album it took part in ends
// (section 8). Each event's purge schedules this for its identities; a later event keeps the identity.
export const expireIdentity = internalMutation({
  args: { guestIdentityId: v.id("guestIdentities") },
  handler: async (ctx, { guestIdentityId }) => {
    const identity = await ctx.db.get(guestIdentityId);
    if (identity === null) return;
    const place = await ctx.db
      .query("memberships")
      .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", guestIdentityId))
      .first();
    if (place !== null) return;
    for (const session of await ctx.db
      .query("guestSessions")
      .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", guestIdentityId))
      .collect()) {
      await ctx.db.delete(session._id);
    }
    for (const row of await ctx.db
      .query("pushTokens")
      .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", guestIdentityId))
      .collect()) {
      if (row.accountId === undefined) await ctx.db.delete(row._id);
      else await ctx.db.patch(row._id, { guestIdentityId: undefined });
    }
    await ctx.db.delete(guestIdentityId);
  },
});
