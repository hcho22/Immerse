// The album and its read grants (V2-FR-37, V2-FR-41, V2-FR-43, V2-FR-45, section 9.4, open check OC-4).
//
// Before the reveal the server issues no read address for any picture, to anyone, the Host and the picture's own
// shooter included. After it, a member who was not removed (a guest who left included) or the event's Host gets the
// album: every picture in capture order across all guests, numbered, with a numbered gap where one was withdrawn or
// removed (V2-FR-45), and for each picture still there presigned GET addresses for its viewing copy and the full
// picture, valid for one minute. The bucket is private, so an object's key alone reads nothing, and a removed picture's
// objects are deleted, so an address issued before its removal stops working when they go (deletion.ts,
// storageQueue.ts). This is the one place a read address is made, and where a key could be released later should
// sealing ever need encryption.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Doc } from "./_generated/dataModel";
import { action, internalQuery } from "./_generated/server";
import { isHostOf, liveEvent, maySeeAlbum, membershipOf, resolveCaller } from "./lib/callers";
import { refusalForPlace } from "./lib/callers";
import { refuse } from "./lib/errors";
import { phaseOf } from "./lib/phase";
import { presignRead, READ_ADDRESS_SECONDS, storageConfig } from "./lib/storage";

type StoredEntry = {
  number: number;
  removed: false;
  pictureId: string;
  exposureNumber: number;
  shooterName: string;
  captureTime: number;
  contentType: string;
  size: number;
  sha256: string;
  storageKey: string;
  viewStorageKey: string | null;
  // The caller took it: they may remove it (V2-FR-51) and not report it.
  mine: boolean;
};
type GapEntry = { number: number; removed: true };
type AlbumEntry = StoredEntry | GapEntry;

// Album order: capture time across all guests, then arrival, so a late picture takes its place by capture time
// (V2-FR-41) and the numbering holds still for everything already there.
function captureOrder(a: Doc<"pictures">, b: Doc<"pictures">) {
  return (a.captureTime ?? 0) - (b.captureTime ?? 0) || a._creationTime - b._creationTime;
}

export const albumEntries = internalQuery({
  args: { eventId: v.id("events"), guestToken: v.optional(v.string()) },
  handler: async (ctx, { eventId, guestToken }) => {
    const caller = await resolveCaller(ctx, eventId, guestToken);
    const event = await liveEvent(ctx, eventId);
    const isHost = isHostOf(event, caller);
    const membership = await membershipOf(ctx, eventId, caller);
    if (!isHost && !maySeeAlbum(membership)) refuse(refusalForPlace(membership));
    // Sealed until the reveal, for everyone (V2-FR-37).
    if (phaseOf(event, Date.now()) !== "revealed") refuse("sealed");
    const pictures = (await ctx.db
      .query("pictures")
      .withIndex("by_event", (q) => q.eq("eventId", eventId))
      .collect())
      .filter((picture) => picture.state === "stored" || picture.everStored === true)
      .sort(captureOrder);
    const names = new Map<string, string>();
    const entries: AlbumEntry[] = [];
    for (const [index, picture] of pictures.entries()) {
      const number = index + 1;
      if (picture.state !== "stored") {
        entries.push({ number, removed: true });
        continue;
      }
      if (!names.has(picture.membershipId)) {
        names.set(picture.membershipId, (await ctx.db.get(picture.membershipId))?.guestName ?? "");
      }
      entries.push({
        number,
        removed: false,
        pictureId: picture._id,
        exposureNumber: picture.exposureNumber,
        shooterName: names.get(picture.membershipId) ?? "",
        captureTime: picture.captureTime ?? 0,
        contentType: picture.contentType ?? "",
        size: picture.size ?? 0,
        sha256: picture.sha256 ?? "",
        storageKey: picture.storageKey ?? "",
        viewStorageKey: picture.viewStorageKey ?? null,
        mine: membership !== null && picture.membershipId === membership._id,
      });
    }
    return { camera: event.camera, isHost, entries };
  },
});

export type AlbumPicture = Omit<StoredEntry, "storageKey" | "viewStorageKey"> & {
  url: string;
  viewUrl: string;
  expiresAt: number;
};

// The revealed album, with read addresses for every picture still in it. The app asks again for fresh addresses when
// they run out.
export const album = action({
  args: { eventId: v.id("events"), guestToken: v.optional(v.string()) },
  handler: async (ctx, args): Promise<{ camera: string; isHost: boolean; entries: Array<AlbumPicture | GapEntry> }> => {
    const { camera, isHost, entries }: { camera: string; isHost: boolean; entries: AlbumEntry[] } = await ctx.runQuery(
      internal.reads.albumEntries,
      args,
    );
    const config = storageConfig();
    const expiresAt = Date.now() + READ_ADDRESS_SECONDS * 1000;
    const signed = await Promise.all(
      entries.map(async (entry): Promise<AlbumPicture | GapEntry> => {
        if (entry.removed) return entry;
        const { storageKey, viewStorageKey, ...picture } = entry;
        const url = (await presignRead(config, storageKey)).url;
        const viewUrl = viewStorageKey !== null ? (await presignRead(config, viewStorageKey)).url : url;
        return { ...picture, url, viewUrl, expiresAt };
      }),
    );
    return { camera, isHost, entries: signed };
  },
});
