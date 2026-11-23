// The upload path (V2-FR-34, V2-FR-35, section 9.3, open check OC-3).
//
// 1. The phone asks `requestUpload` for permission to send one developed picture, naming its event, exposure
//    number, capture time, content type, size and SHA-256.
// 2. The server checks the shooter's place, the event and the exposure, records the picture as uploading, and
//    returns a one-time upload address: a presigned R2 PUT for one unguessable key, valid for five minutes and
//    bound to the content type and the checksum.
// 3. The phone sends the file straight to R2 at that address.
// 4. The phone calls `confirmUpload`; the server reads the object back, checks its size and SHA-256, and only then
//    records it stored and tells the phone it may delete its copy. A mismatch deletes the object and the phone
//    sends the picture again.
//
// Every step repeats safely: asking again for a stored picture answers "stored", so a picture sent twice is stored
// once (V2-FR-35); asking again while uploading gives a fresh address for the same key; a removed picture is
// refused for good.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Doc, Id } from "./_generated/dataModel";
import { action, internalMutation, internalQuery } from "./_generated/server";
import { isBase64Sha256, randomToken, sha256Base64 } from "./lib/crypto";
import { liveEvent, maySendPictures, membershipOf, resolveCaller } from "./lib/callers";
import { refuse } from "./lib/errors";
import {
  MAX_PICTURE_BYTES,
  PICTURE_CONTENT_TYPES,
  presignUpload,
  readObject,
  storageConfig,
  UPLOAD_ADDRESS_SECONDS,
} from "./lib/storage";
import { queueStorageDeletion } from "./deletion";

const pictureArgs = {
  eventId: v.id("events"),
  exposureNumber: v.number(),
  guestToken: v.optional(v.string()),
};

export type UploadDecision =
  | { status: "upload"; storageKey: string; contentType: string; sha256: string }
  | { status: "stored" };

export const reserveUpload = internalMutation({
  args: {
    ...pictureArgs,
    captureTime: v.number(),
    contentType: v.string(),
    size: v.number(),
    sha256: v.string(),
  },
  handler: async (ctx, args): Promise<UploadDecision> => {
    if (!(PICTURE_CONTENT_TYPES as readonly string[]).includes(args.contentType)) refuse("invalid", "Unsupported content type");
    if (!Number.isInteger(args.size) || args.size <= 0 || args.size > MAX_PICTURE_BYTES) refuse("invalid", "Size out of range");
    if (!isBase64Sha256(args.sha256)) refuse("invalid", "Malformed checksum");
    if (!Number.isFinite(args.captureTime)) refuse("invalid", "Malformed capture time");
    const caller = await resolveCaller(ctx, args.eventId, args.guestToken);
    const event = await liveEvent(ctx, args.eventId);
    const membership = await membershipOf(ctx, args.eventId, caller);
    if (!maySendPictures(membership)) refuse("notAMember");
    if (!Number.isInteger(args.exposureNumber) || args.exposureNumber < 1 || args.exposureNumber > event.exposuresPerRoll) {
      refuse("invalid", "Exposure number out of range");
    }
    // A picture taken after the server's End Time is refused, whatever the phone believed (V2-FR-31).
    if (args.captureTime > event.endsAt) refuse("afterEndTime");

    const now = Date.now();
    const existing = await ctx.db
      .query("pictures")
      .withIndex("by_shooter_and_exposure", (q) =>
        q.eq("membershipId", membership._id).eq("exposureNumber", args.exposureNumber),
      )
      .unique();
    const sameFile = (picture: Doc<"pictures">) =>
      picture.sha256 === args.sha256 && picture.size === args.size && picture.contentType === args.contentType;

    if (existing !== null) {
      if (existing.state === "removed") refuse("pictureRemoved");
      if (existing.state === "stored") {
        if (sameFile(existing)) return { status: "stored" };
        refuse("exposureTaken");
      }
      // Still uploading: the same file gets a new address for its key; a different file replaces it.
      if (sameFile(existing) && existing.storageKey !== undefined) {
        return { status: "upload", storageKey: existing.storageKey, contentType: args.contentType, sha256: args.sha256 };
      }
      if (existing.storageKey !== undefined) await queueStorageDeletion(ctx, existing.storageKey, now);
      const storageKey = newStorageKey(args.eventId);
      await ctx.db.patch(existing._id, {
        captureTime: args.captureTime,
        contentType: args.contentType,
        size: args.size,
        sha256: args.sha256,
        storageKey,
        requestedAt: now,
      });
      return { status: "upload", storageKey, contentType: args.contentType, sha256: args.sha256 };
    }

    const storageKey = newStorageKey(args.eventId);
    await ctx.db.insert("pictures", {
      eventId: args.eventId,
      membershipId: membership._id,
      exposureNumber: args.exposureNumber,
      state: "uploading",
      captureTime: args.captureTime,
      contentType: args.contentType,
      size: args.size,
      sha256: args.sha256,
      storageKey,
      requestedAt: now,
    });
    return { status: "upload", storageKey, contentType: args.contentType, sha256: args.sha256 };
  },
});

// An unguessable key that names nothing about the shooter.
function newStorageKey(eventId: Id<"events">): string {
  return `pictures/${eventId}/${randomToken(24)}`;
}

export const requestUpload = action({
  args: {
    ...pictureArgs,
    captureTime: v.number(),
    contentType: v.string(),
    size: v.number(),
    sha256: v.string(),
  },
  handler: async (ctx, args) => {
    const decision: UploadDecision = await ctx.runMutation(internal.pictures.reserveUpload, args);
    if (decision.status === "stored") return { status: "stored" as const };
    const address = await presignUpload(storageConfig(), decision.storageKey, decision.contentType, decision.sha256);
    return {
      status: "upload" as const,
      url: address.url,
      method: address.method,
      headers: address.headers,
      expiresAt: Date.now() + UPLOAD_ADDRESS_SECONDS * 1000,
    };
  },
});

export const pictureToConfirm = internalQuery({
  args: pictureArgs,
  handler: async (ctx, args) => {
    const caller = await resolveCaller(ctx, args.eventId, args.guestToken);
    await liveEvent(ctx, args.eventId);
    const membership = await membershipOf(ctx, args.eventId, caller);
    if (!maySendPictures(membership)) refuse("notAMember");
    const picture = await ctx.db
      .query("pictures")
      .withIndex("by_shooter_and_exposure", (q) =>
        q.eq("membershipId", membership._id).eq("exposureNumber", args.exposureNumber),
      )
      .unique();
    if (picture === null) return null;
    return {
      _id: picture._id,
      state: picture.state,
      storageKey: picture.storageKey,
      size: picture.size,
      sha256: picture.sha256,
    };
  },
});

export const markStored = internalMutation({
  args: { pictureId: v.id("pictures"), storageKey: v.string(), sha256: v.string() },
  handler: async (ctx, { pictureId, storageKey, sha256 }): Promise<"stored" | "removed" | "changed"> => {
    const picture = await ctx.db.get(pictureId);
    if (picture === null || picture.state === "removed") {
      // Removed while it was being checked: its object must go too (section 9.8).
      await queueStorageDeletion(ctx, storageKey, Date.now());
      return "removed";
    }
    if (picture.state === "stored") return picture.storageKey === storageKey ? "stored" : "changed";
    // Replaced by a different file while this one was being checked.
    if (picture.storageKey !== storageKey || picture.sha256 !== sha256) return "changed";
    await ctx.db.patch(pictureId, { state: "stored", storedAt: Date.now() });
    return "stored";
  },
});

// Rejects an object that does not match what the phone said it sent: the object is deleted, and the picture moves
// to a new key, so the deletion can never reach the file the phone sends next.
export const rejectObject = internalMutation({
  args: { pictureId: v.id("pictures"), storageKey: v.string() },
  handler: async (ctx, { pictureId, storageKey }) => {
    const now = Date.now();
    await queueStorageDeletion(ctx, storageKey, now);
    const picture = await ctx.db.get(pictureId);
    if (picture !== null && picture.state === "uploading" && picture.storageKey === storageKey) {
      await ctx.db.patch(pictureId, { storageKey: newStorageKey(picture.eventId), requestedAt: now });
    }
  },
});

// Confirms an upload by the object's size and SHA-256. "stored" means the phone may delete its copy (V2-FR-34).
// "missing" and "mismatch" mean it must ask for an address and send the picture again.
export const confirmUpload = action({
  args: pictureArgs,
  handler: async (ctx, args): Promise<{ status: "stored" | "missing" | "mismatch" }> => {
    const picture = await ctx.runQuery(internal.pictures.pictureToConfirm, args);
    if (picture === null) return { status: "missing" };
    if (picture.state === "removed") refuse("pictureRemoved");
    if (picture.state === "stored") return { status: "stored" };
    if (picture.storageKey === undefined || picture.size === undefined || picture.sha256 === undefined) {
      return { status: "missing" };
    }
    const object = await readObject(storageConfig(), picture.storageKey);
    if (object === null) return { status: "missing" };
    const matches =
      object.size === picture.size &&
      object.bytes.byteLength === picture.size &&
      (await sha256Base64(object.bytes)) === picture.sha256;
    if (!matches) {
      await ctx.runMutation(internal.pictures.rejectObject, { pictureId: picture._id, storageKey: picture.storageKey });
      return { status: "mismatch" };
    }
    const outcome = await ctx.runMutation(internal.pictures.markStored, {
      pictureId: picture._id,
      storageKey: picture.storageKey,
      sha256: picture.sha256,
    });
    if (outcome === "removed") refuse("pictureRemoved");
    return { status: outcome === "stored" ? "stored" : "missing" };
  },
});
