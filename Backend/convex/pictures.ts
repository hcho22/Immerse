// The upload path (V2-FR-34, V2-FR-35, section 9.3, open check OC-3).
//
// 1. The phone asks `requestUpload` for permission to send one developed picture, naming its event, exposure
//    number, capture time, content type, size and SHA-256, and those of the smaller viewing copy it made (section 9.4).
// 2. The server checks the shooter's place, the event and the exposure, records the picture as uploading, and
//    returns one-time upload addresses: presigned R2 PUTs for unguessable keys, valid for five minutes and bound to
//    the content type and the checksum.
// 3. The phone sends the files straight to R2 at those addresses.
// 4. The phone calls `confirmUpload`; the server reads the objects back, checks their sizes and SHA-256, and only then
//    records the picture stored and tells the phone it may delete its copy. A mismatch deletes the object and the
//    phone sends the picture again.
//
// Every step repeats safely: asking again for a stored picture answers "stored", so a picture sent twice is stored
// once (V2-FR-35); asking again while uploading gives fresh addresses for the same keys; a removed or withdrawn picture
// is refused for good. A picture taken before the End Time is accepted until the album ends, and a late one joins the
// revealed album in its place by capture time (V2-FR-41).
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Doc, Id } from "./_generated/dataModel";
import { action, internalMutation, internalQuery } from "./_generated/server";
import { crc32 } from "./lib/crc32";
import { isBase64Sha256, randomToken, sha256Base64 } from "./lib/crypto";
import { liveEvent, maySendPictures, membershipOf, resolveCaller } from "./lib/callers";
import { refusalForPlace } from "./lib/callers";
import { refuse } from "./lib/errors";
import { phaseOf } from "./lib/phase";
import {
  MAX_PICTURE_BYTES,
  PICTURE_CONTENT_TYPES,
  presignUpload,
  readObject,
  storageConfig,
  UPLOAD_ADDRESS_SECONDS,
  VIEW_CONTENT_TYPE,
} from "./lib/storage";
import { queueStorageDeletion } from "./deletion";

const pictureArgs = {
  eventId: v.id("events"),
  exposureNumber: v.number(),
  guestToken: v.optional(v.string()),
};

const fileArgs = {
  captureTime: v.number(),
  contentType: v.string(),
  size: v.number(),
  sha256: v.string(),
  // The viewing copy (section 9.4): a smaller JPEG of the developed picture, made on the phone.
  view: v.optional(v.object({ size: v.number(), sha256: v.string() })),
};

type Target = { storageKey: string; contentType: string; sha256: string };
export type UploadDecision = { status: "upload"; picture: Target; view: Target | null } | { status: "stored" };

function checkSize(size: number) {
  if (!Number.isInteger(size) || size <= 0 || size > MAX_PICTURE_BYTES) refuse("invalid", "Size out of range");
}

export const reserveUpload = internalMutation({
  args: { ...pictureArgs, ...fileArgs },
  handler: async (ctx, args): Promise<UploadDecision> => {
    if (!(PICTURE_CONTENT_TYPES as readonly string[]).includes(args.contentType)) refuse("invalid", "Unsupported content type");
    checkSize(args.size);
    if (!isBase64Sha256(args.sha256)) refuse("invalid", "Malformed checksum");
    if (args.view !== undefined) {
      checkSize(args.view.size);
      if (!isBase64Sha256(args.view.sha256)) refuse("invalid", "Malformed checksum");
    }
    if (!Number.isFinite(args.captureTime)) refuse("invalid", "Malformed capture time");
    const caller = await resolveCaller(ctx, args.eventId, args.guestToken);
    const event = await liveEvent(ctx, args.eventId);
    const membership = await membershipOf(ctx, args.eventId, caller);
    if (!maySendPictures(membership)) refuse(refusalForPlace(membership));
    if (!Number.isInteger(args.exposureNumber) || args.exposureNumber < 1 || args.exposureNumber > event.exposuresPerRoll) {
      refuse("invalid", "Exposure number out of range");
    }
    // Nobody shoots before the Start Time (V2-FR-12).
    if (phaseOf(event, Date.now()) === "scheduled") refuse("notYetOpen");
    // A picture taken after the server's End Time is refused, whatever the phone believed (V2-FR-31).
    if (args.captureTime > event.endsAt) refuse("afterEndTime");
    // Withdraw Before Reveal took every exposure up to this one for good (V2-FR-50).
    if (args.exposureNumber <= (membership.withdrawnThrough ?? 0)) refuse("pictureRemoved");

    const now = Date.now();
    const existing = await ctx.db
      .query("pictures")
      .withIndex("by_shooter_and_exposure", (q) =>
        q.eq("membershipId", membership._id).eq("exposureNumber", args.exposureNumber),
      )
      .unique();
    const sameFile = (picture: Doc<"pictures">) =>
      picture.sha256 === args.sha256 &&
      picture.size === args.size &&
      picture.contentType === args.contentType &&
      picture.viewSha256 === args.view?.sha256 &&
      picture.viewSize === args.view?.size;
    const decision = (picture: { storageKey: string; viewStorageKey?: string }): UploadDecision => ({
      status: "upload",
      picture: { storageKey: picture.storageKey, contentType: args.contentType, sha256: args.sha256 },
      view:
        args.view !== undefined && picture.viewStorageKey !== undefined
          ? { storageKey: picture.viewStorageKey, contentType: VIEW_CONTENT_TYPE, sha256: args.view.sha256 }
          : null,
    });
    const fields = () => ({
      captureTime: args.captureTime,
      contentType: args.contentType,
      size: args.size,
      sha256: args.sha256,
      storageKey: newStorageKey(args.eventId),
      viewSize: args.view?.size,
      viewSha256: args.view?.sha256,
      viewStorageKey: args.view !== undefined ? newStorageKey(args.eventId) : undefined,
      requestedAt: now,
    });

    if (existing !== null) {
      if (existing.state === "removed") refuse("pictureRemoved");
      if (existing.state === "stored") {
        if (existing.sha256 === args.sha256 && existing.size === args.size && existing.contentType === args.contentType) {
          return { status: "stored" };
        }
        refuse("exposureTaken");
      }
      // Still uploading: the same files get new addresses for their keys; different files replace them.
      if (sameFile(existing) && existing.storageKey !== undefined) {
        return decision({ storageKey: existing.storageKey, viewStorageKey: existing.viewStorageKey });
      }
      for (const key of [existing.storageKey, existing.viewStorageKey]) {
        if (key !== undefined) await queueStorageDeletion(ctx, key, now);
      }
      const replaced = fields();
      await ctx.db.patch(existing._id, replaced);
      return decision(replaced);
    }

    const created = fields();
    await ctx.db.insert("pictures", {
      eventId: args.eventId,
      membershipId: membership._id,
      exposureNumber: args.exposureNumber,
      state: "uploading",
      ...created,
    });
    return decision(created);
  },
});

// An unguessable key that names nothing about the shooter.
function newStorageKey(eventId: Id<"events">): string {
  return `pictures/${eventId}/${randomToken(24)}`;
}

type SignedAddress = { url: string; method: "PUT" | "GET"; headers: Record<string, string> };
export type UploadAddresses =
  | { status: "stored" }
  | (SignedAddress & { status: "upload"; view: SignedAddress | null; expiresAt: number });

export const requestUpload = action({
  args: { ...pictureArgs, ...fileArgs },
  handler: async (ctx, args): Promise<UploadAddresses> => {
    const decision: UploadDecision = await ctx.runMutation(internal.pictures.reserveUpload, args);
    if (decision.status === "stored") return { status: "stored" as const };
    const config = storageConfig();
    const address = await presignUpload(config, decision.picture.storageKey, decision.picture.contentType, decision.picture.sha256);
    const view: SignedAddress | null =
      decision.view !== null
        ? await presignUpload(config, decision.view.storageKey, decision.view.contentType, decision.view.sha256)
        : null;
    return {
      status: "upload" as const,
      url: address.url,
      method: address.method,
      headers: address.headers,
      view: view !== null ? { url: view.url, method: view.method, headers: view.headers } : null,
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
    if (!maySendPictures(membership)) refuse(refusalForPlace(membership));
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
      viewStorageKey: picture.viewStorageKey,
      viewSize: picture.viewSize,
      viewSha256: picture.viewSha256,
    };
  },
});

export const markStored = internalMutation({
  args: {
    pictureId: v.id("pictures"),
    storageKey: v.string(),
    viewStorageKey: v.optional(v.string()),
    sha256: v.string(),
    crc32: v.number(),
  },
  handler: async (ctx, { pictureId, storageKey, viewStorageKey, sha256, crc32 }): Promise<"stored" | "removed" | "changed"> => {
    const picture = await ctx.db.get(pictureId);
    if (picture === null || picture.state === "removed") {
      // Removed while it was being checked: its objects must go too (section 9.8).
      const now = Date.now();
      await queueStorageDeletion(ctx, storageKey, now);
      if (viewStorageKey !== undefined) await queueStorageDeletion(ctx, viewStorageKey, now);
      return "removed";
    }
    if (picture.state === "stored") return picture.storageKey === storageKey ? "stored" : "changed";
    // Replaced by a different file while this one was being checked.
    if (picture.storageKey !== storageKey || picture.sha256 !== sha256) return "changed";
    await ctx.db.patch(pictureId, { state: "stored", storedAt: Date.now(), everStored: true, crc32 });
    // The Host's list shows each guest's exposures used (V2-FR-22); a stored picture proves at least this many.
    const membership = await ctx.db.get(picture.membershipId);
    if (membership !== null && membership.exposuresUsed < picture.exposureNumber) {
      await ctx.db.patch(membership._id, { exposuresUsed: picture.exposureNumber });
    }
    return "stored";
  },
});

// Rejects an object that does not match what the phone said it sent: both objects are deleted, and the picture moves
// to new keys, so the deletion can never reach the files the phone sends next.
export const rejectObject = internalMutation({
  args: { pictureId: v.id("pictures"), storageKey: v.string() },
  handler: async (ctx, { pictureId, storageKey }) => {
    const now = Date.now();
    const picture = await ctx.db.get(pictureId);
    if (picture === null || picture.state !== "uploading" || picture.storageKey !== storageKey) {
      await queueStorageDeletion(ctx, storageKey, now);
      return;
    }
    for (const key of [picture.storageKey, picture.viewStorageKey]) {
      if (key !== undefined) await queueStorageDeletion(ctx, key, now);
    }
    await ctx.db.patch(pictureId, {
      storageKey: newStorageKey(picture.eventId),
      viewStorageKey: picture.viewStorageKey !== undefined ? newStorageKey(picture.eventId) : undefined,
      requestedAt: now,
    });
  },
});

// Whether the object at a key is what the phone said it sent, with its CRC-32 when it is; null when no object is there.
async function matches(key: string, size: number, sha256: string): Promise<{ whole: boolean; crc32: number } | null> {
  const object = await readObject(storageConfig(), key);
  if (object === null) return null;
  const whole = object.size === size && object.bytes.byteLength === size && (await sha256Base64(object.bytes)) === sha256;
  return { whole, crc32: whole ? crc32(object.bytes) : 0 };
}

// Confirms an upload by the objects' sizes and SHA-256. "stored" means the phone may delete its copy (V2-FR-34).
// "missing" and "mismatch" mean it must ask for addresses and send the picture again.
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
    const full = await matches(picture.storageKey, picture.size, picture.sha256);
    const checks = [full];
    if (picture.viewStorageKey !== undefined && picture.viewSize !== undefined && picture.viewSha256 !== undefined) {
      checks.push(await matches(picture.viewStorageKey, picture.viewSize, picture.viewSha256));
    }
    if (checks.some((check) => check !== null && !check.whole)) {
      await ctx.runMutation(internal.pictures.rejectObject, { pictureId: picture._id, storageKey: picture.storageKey });
      return { status: "mismatch" };
    }
    if (full === null || checks.includes(null)) return { status: "missing" };
    const outcome = await ctx.runMutation(internal.pictures.markStored, {
      pictureId: picture._id,
      storageKey: picture.storageKey,
      viewStorageKey: picture.viewStorageKey,
      sha256: picture.sha256,
      crc32: full.crc32,
    });
    if (outcome === "removed") refuse("pictureRemoved");
    return { status: outcome === "stored" ? "stored" : "missing" };
  },
});
