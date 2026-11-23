// The server's own aggregate counts for v2's success measures (PRD section 13), with nothing that names a person:
// how late each reveal ran (M-3), and an event's pictures and stored bytes (M-1, M-8 and open check OC-2). Internal
// functions, read from the Convex dashboard or `npx convex run` with the deployment's key.
import { v } from "convex/values";
import { internalQuery } from "./_generated/server";

// One event's counts: when its reveal was due and when it ran, its Rolls, its pictures by state, and the bytes its
// stored pictures and viewing copies hold in R2.
export const eventMeasures = internalQuery({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }) => {
    const event = await ctx.db.get(eventId);
    if (event === null) return null;
    const pictures = await ctx.db
      .query("pictures")
      .withIndex("by_event", (q) => q.eq("eventId", eventId))
      .collect();
    const stored = pictures.filter((picture) => picture.state === "stored");
    return {
      revealsAt: event.revealsAt,
      revealedAt: event.revealedAt ?? null,
      revealLateByMs: event.revealedAt !== undefined ? event.revealedAt - event.revealsAt : null,
      rollsSetAside: event.rollsSetAside,
      rollsTaken: event.rollsTaken,
      pictures: {
        stored: stored.length,
        uploading: pictures.filter((picture) => picture.state === "uploading").length,
        removed: pictures.filter((picture) => picture.state === "removed").length,
      },
      storedBytes: stored.reduce((total, picture) => total + (picture.size ?? 0), 0),
      storedViewBytes: stored.reduce((total, picture) => total + (picture.viewSize ?? 0), 0),
    };
  },
});

// The reveals that ran more than a minute after their time (M-3's misses), newest first.
export const lateReveals = internalQuery({
  args: { since: v.number() },
  handler: async (ctx, { since }) => {
    const revealed = await ctx.db.query("events").collect();
    return revealed
      .filter((event) => event.revealedAt !== undefined && event.revealsAt >= since && event.revealedAt - event.revealsAt > 60_000)
      .map((event) => ({ eventId: event._id, revealsAt: event.revealsAt, lateByMs: event.revealedAt! - event.revealsAt }))
      .sort((a, b) => b.revealsAt - a.revealsAt);
  },
});
