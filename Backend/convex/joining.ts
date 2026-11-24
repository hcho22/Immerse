// A guest's side of a Group Film (v2 PRD sections 5.3, 5.4, 5.6 and 5.9): what the Join Code's link shows, joining and
// rejoining, the member's view of the event, leaving, the Guest Name, Withdraw Before Reveal and removing one's own
// picture after the reveal. The Host who shoots in their own event takes a Roll through `join` like any guest
// (V2-FR-25).
//
// A guest with no Account proves its guest identity with its id and secret to join or learn where it stands, and with
// the token it gets for one event for everything else (lib/callers.ts). Every rule is checked here, on the server,
// whatever the app shows, and every change can be repeated safely (V2-FR-81).
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { mutation, query, type MutationCtx, type QueryCtx } from "./_generated/server";
import { ensureGuestIdentity, issueSession } from "./guests";
import { removePicture } from "./deletion";
import {
  guestCredentials,
  identityForCredentials,
  isHostOf,
  liveEvent,
  maySendPictures,
  membershipOf,
  requireAccount,
  resolveCaller,
} from "./lib/callers";
import { refusalForPlace } from "./lib/callers";
import { refuse } from "./lib/errors";
import { cleanGuestName, eventSummary } from "./lib/events";
import { JOIN_CODE, joinCodeVerifier } from "./lib/joinCode";
import { isLive, phaseOf } from "./lib/phase";

type Place = "none" | "joined" | "left" | "removed";

// The event a Join Code names, with whether the code is still current.
async function eventForCode(ctx: QueryCtx, code: string) {
  if (!JOIN_CODE.test(code)) return null;
  const verifier = await joinCodeVerifier(code);
  const found = await ctx.db
    .query("joinCodes")
    .withIndex("by_verifier", (q) => q.eq("verifier", verifier))
    .unique();
  if (found === null) return null;
  const event = await ctx.db.get(found.eventId);
  if (event === null) return null;
  return { event, retired: found.retiredAt !== undefined };
}

// Whether this person was removed from the event: their guest identity, the Account it was claimed into, or a guest
// identity claimed into their Account (V2-FR-24: a removed guest's identity, or the Account it was claimed into, is
// refused at join).
async function wasRemoved(
  ctx: QueryCtx,
  eventId: Id<"events">,
  who: { identity?: Doc<"guestIdentities">; accountId?: Id<"accounts"> },
): Promise<boolean> {
  const removed = (membership: Doc<"memberships"> | null) => membership?.status === "removed";
  const accountIds = new Set<Id<"accounts">>();
  const identityIds = new Set<Id<"guestIdentities">>();
  if (who.identity !== undefined) {
    identityIds.add(who.identity._id);
    if (who.identity.accountId !== undefined) accountIds.add(who.identity.accountId);
  }
  if (who.accountId !== undefined) {
    accountIds.add(who.accountId);
    for (const claimed of await ctx.db
      .query("guestIdentities")
      .withIndex("by_account", (q) => q.eq("accountId", who.accountId))
      .collect()) {
      identityIds.add(claimed._id);
    }
  }
  for (const accountId of accountIds) {
    const membership = await ctx.db
      .query("memberships")
      .withIndex("by_event_and_account", (q) => q.eq("eventId", eventId).eq("accountId", accountId))
      .unique();
    if (removed(membership)) return true;
  }
  for (const guestIdentityId of identityIds) {
    const membership = await ctx.db
      .query("memberships")
      .withIndex("by_event_and_guest_identity", (q) => q.eq("eventId", eventId).eq("guestIdentityId", guestIdentityId))
      .unique();
    if (removed(membership)) return true;
  }
  return false;
}

// Who is opening the link: a guest identity (when its credentials prove it), or the signed-in Account, or nobody known.
async function opener(ctx: QueryCtx, guest: { publicId: string; secret: string } | undefined) {
  if (guest !== undefined) {
    const identity = await identityForCredentials(ctx, guest);
    return { identity: identity ?? undefined, accountId: undefined };
  }
  const signedIn = await ctx.auth.getUserIdentity();
  if (signedIn === null) return { identity: undefined, accountId: undefined };
  const account = await ctx.db
    .query("accounts")
    .withIndex("by_token", (q) => q.eq("tokenIdentifier", signedIn.tokenIdentifier))
    .unique();
  return { identity: undefined, accountId: account?.deletionRequestedAt === undefined ? account?._id : undefined };
}

async function placeOf(
  ctx: QueryCtx,
  eventId: Id<"events">,
  who: { identity?: Doc<"guestIdentities">; accountId?: Id<"accounts"> },
): Promise<Doc<"memberships"> | null> {
  if (who.identity !== undefined) {
    const identityId = who.identity._id;
    return ctx.db
      .query("memberships")
      .withIndex("by_event_and_guest_identity", (q) => q.eq("eventId", eventId).eq("guestIdentityId", identityId))
      .unique();
  }
  if (who.accountId !== undefined) {
    const accountId = who.accountId;
    return ctx.db
      .query("memberships")
      .withIndex("by_event_and_account", (q) => q.eq("eventId", eventId).eq("accountId", accountId))
      .unique();
  }
  return null;
}

function placeName(membership: Doc<"memberships"> | null): Place {
  if (membership === null || membership.status === "deleted") return "none";
  return membership.status;
}

// What a Join Code's link shows (V2-FR-18, V2-FR-21): the event's Join Confirmation, or why this person cannot join
// now, in V2-FR-18's cases. Opening the link joins nobody, and never shows a picture.
export const preview = query({
  args: { code: v.string(), guest: v.optional(guestCredentials) },
  handler: async (ctx, { code, guest }) => {
    const found = await eventForCode(ctx, code);
    if (found === null) return { status: "unknown" as const };
    const { event, retired } = found;
    const now = Date.now();
    const phase = phaseOf(event, now);
    if (!isLive(phase)) return { status: "unavailable" as const };
    if (retired) return { status: "replaced" as const };
    const who = await opener(ctx, guest);
    const membership = await placeOf(ctx, event._id, who);
    const place = placeName(membership);
    const summary = await eventSummary(ctx, event, now);
    const base = { event: summary, place, isHost: who.accountId !== undefined && who.accountId === event.hostAccountId };
    if (place === "removed" || (await wasRemoved(ctx, event._id, who))) return { status: "removed" as const, ...base };
    if (place === "joined") return { status: "member" as const, ...base };
    if (phase === "scheduled") return { status: "notYetOpen" as const, ...base };
    if (phase !== "open") return { status: place === "left" ? ("member" as const) : ("ended" as const), ...base };
    if (event.joiningPaused) return { status: "paused" as const, ...base };
    // A guest who left rejoins to their own Roll, so a full event still takes them back (V2-FR-56).
    if (place !== "left" && event.rollsTaken >= event.rollsSetAside) return { status: "full" as const, ...base };
    return { status: "open" as const, ...base };
  },
});

// What the phone needs to shoot offline after joining (V2-FR-31): the event's Camera, Film Stock, Roll and End Time.
async function joinedReply(ctx: MutationCtx, event: Doc<"events">, membership: Doc<"memberships">, guestToken?: { token: string; expiresAt: number }) {
  return {
    event: await eventSummary(ctx, event, Date.now()),
    membershipId: membership._id,
    guestName: membership.guestName,
    exposuresUsed: membership.exposuresUsed,
    withdrawnThrough: membership.withdrawnThrough ?? 0,
    guestToken: guestToken?.token ?? null,
    guestTokenExpiresAt: guestToken?.expiresAt ?? null,
  };
}

// Joins through the Join Code's link (V2-FR-21, V2-FR-24): with only a Guest Name, the guest takes one Roll, or a guest
// who left rejoins to their own Roll (V2-FR-56). A guest with no Account sends its guest identity, made on the phone; a
// signed-in person, the Host included, joins with the Account. Joining again when already in returns the same place.
export const join = mutation({
  args: { code: v.string(), guestName: v.string(), guest: v.optional(guestCredentials) },
  handler: async (ctx, { code, guestName, guest }) => {
    const found = await eventForCode(ctx, code);
    if (found === null) refuse("unknownCode");
    const { event, retired } = found;
    const now = Date.now();
    const phase = phaseOf(event, now);
    if (!isLive(phase)) refuse("eventGone");
    if (retired) refuse("codeReplaced");
    let identity: Doc<"guestIdentities"> | undefined;
    let accountId: Id<"accounts"> | undefined;
    if (guest !== undefined) {
      identity = (await ctx.db.get(await ensureGuestIdentity(ctx, guest.publicId, guest.secret)))!;
    } else {
      accountId = (await requireAccount(ctx))._id;
    }
    const who = { identity, accountId };
    const existing = await placeOf(ctx, event._id, who);
    const session = async () => (identity !== undefined ? issueSession(ctx, identity._id, event._id) : undefined);
    if (existing?.status === "removed" || (await wasRemoved(ctx, event._id, who))) refuse("removedFromEvent");
    if (existing?.status === "joined") return joinedReply(ctx, event, existing, await session());
    if (phase === "scheduled") refuse("notYetOpen");
    if (phase !== "open") refuse("shootingEnded");
    if (event.joiningPaused) refuse("joiningPaused");
    if (existing?.status === "left") {
      await ctx.db.patch(existing._id, { status: "joined", leftAt: undefined });
      return joinedReply(ctx, event, (await ctx.db.get(existing._id))!, await session());
    }
    const name = cleanGuestName(guestName);
    // Two people taking the last Roll at once: Convex runs the two joins one after the other, so exactly one gets it.
    if (event.rollsTaken >= event.rollsSetAside) refuse("rollsTaken");
    const membershipId = await ctx.db.insert("memberships", {
      eventId: event._id,
      accountId,
      guestIdentityId: identity?._id,
      guestName: name,
      exposuresUsed: 0,
      status: "joined",
      joinedAt: now,
    });
    await ctx.db.patch(event._id, { rollsTaken: event.rollsTaken + 1 });
    return joinedReply(ctx, event, (await ctx.db.get(membershipId))!, await session());
  },
});

// Where this person stands in an event, for the phone to act on whatever happened while it was offline: still in, left,
// removed by the Host (its waiting pictures and kept Instant prints for the event are deleted, V2-FR-53), or the event
// deleted or gone (the same, V2-FR-55). A removed guest learns only that, never why.
export const standing = query({
  args: { eventId: v.id("events"), guest: v.optional(guestCredentials) },
  handler: async (ctx, { eventId, guest }) => {
    const event = await ctx.db.get(eventId);
    if (event === null || event.state === "deleted") return { event: "deleted" as const, place: "none" as const };
    const now = Date.now();
    const phase = phaseOf(event, now);
    if (phase === "gone") return { event: "gone" as const, place: "none" as const };
    const who = await opener(ctx, guest);
    if (who.identity === undefined && who.accountId === undefined) {
      if (guest !== undefined) return { event: phase, place: "none" as const };
      await requireAccount(ctx);
    }
    const membership = await placeOf(ctx, eventId, who);
    const place: Place = (await wasRemoved(ctx, eventId, who)) ? "removed" : placeName(membership);
    return {
      event: phase,
      place,
      endsAt: event.endsAt,
      revealsAt: event.revealsAt,
      exposuresUsed: membership?.exposuresUsed ?? 0,
      withdrawnThrough: membership?.withdrawnThrough ?? 0,
    };
  },
});

// The caller's place in an event, refused unless it is current (joined, or left on their own).
async function currentPlace(ctx: QueryCtx, eventId: Id<"events">, guestToken: string | undefined) {
  const caller = await resolveCaller(ctx, eventId, guestToken);
  const event = await liveEvent(ctx, eventId);
  const membership = await membershipOf(ctx, eventId, caller);
  if (!maySendPictures(membership)) refuse(refusalForPlace(membership));
  return { caller, event, membership };
}

// The event as a member sees it (V2-FR-29's counterpart for guests, V2-FR-35, V2-FR-38, V2-FR-48): its settings and
// times, the countdown to the reveal, the album's end notices, the member's own name, exposures and which of their
// pictures the server holds (so the phone knows what still waits to upload), and never anyone's picture.
export const memberView = query({
  args: { eventId: v.id("events"), guestToken: v.optional(v.string()) },
  handler: async (ctx, { eventId, guestToken }) => {
    const { caller, event, membership } = await currentPlace(ctx, eventId, guestToken);
    const pictures = await ctx.db
      .query("pictures")
      .withIndex("by_shooter_and_exposure", (q) => q.eq("membershipId", membership._id))
      .collect();
    return {
      event: await eventSummary(ctx, event, Date.now()),
      isHost: isHostOf(event, caller),
      membershipId: membership._id,
      guestName: membership.guestName,
      status: membership.status,
      exposuresUsed: membership.exposuresUsed,
      withdrawnThrough: membership.withdrawnThrough ?? 0,
      storedExposures: pictures.filter((p) => p.state === "stored").map((p) => p.exposureNumber),
      removedExposures: pictures.filter((p) => p.state === "removed").map((p) => p.exposureNumber),
    };
  },
});

// The events the signed-in person joined, for the Film Library on any iPhone they sign in on (V2-FR-04).
export const mine = query({
  args: {},
  handler: async (ctx) => {
    const account = await requireAccount(ctx);
    const now = Date.now();
    const memberships = await ctx.db
      .query("memberships")
      .withIndex("by_account", (q) => q.eq("accountId", account._id))
      .collect();
    const result = [];
    for (const membership of memberships) {
      if (!maySendPictures(membership)) continue;
      const event = await ctx.db.get(membership.eventId);
      if (event === null || !isLive(phaseOf(event, now))) continue;
      result.push({
        event: await eventSummary(ctx, event, now),
        membershipId: membership._id,
        guestName: membership.guestName,
        exposuresUsed: membership.exposuresUsed,
        status: membership.status,
        isHost: event.hostAccountId === account._id,
      });
    }
    return result;
  },
});

// The phone reports how many exposures its guest has used, so the Host's list shows it (V2-FR-22, V2-FR-29). The
// count only grows.
export const reportExposures = mutation({
  args: { eventId: v.id("events"), guestToken: v.optional(v.string()), exposuresUsed: v.number() },
  handler: async (ctx, { eventId, guestToken, exposuresUsed }) => {
    const { event, membership } = await currentPlace(ctx, eventId, guestToken);
    if (!Number.isInteger(exposuresUsed) || exposuresUsed < 0 || exposuresUsed > event.exposuresPerRoll) {
      refuse("invalid", "Exposures out of range");
    }
    if (exposuresUsed > membership.exposuresUsed) await ctx.db.patch(membership._id, { exposuresUsed });
    return { exposuresUsed: Math.max(exposuresUsed, membership.exposuresUsed) };
  },
});

// A guest leaves (V2-FR-56): they stop shooting, their Roll stays used and their pictures stay; they still see the
// album after the reveal, and may rejoin through the current link while the event is open. The Host cannot leave
// their own event.
export const leave = mutation({
  args: { eventId: v.id("events"), guestToken: v.optional(v.string()) },
  handler: async (ctx, { eventId, guestToken }) => {
    const { caller, event, membership } = await currentPlace(ctx, eventId, guestToken);
    if (isHostOf(event, caller)) refuse("invalid", "The Host cannot leave their own event");
    if (membership.status === "joined") await ctx.db.patch(membership._id, { status: "left", leftAt: Date.now() });
    return { left: true };
  },
});

// Changes the Guest Name until the album ends; it shows on all the guest's pictures (V2-FR-22).
export const setGuestName = mutation({
  args: { eventId: v.id("events"), guestToken: v.optional(v.string()), guestName: v.string() },
  handler: async (ctx, { eventId, guestToken, guestName }) => {
    const { membership } = await currentPlace(ctx, eventId, guestToken);
    const name = cleanGuestName(guestName);
    if (name !== membership.guestName) await ctx.db.patch(membership._id, { guestName: name });
    return { guestName: name };
  },
});

// Withdraw Before Reveal (V2-FR-50): before the reveal, every picture the guest took in the event goes, unseen and for
// good, and no exposure comes back. The phone deletes what waits on it and names the last exposure it had used; the
// server removes what it holds and refuses any picture up to that exposure that arrives later, whatever sends it.
export const withdraw = mutation({
  args: { eventId: v.id("events"), guestToken: v.optional(v.string()), throughExposure: v.number() },
  handler: async (ctx, { eventId, guestToken, throughExposure }) => {
    const { event, membership } = await currentPlace(ctx, eventId, guestToken);
    if (!Number.isInteger(throughExposure) || throughExposure < 0 || throughExposure > event.exposuresPerRoll) {
      refuse("invalid", "Exposure out of range");
    }
    const now = Date.now();
    if (phaseOf(event, now) === "revealed") refuse("alreadyRevealed");
    const pictures = await ctx.db
      .query("pictures")
      .withIndex("by_shooter_and_exposure", (q) => q.eq("membershipId", membership._id))
      .collect();
    const highest = pictures.reduce((max, picture) => Math.max(max, picture.exposureNumber), 0);
    const through = Math.max(membership.withdrawnThrough ?? 0, throughExposure, highest);
    for (const picture of pictures) await removePicture(ctx, picture, now, "withdrawal");
    await ctx.db.patch(membership._id, {
      withdrawnThrough: through,
      exposuresUsed: Math.max(membership.exposuresUsed, through),
    });
    return { withdrawnThrough: through };
  },
});

// A guest removes one of their own pictures after the reveal, for everyone (V2-FR-51). No exposure comes back.
export const removeMyPicture = mutation({
  args: { eventId: v.id("events"), guestToken: v.optional(v.string()), exposureNumber: v.number() },
  handler: async (ctx, { eventId, guestToken, exposureNumber }) => {
    const { event, membership } = await currentPlace(ctx, eventId, guestToken);
    const now = Date.now();
    if (phaseOf(event, now) !== "revealed") refuse("notRevealed");
    const picture = await ctx.db
      .query("pictures")
      .withIndex("by_shooter_and_exposure", (q) => q.eq("membershipId", membership._id).eq("exposureNumber", exposureNumber))
      .unique();
    if (picture === null) refuse("invalid", "No such picture");
    await removePicture(ctx, picture, now, "shooter");
    return { removed: true };
  },
});
