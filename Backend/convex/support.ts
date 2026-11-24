// What Immerse's operator uses to answer reports (v2 PRD V2-FR-54, OQ-12): the open reports, with those past the 48
// hours the operator answers within, removing a reported picture from any event, a deleted Host's included (V2-FR-06),
// and closing a report with the picture kept. These are internal functions: they run only from the Convex dashboard or
// `npx convex run` with the deployment's key, never from the app or a browser.
import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
import { removePicture } from "./deletion";
import { resolveReportsFor } from "./hosting";
import { SUPPORT_RESPONSE_MS } from "./lib/config";

// Every report not yet resolved, oldest first, with whether it is past the response time.
export const openReports = internalQuery({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    const open = await ctx.db
      .query("reports")
      .withIndex("by_resolution", (q) => q.eq("resolvedAt", undefined))
      .collect();
    const rows = [];
    for (const report of open.sort((a, b) => a.at - b.at)) {
      const event = await ctx.db.get(report.eventId);
      const picture = await ctx.db.get(report.pictureId);
      const shooter = picture !== null ? await ctx.db.get(picture.membershipId) : null;
      rows.push({
        reportId: report._id,
        eventId: report.eventId,
        eventTitle: event?.title ?? "",
        hostLeft: event !== null && event.hostAccountId === undefined,
        pictureId: report.pictureId,
        pictureState: picture?.state ?? "removed",
        shooterName: shooter?.guestName ?? "",
        reason: report.reason,
        reportedAt: report.at,
        delivered: report.deliveredAt !== undefined,
        overdue: now - report.at > SUPPORT_RESPONSE_MS,
      });
    }
    return rows;
  },
});

// Support removes a picture for everyone, in any event (V2-FR-54), and closes its reports.
export const removePictureForSupport = internalMutation({
  args: { pictureId: v.id("pictures") },
  handler: async (ctx, { pictureId }) => {
    const picture = await ctx.db.get(pictureId);
    if (picture === null) return { removed: false };
    const now = Date.now();
    await removePicture(ctx, picture, now, "support");
    await resolveReportsFor(ctx, pictureId, now, "removed");
    return { removed: true };
  },
});

// Support closes the reports about a picture it keeps.
export const keepPicture = internalMutation({
  args: { pictureId: v.id("pictures") },
  handler: async (ctx, { pictureId }) => {
    await resolveReportsFor(ctx, pictureId, Date.now(), "kept");
    return { resolved: true };
  },
});
