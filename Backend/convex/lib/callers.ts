// Who is asking. Every public function resolves its caller here, on the server, whatever the app shows
// (V2-FR-01, V2-FR-80, V2-FR-81).
//
// A signed-in person is a Clerk session that Convex verified against Clerk's issuer (auth.config.ts). A guest with
// no Account is a short-lived guest token for one event, passed as an argument (open check OC-4, section 9.2): the
// token is random, only its hash is stored, and it names one guest identity in one event, so it can act for nobody
// else and stops working the moment its session row is deleted (a removed guest, Delete Guest Identity).
import type { Doc, Id } from "../_generated/dataModel";
import type { QueryCtx } from "../_generated/server";
import { sha256Hex } from "./crypto";
import { refuse } from "./errors";

export async function signedInIdentity(ctx: QueryCtx) {
  const identity = await ctx.auth.getUserIdentity();
  if (identity === null) refuse("unauthenticated");
  return identity;
}

// The caller's Account, refused when there is no Clerk session, no Account yet, or the Account is being deleted.
export async function requireAccount(ctx: QueryCtx): Promise<Doc<"accounts">> {
  const identity = await signedInIdentity(ctx);
  const account = await ctx.db
    .query("accounts")
    .withIndex("by_token", (q) => q.eq("tokenIdentifier", identity.tokenIdentifier))
    .unique();
  if (account === null) refuse("noAccount");
  if (account.deletionRequestedAt !== undefined) refuse("accountDeleted");
  return account;
}

// The guest identity a token names, refused unless the token is current and was issued for this event.
export async function guestIdentityForToken(
  ctx: QueryCtx,
  eventId: Id<"events">,
  guestToken: string,
): Promise<Id<"guestIdentities">> {
  const tokenHash = await sha256Hex(guestToken);
  const session = await ctx.db
    .query("guestSessions")
    .withIndex("by_token_hash", (q) => q.eq("tokenHash", tokenHash))
    .unique();
  if (session === null || session.eventId !== eventId || session.expiresAt <= Date.now()) {
    refuse("guestTokenRefused");
  }
  return session.guestIdentityId;
}

export type Caller =
  | { kind: "account"; account: Doc<"accounts"> }
  | { kind: "guest"; guestIdentityId: Id<"guestIdentities"> };

// A guest token when one is given, otherwise the signed-in Account.
export async function resolveCaller(
  ctx: QueryCtx,
  eventId: Id<"events">,
  guestToken: string | undefined,
): Promise<Caller> {
  if (guestToken !== undefined) {
    return { kind: "guest", guestIdentityId: await guestIdentityForToken(ctx, eventId, guestToken) };
  }
  return { kind: "account", account: await requireAccount(ctx) };
}

// The caller's place in an event, or null when they hold none.
export async function membershipOf(
  ctx: QueryCtx,
  eventId: Id<"events">,
  caller: Caller,
): Promise<Doc<"memberships"> | null> {
  if (caller.kind === "guest") {
    return ctx.db
      .query("memberships")
      .withIndex("by_event_and_guest_identity", (q) =>
        q.eq("eventId", eventId).eq("guestIdentityId", caller.guestIdentityId),
      )
      .unique();
  }
  return ctx.db
    .query("memberships")
    .withIndex("by_event_and_account", (q) => q.eq("eventId", eventId).eq("accountId", caller.account._id))
    .unique();
}

// An event that still exists: not gone at its 12-month end and not deleted by its Host.
export async function liveEvent(ctx: QueryCtx, eventId: Id<"events">): Promise<Doc<"events">> {
  const event = await ctx.db.get(eventId);
  if (event === null || event.state === "gone" || event.state === "deleted") refuse("eventGone");
  return event;
}

// A member who may still send pictures they took: joined, or left on their own (V2-FR-56: their pictures stay).
// A removed or deleted shooter may not (V2-FR-53, V2-FR-05).
export function maySendPictures(membership: Doc<"memberships"> | null): membership is Doc<"memberships"> {
  return membership !== null && (membership.status === "joined" || membership.status === "left");
}

// A member who may see the album after the reveal: everyone who joined and was not removed, a guest who left
// included (V2-FR-43, V2-FR-56).
export function maySeeAlbum(membership: Doc<"memberships"> | null): membership is Doc<"memberships"> {
  return maySendPictures(membership);
}
