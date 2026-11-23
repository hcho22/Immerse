// The guest identity and its short-lived token (V2-FR-23, section 9.2, open check OC-4).
//
// A guest identity is a random id and a secret the phone makes at joining; the server keeps only a SHA-256
// verifier of the secret (the secret is 32 random bytes, so a fast hash is enough). In exchange for the secret, a
// member is given a token for one event, which every guest function takes as an argument (lib/callers.ts). The
// token rather than Convex's own authentication carries the guest because it needs no second token issuer, and
// revoking it is deleting its row: a removed guest's token stops working at once.
//
// Stage 1 builds the token and its checks; joining, which makes the identity and its membership, is Stage 2.
import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";
import { internalMutation, mutation, type MutationCtx } from "./_generated/server";
import { constantTimeEqual, randomToken, sha256Hex } from "./lib/crypto";
import { liveEvent, maySendPictures } from "./lib/callers";
import { refuse } from "./lib/errors";

// A guest token lasts one hour; the app asks for a new one with the secret when it runs out.
export const GUEST_TOKEN_MS = 60 * 60 * 1000;
const PUBLIC_ID = /^[A-Za-z0-9_-]{22,64}$/;
const SECRET = /^[A-Za-z0-9_-]{43,128}$/;

// Makes a guest identity, or returns the one with this id when the secret matches, so a retried join does not make
// a second one. Stage 2's join calls it.
export async function ensureGuestIdentity(
  ctx: MutationCtx,
  publicId: string,
  secret: string,
): Promise<Id<"guestIdentities">> {
  if (!PUBLIC_ID.test(publicId) || !SECRET.test(secret)) refuse("invalid", "Malformed guest identity");
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

// Exchanges a guest identity's secret for a token in one event where it holds a current place. The same answer is
// given for an unknown identity, a wrong secret, and an identity with no place, so the endpoint reveals nothing.
export const startSession = mutation({
  args: { publicId: v.string(), secret: v.string(), eventId: v.id("events") },
  handler: async (ctx, { publicId, secret, eventId }) => {
    if (!PUBLIC_ID.test(publicId) || !SECRET.test(secret)) refuse("guestTokenRefused");
    const identity = await ctx.db
      .query("guestIdentities")
      .withIndex("by_public_id", (q) => q.eq("publicId", publicId))
      .unique();
    const verifier = await sha256Hex(secret);
    if (identity === null || !constantTimeEqual(identity.secretVerifier, verifier)) refuse("guestTokenRefused");
    // A claimed identity acts through its Account from then on (section 9.2: the phone's secret is retired).
    if (identity.accountId !== undefined) refuse("guestTokenRefused");
    await liveEvent(ctx, eventId);
    const membership = await ctx.db
      .query("memberships")
      .withIndex("by_event_and_guest_identity", (q) => q.eq("eventId", eventId).eq("guestIdentityId", identity._id))
      .unique();
    if (!maySendPictures(membership)) refuse("guestTokenRefused");
    const now = Date.now();
    // Expired tokens of this identity are dropped as new ones are made.
    const sessions = await ctx.db
      .query("guestSessions")
      .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", identity._id))
      .collect();
    for (const session of sessions) if (session.expiresAt <= now) await ctx.db.delete(session._id);
    const token = randomToken();
    const expiresAt = now + GUEST_TOKEN_MS;
    await ctx.db.insert("guestSessions", {
      tokenHash: await sha256Hex(token),
      guestIdentityId: identity._id,
      eventId,
      expiresAt,
    });
    return { token, expiresAt };
  },
});

// Ends every token a guest identity holds in one event, for removal from it (Stage 2's Remove Guest calls this).
export const endSessions = internalMutation({
  args: { guestIdentityId: v.id("guestIdentities"), eventId: v.id("events") },
  handler: async (ctx, { guestIdentityId, eventId }) => {
    const sessions = await ctx.db
      .query("guestSessions")
      .withIndex("by_guest_identity", (q) => q.eq("guestIdentityId", guestIdentityId))
      .collect();
    for (const session of sessions) if (session.eventId === eventId) await ctx.db.delete(session._id);
  },
});
