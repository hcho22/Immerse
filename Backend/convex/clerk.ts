// The Clerk boundary on the server: deleting a Clerk user through Clerk's Backend API after Delete Account.
//
// The server deletes the user itself, with the instance's secret key, rather than leaving it to the app's
// `user.delete()`: deletion then finishes even if the app is closed halfway, and repeats safely. Clerk answers a
// user that no longer exists with 404, which counts as done.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalAction, internalMutation, internalQuery } from "./_generated/server";

const RETRY_DELAYS_MS = [60_000, 5 * 60_000, 30 * 60_000, 2 * 3_600_000, 12 * 3_600_000];

function clerkApiBase(): string {
  return (process.env.CLERK_API_URL || "https://api.clerk.com").replace(/\/+$/, "");
}

export const pendingDeletion = internalQuery({
  args: { clerkUserId: v.string() },
  handler: (ctx, { clerkUserId }) =>
    ctx.db
      .query("clerkDeletions")
      .withIndex("by_clerk_user", (q) => q.eq("clerkUserId", clerkUserId))
      .unique(),
});

export const forgetDeletion = internalMutation({
  args: { clerkUserId: v.string() },
  handler: async (ctx, { clerkUserId }) => {
    const pending = await ctx.db
      .query("clerkDeletions")
      .withIndex("by_clerk_user", (q) => q.eq("clerkUserId", clerkUserId))
      .unique();
    if (pending !== null) await ctx.db.delete(pending._id);
  },
});

export const recordFailedAttempt = internalMutation({
  args: { clerkUserId: v.string() },
  handler: async (ctx, { clerkUserId }) => {
    const pending = await ctx.db
      .query("clerkDeletions")
      .withIndex("by_clerk_user", (q) => q.eq("clerkUserId", clerkUserId))
      .unique();
    if (pending === null) return;
    const attempts = pending.attempts + 1;
    await ctx.db.patch(pending._id, { attempts });
    // After the last scheduled retry the row stays, so the Clerk user still cannot make a new Account, and the
    // next Delete Account or `user.deleted` webhook finishes it.
    const delay = RETRY_DELAYS_MS[attempts - 1];
    if (delay !== undefined) await ctx.scheduler.runAfter(delay, internal.clerk.deleteUser, { clerkUserId });
  },
});

// Deletes the Clerk user named in a pending deletion. Returns whether Clerk no longer has the user.
export const deleteUser = internalAction({
  args: { clerkUserId: v.string() },
  handler: async (ctx, { clerkUserId }): Promise<{ deleted: boolean }> => {
    const pending = await ctx.runQuery(internal.clerk.pendingDeletion, { clerkUserId });
    if (pending === null) return { deleted: true };
    const secretKey = process.env.CLERK_SECRET_KEY;
    let deleted = false;
    if (secretKey) {
      try {
        const response = await fetch(`${clerkApiBase()}/v1/users/${encodeURIComponent(clerkUserId)}`, {
          method: "DELETE",
          headers: { authorization: `Bearer ${secretKey}` },
        });
        deleted = response.ok || response.status === 404;
        if (!deleted) console.error(`Clerk user deletion failed with HTTP ${response.status}`);
      } catch (error) {
        console.error(`Clerk user deletion failed: ${String(error)}`);
      }
    } else {
      console.error("Clerk user deletion skipped: CLERK_SECRET_KEY is not set");
    }
    if (deleted) await ctx.runMutation(internal.clerk.forgetDeletion, { clerkUserId });
    else await ctx.runMutation(internal.clerk.recordFailedAttempt, { clerkUserId });
    return { deleted };
  },
});
