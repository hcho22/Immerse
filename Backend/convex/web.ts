// What the join page and the view-only web album may show (v2 PRD V2-FR-15, V2-FR-18, V2-FR-47, V2-FR-48, section 9.4).
//
// The join page is a Cloudflare Worker (Backend/worker). It holds no credential for the picture bucket and decides
// nothing: for every page and every picture it asks here, over the HTTP routes in http.ts, which only the Worker can
// call (WEB_GATEWAY_SECRET). This file is where the rules are held, on the server, whatever the Worker or a browser
// sends:
//
// - A link's page says what V2-FR-18 lists for its case and never more than the event's title, Host name, Camera and
//   times. A replaced code, a deleted event and an album that has ended say nothing of the event at all.
// - The album's pictures are listed, and a read address is signed for one of them, only while the event is revealed,
//   its web album is switched on, the code in the link is the event's current one and the picture is stored. Before the
//   reveal, with the switch off, after it is switched off again, for a withdrawn or removed picture, a removed guest's
//   pictures, and a deleted or gone event, nothing is listed and no address is signed.
// - A read address is given to the Worker, never to a browser: the Worker fetches the picture and passes its bytes on,
//   so switching the album off stops the very next picture, also at an address a viewer copied earlier.
//
// The page has no viewer to identify, so it shows what anyone with the link may see; members reach the album in the
// app or the mini-app (reads.ts).
import { v } from "convex/values";
import type { Doc } from "./_generated/dataModel";
import { internalQuery, type QueryCtx } from "./_generated/server";
import { albumEndsAt, albumNotice, isLive, opensAt, phaseOf } from "./lib/phase";
import { JOIN_CODE, joinCodeVerifier } from "./lib/joinCode";

// Album order, as in reads.ts: capture time across all guests, then arrival.
function captureOrder(a: Doc<"pictures">, b: Doc<"pictures">) {
  return (a.captureTime ?? 0) - (b.captureTime ?? 0) || a._creationTime - b._creationTime;
}

type Found = { event: Doc<"events">; retired: boolean };

async function eventForCode(ctx: QueryCtx, code: string): Promise<Found | null> {
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

// Whether the event's pictures may be shown on the web now.
function sharedOnTheWeb(found: Found | null, now: number): found is Found {
  return found !== null && !found.retired && phaseOf(found.event, now) === "revealed" && found.event.webAlbumOn;
}

export type WebAlbumEntry =
  | { number: number; removed: true }
  | {
      number: number;
      removed: false;
      pictureId: string;
      shooterName: string;
      captureTime: number;
      contentType: string;
      size: number;
      crc32: number | null;
    };

export type WebPage =
  // No event has this code, the event was deleted, or its album has ended: "This event is no longer available."
  | { status: "unknown" | "unavailable" }
  // The code was replaced: "This link no longer works; ask the Host for the new one."
  | { status: "replaced" }
  | {
      // scheduled: opens at its Start Time. open: anyone can join now. paused: joining is paused. full: every Roll is
      // taken. ended: shooting has ended and the album has not revealed. revealed: the album has revealed.
      status: "scheduled" | "open" | "paused" | "full" | "ended" | "revealed";
      event: {
        title: string;
        hostName: string | null;
        hostLeft: boolean;
        camera: Doc<"events">["camera"];
        filmStock: Doc<"events">["filmStock"] | null;
        exposuresPerRoll: number;
        opensAt: number;
        endsAt: number;
        revealsAt: number;
        albumEndsAt: number;
        albumNotice: "none" | "month" | "week";
      };
      // The album, only while it is revealed and switched on; null means its pictures are not shared on the web.
      album: WebAlbumEntry[] | null;
    };

export const page = internalQuery({
  args: { code: v.string() },
  handler: async (ctx, { code }): Promise<WebPage> => {
    const found = await eventForCode(ctx, code);
    if (found === null) return { status: "unknown" };
    const { event, retired } = found;
    const now = Date.now();
    const phase = phaseOf(event, now);
    if (!isLive(phase)) return { status: "unavailable" };
    if (retired) return { status: "replaced" };
    const host = event.hostAccountId !== undefined ? await ctx.db.get(event.hostAccountId) : null;
    const described = {
      title: event.title,
      hostName: host?.displayName ?? null,
      hostLeft: event.hostAccountId === undefined,
      camera: event.camera,
      filmStock: event.filmStock ?? null,
      exposuresPerRoll: event.exposuresPerRoll,
      opensAt: opensAt(event),
      endsAt: event.endsAt,
      revealsAt: event.revealsAt,
      albumEndsAt: albumEndsAt(event),
      albumNotice: albumNotice(event, now),
    };
    if (phase === "scheduled") return { status: "scheduled", event: described, album: null };
    if (phase === "open") {
      const status = event.joiningPaused ? "paused" : event.rollsTaken >= event.rollsSetAside ? "full" : "open";
      return { status, event: described, album: null };
    }
    if (phase !== "revealed") return { status: "ended", event: described, album: null };
    if (!sharedOnTheWeb(found, now)) return { status: "revealed", event: described, album: null };
    const pictures = (await ctx.db
      .query("pictures")
      .withIndex("by_event", (q) => q.eq("eventId", event._id))
      .collect())
      .filter((picture) => picture.state === "stored" || picture.everStored === true)
      .sort(captureOrder);
    const names = new Map<string, string>();
    const album: WebAlbumEntry[] = [];
    for (const [index, picture] of pictures.entries()) {
      const number = index + 1;
      if (picture.state !== "stored") {
        album.push({ number, removed: true });
        continue;
      }
      if (!names.has(picture.membershipId)) {
        names.set(picture.membershipId, (await ctx.db.get(picture.membershipId))?.guestName ?? "");
      }
      album.push({
        number,
        removed: false,
        pictureId: picture._id,
        shooterName: names.get(picture.membershipId) ?? "",
        captureTime: picture.captureTime ?? 0,
        contentType: picture.contentType ?? "image/jpeg",
        size: picture.size ?? 0,
        crc32: picture.crc32 ?? null,
      });
    }
    return { status: "revealed", event: described, album };
  },
});

export type PictureGrant =
  | { granted: false }
  | { granted: true; storageKey: string; contentType: string; size: number };

// The one picture a web-album viewer asks for, by the link's code and the picture's id: its full file or its viewing
// copy. Granted only while the album is shared on the web and the picture is stored in that event; every other case is
// the same refusal, which says nothing of why.
export const pictureGrant = internalQuery({
  args: { code: v.string(), pictureId: v.string(), copy: v.union(v.literal("view"), v.literal("full")) },
  handler: async (ctx, { code, pictureId, copy }): Promise<PictureGrant> => {
    const found = await eventForCode(ctx, code);
    if (!sharedOnTheWeb(found, Date.now())) return { granted: false };
    const id = ctx.db.normalizeId("pictures", pictureId);
    if (id === null) return { granted: false };
    const picture = await ctx.db.get(id);
    if (picture === null || picture.eventId !== found.event._id || picture.state !== "stored") return { granted: false };
    if (picture.storageKey === undefined || picture.size === undefined) return { granted: false };
    if (copy === "view" && picture.viewStorageKey !== undefined && picture.viewSize !== undefined) {
      return { granted: true, storageKey: picture.viewStorageKey, contentType: "image/jpeg", size: picture.viewSize };
    }
    return {
      granted: true,
      storageKey: picture.storageKey,
      contentType: picture.contentType ?? "image/jpeg",
      size: picture.size,
    };
  },
});
