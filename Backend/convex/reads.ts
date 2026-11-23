// Read grants (V2-FR-37, V2-FR-43, section 9.4, open check OC-4).
//
// Before the reveal the server issues no read address for any picture, to anyone, the Host and the picture's own
// shooter included. After it, a member who was not removed (a guest who left included) or the event's Host gets a
// presigned GET address for each stored picture, valid for one minute. The bucket is private, so an object's key
// alone reads nothing, and a removed picture's object is deleted, so an address issued before its removal stops
// working when the object goes (deletion.ts, storageQueue.ts).
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { action, internalQuery } from "./_generated/server";
import { liveEvent, maySeeAlbum, membershipOf, resolveCaller } from "./lib/callers";
import { refuse } from "./lib/errors";
import { presignRead, READ_ADDRESS_SECONDS, storageConfig } from "./lib/storage";

type ReadablePicture = {
  exposureNumber: number;
  shooterName: string;
  captureTime: number;
  contentType: string;
  size: number;
  sha256: string;
  storageKey: string;
};

export type ReadAddress = Omit<ReadablePicture, "storageKey"> & { url: string; expiresAt: number };

export const readablePictures = internalQuery({
  args: { eventId: v.id("events"), guestToken: v.optional(v.string()) },
  handler: async (ctx, { eventId, guestToken }): Promise<ReadablePicture[]> => {
    const caller = await resolveCaller(ctx, eventId, guestToken);
    const event = await liveEvent(ctx, eventId);
    const isHost = caller.kind === "account" && event.hostAccountId === caller.account._id;
    const membership = await membershipOf(ctx, eventId, caller);
    if (!isHost && !maySeeAlbum(membership)) refuse("notAMember");
    // Sealed until the reveal, for everyone (V2-FR-37).
    if (event.state !== "revealed") refuse("sealed");
    const pictures = await ctx.db
      .query("pictures")
      .withIndex("by_event", (q) => q.eq("eventId", eventId))
      .filter((q) => q.eq(q.field("state"), "stored"))
      .collect();
    const names = new Map<string, string>();
    for (const picture of pictures) {
      if (!names.has(picture.membershipId)) {
        names.set(picture.membershipId, (await ctx.db.get(picture.membershipId))?.guestName ?? "");
      }
    }
    return pictures.map((picture) => ({
      exposureNumber: picture.exposureNumber,
      shooterName: names.get(picture.membershipId) ?? "",
      captureTime: picture.captureTime ?? 0,
      contentType: picture.contentType ?? "",
      size: picture.size ?? 0,
      sha256: picture.sha256 ?? "",
      storageKey: picture.storageKey ?? "",
    }));
  },
});

// Read addresses for every stored picture of a revealed event the caller may see.
export const readAddresses = action({
  args: { eventId: v.id("events"), guestToken: v.optional(v.string()) },
  handler: async (ctx, args): Promise<ReadAddress[]> => {
    const pictures: ReadablePicture[] = await ctx.runQuery(internal.reads.readablePictures, args);
    const config = storageConfig();
    const expiresAt = Date.now() + READ_ADDRESS_SECONDS * 1000;
    return Promise.all(
      pictures.map(async ({ storageKey, ...picture }) => ({
        ...picture,
        url: (await presignRead(config, storageKey)).url,
        expiresAt,
      })),
    );
  },
});
