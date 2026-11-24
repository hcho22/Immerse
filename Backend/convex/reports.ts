// Reporting a picture (v2 PRD V2-FR-54, OQ-12): after the reveal any guest can report a picture they think is
// inappropriate or unsafe. The report reaches the Host in the app (`hosting:view` lists it, never with its reporter) and
// Immerse's support address, through the relay the operator configures: the server posts each report, signed, to
// SUPPORT_REPORT_WEBHOOK_URL, which forwards it to the support address (Backend/SETUP.md). The address itself is
// configuration and is never committed. A report removes nothing by itself; the Host or support removes a picture.
// Immerse's operator answers reports within 48 hours (OQ-12, answered 2026-11-23); `support:openReports` lists the
// ones past it.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalAction, internalMutation, internalQuery, mutation } from "./_generated/server";
import { bytesToHex } from "./lib/crypto";
import { isHostOf, liveEvent, maySeeAlbum, membershipOf, resolveCaller } from "./lib/callers";
import { MINUTE_MS, HOUR_MS } from "./lib/config";
import { refuse } from "./lib/errors";
import { phaseOf } from "./lib/phase";
import { reportReasonValidator } from "./schema";

// A failed delivery is tried again after these delays, then every six hours until it gets through.
const RETRY_DELAYS_MS = [MINUTE_MS, 5 * MINUTE_MS, 15 * MINUTE_MS, HOUR_MS];
const LAST_RETRY_DELAY_MS = 6 * HOUR_MS;

export const report = mutation({
  args: {
    eventId: v.id("events"),
    guestToken: v.optional(v.string()),
    pictureId: v.id("pictures"),
    reason: reportReasonValidator,
  },
  handler: async (ctx, { eventId, guestToken, pictureId, reason }) => {
    const caller = await resolveCaller(ctx, eventId, guestToken);
    const event = await liveEvent(ctx, eventId);
    const membership = await membershipOf(ctx, eventId, caller);
    if (!maySeeAlbum(membership)) refuse("notAMember");
    // A report goes to the Host; the Host removes a picture instead (section 4.2).
    if (isHostOf(event, caller)) refuse("invalid", "The Host removes pictures rather than reporting them");
    if (phaseOf(event, Date.now()) !== "revealed") refuse("notRevealed");
    const picture = await ctx.db.get(pictureId);
    if (picture === null || picture.eventId !== eventId || picture.state !== "stored") refuse("invalid", "No such picture");
    const existing = await ctx.db
      .query("reports")
      .withIndex("by_picture_and_reporter", (q) => q.eq("pictureId", pictureId).eq("reporterMembershipId", membership._id))
      .unique();
    if (existing !== null) return { reported: true };
    const reportId = await ctx.db.insert("reports", {
      eventId,
      pictureId,
      reporterMembershipId: membership._id,
      reason,
      at: Date.now(),
      deliveryAttempts: 0,
    });
    await ctx.scheduler.runAfter(0, internal.reports.deliver, { reportId });
    return { reported: true };
  },
});

// What support receives: the event, the picture's place in the album, the reason and when. The reporter is named only
// by an opaque id, for support's own record; never by name.
export const deliveryContent = internalQuery({
  args: { reportId: v.id("reports") },
  handler: async (ctx, { reportId }) => {
    const report = await ctx.db.get(reportId);
    if (report === null || report.deliveredAt !== undefined) return null;
    const event = await ctx.db.get(report.eventId);
    const picture = await ctx.db.get(report.pictureId);
    return {
      reportId,
      eventId: report.eventId,
      eventTitle: event?.title ?? "",
      hostLeft: event !== null && event.hostAccountId === undefined,
      pictureId: report.pictureId,
      pictureState: picture?.state ?? "removed",
      reason: report.reason,
      reportedAt: report.at,
      reporter: report.reporterMembershipId,
      attempts: report.deliveryAttempts,
    };
  },
});

export const recordDelivery = internalMutation({
  args: { reportId: v.id("reports"), delivered: v.boolean() },
  handler: async (ctx, { reportId, delivered }) => {
    const report = await ctx.db.get(reportId);
    if (report === null || report.deliveredAt !== undefined) return;
    const attempts = report.deliveryAttempts + 1;
    if (delivered) {
      await ctx.db.patch(reportId, { deliveredAt: Date.now(), deliveryAttempts: attempts });
      return;
    }
    await ctx.db.patch(reportId, { deliveryAttempts: attempts });
    const delay = RETRY_DELAYS_MS[attempts - 1] ?? LAST_RETRY_DELAY_MS;
    await ctx.scheduler.runAfter(delay, internal.reports.deliver, { reportId });
  },
});

async function signature(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, [
    "sign",
  ]);
  return bytesToHex(new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body))));
}

// Posts a report to the support relay, signed with SUPPORT_REPORT_WEBHOOK_SECRET in `x-immerse-signature`, and keeps
// trying until the relay accepts it. A deployment without a relay keeps the report for `support:openReports` and tries
// again, so a relay configured later still receives it.
export const deliver = internalAction({
  args: { reportId: v.id("reports") },
  handler: async (ctx, { reportId }) => {
    const content = await ctx.runQuery(internal.reports.deliveryContent, { reportId });
    if (content === null) return;
    const url = process.env.SUPPORT_REPORT_WEBHOOK_URL;
    const secret = process.env.SUPPORT_REPORT_WEBHOOK_SECRET;
    let delivered = false;
    if (url && secret) {
      const body = JSON.stringify({ type: "picture.reported", ...content });
      try {
        const response = await fetch(url, {
          method: "POST",
          headers: { "content-type": "application/json", "x-immerse-signature": `sha256=${await signature(secret, body)}` },
          body,
        });
        delivered = response.ok;
        if (!delivered) console.error(`Report delivery failed with HTTP ${response.status}`);
      } catch (error) {
        console.error(`Report delivery failed: ${String(error)}`);
      }
    } else {
      console.error("Report delivery skipped: SUPPORT_REPORT_WEBHOOK_URL or SUPPORT_REPORT_WEBHOOK_SECRET is not set");
    }
    await ctx.runMutation(internal.reports.recordDelivery, { reportId, delivered });
  },
});

// Deletes reports resolved more than 90 days ago (section 8); a gone or deleted event's purge takes the rest.
export const expireResolved = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    const resolved = await ctx.db
      .query("reports")
      .withIndex("by_resolution", (q) => q.gt("resolvedAt", 0))
      .take(500);
    for (const report of resolved) {
      if (report.expiresAt !== undefined && report.expiresAt <= now) await ctx.db.delete(report._id);
    }
  },
});
