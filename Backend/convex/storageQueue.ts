// Deletes queued R2 objects (deletion.ts queues them after writing each removal's marker). A failure stays queued
// and is retried with a growing delay, so no removed picture's media is forgotten in storage.
//
// Each drain claims the rows it deletes, so drains running at once never take the same row, a row counts one
// attempt per try, and rows still backing off after a failure never stand in front of newer ones.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalAction, internalMutation } from "./_generated/server";
import { deleteObject, storageConfig } from "./lib/storage";

const DRAIN_BATCH = 50;
// How long a drain holds the rows it claimed: longer than an action may run, so a held row is never taken twice.
// Should the drain stop without settling, the rows wait this long and are drained again.
const CLAIM_MS = 15 * 60_000;

function retryDelay(attempts: number) {
  return Math.min(60_000 * 2 ** (attempts - 1), 6 * 3_600_000);
}

export const claim = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    const rows = await ctx.db
      .query("storageDeletions")
      .withIndex("by_next_attempt", (q) => q.lte("nextAttemptAt", now))
      .take(DRAIN_BATCH);
    if (rows.length === 0) return [];
    for (const row of rows) await ctx.db.patch(row._id, { nextAttemptAt: now + CLAIM_MS });
    await ctx.scheduler.runAfter(CLAIM_MS, internal.storageQueue.drain, {});
    if (rows.length === DRAIN_BATCH) await ctx.scheduler.runAfter(0, internal.storageQueue.drain, {});
    return rows.map((row) => ({ id: row._id, storageKey: row.storageKey }));
  },
});

export const settle = internalMutation({
  args: { deleted: v.array(v.id("storageDeletions")), failed: v.array(v.id("storageDeletions")) },
  handler: async (ctx, { deleted, failed }) => {
    for (const id of deleted) {
      if ((await ctx.db.get(id)) !== null) await ctx.db.delete(id);
    }
    const now = Date.now();
    const retries = new Set<number>();
    for (const id of failed) {
      const row = await ctx.db.get(id);
      if (row === null) continue;
      const attempts = row.attempts + 1;
      const nextAttemptAt = now + retryDelay(attempts);
      await ctx.db.patch(id, { attempts, nextAttemptAt });
      retries.add(nextAttemptAt);
    }
    for (const at of retries) await ctx.scheduler.runAt(at, internal.storageQueue.drain, {});
  },
});

export const drain = internalAction({
  args: {},
  handler: async (ctx) => {
    const rows = await ctx.runMutation(internal.storageQueue.claim, {});
    if (rows.length === 0) return;
    const config = storageConfig();
    const deleted = [];
    const failed = [];
    for (const row of rows) {
      try {
        await deleteObject(config, row.storageKey);
        deleted.push(row.id);
      } catch (error) {
        console.error(`Storage deletion failed: ${String(error)}`);
        failed.push(row.id);
      }
    }
    await ctx.runMutation(internal.storageQueue.settle, { deleted, failed });
  },
});
