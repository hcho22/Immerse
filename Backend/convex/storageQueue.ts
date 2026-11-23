// Deletes queued R2 objects (deletion.ts queues them after writing each removal's marker). A failure stays queued
// and is retried with a growing delay, so no removed picture's media is forgotten in storage.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalAction, internalMutation, internalQuery } from "./_generated/server";
import { deleteObject, storageConfig } from "./lib/storage";

const DRAIN_BATCH = 50;

export const queued = internalQuery({
  args: {},
  handler: (ctx) => ctx.db.query("storageDeletions").take(DRAIN_BATCH),
});

export const settle = internalMutation({
  args: { deleted: v.array(v.id("storageDeletions")), failed: v.array(v.id("storageDeletions")) },
  handler: async (ctx, { deleted, failed }) => {
    for (const id of deleted) {
      if ((await ctx.db.get(id)) !== null) await ctx.db.delete(id);
    }
    let longestAttempts = 0;
    for (const id of failed) {
      const row = await ctx.db.get(id);
      if (row === null) continue;
      await ctx.db.patch(id, { attempts: row.attempts + 1 });
      longestAttempts = Math.max(longestAttempts, row.attempts + 1);
    }
    if (failed.length > 0) {
      const delay = Math.min(60_000 * 2 ** (longestAttempts - 1), 6 * 3_600_000);
      await ctx.scheduler.runAfter(delay, internal.storageQueue.drain, {});
    }
  },
});

export const drain = internalAction({
  args: {},
  handler: async (ctx) => {
    const rows = await ctx.runQuery(internal.storageQueue.queued, {});
    if (rows.length === 0) return;
    const config = storageConfig();
    const deleted = [];
    const failed = [];
    for (const row of rows) {
      try {
        await deleteObject(config, row.storageKey);
        deleted.push(row._id);
      } catch (error) {
        console.error(`Storage deletion failed: ${String(error)}`);
        failed.push(row._id);
      }
    }
    await ctx.runMutation(internal.storageQueue.settle, { deleted, failed });
    if (rows.length === DRAIN_BATCH && failed.length === 0) await ctx.scheduler.runAfter(0, internal.storageQueue.drain, {});
  },
});
