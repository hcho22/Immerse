"use node";
// The Convex-to-Apple push test of Stage 1 (open check OC-7). It sends the real alert's shape, "Your Film is ready"
// under a test title, to every installation an Account registered, and deletes tokens Apple rejects. It is an
// internal function: run it from the Convex dashboard or `npx convex run`, never from the app, since v2 has no
// push but the reveal's (V2-FR-70). Stage 2's reveal sends through the same `sendAlerts`.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Doc } from "./_generated/dataModel";
import { internalAction } from "./_generated/server";
import { apnsConfig, filmReadyPayload, isRejectedToken, sendAlerts, type DeliveryResult } from "./lib/apns";

export const sendTestAlert = internalAction({
  args: { accountId: v.id("accounts"), filmTitle: v.optional(v.string()) },
  handler: async (ctx, { accountId, filmTitle }): Promise<DeliveryResult[]> => {
    const rows: Doc<"pushTokens">[] = await ctx.runQuery(internal.pushTokens.tokensForAccount, { accountId });
    const config = apnsConfig();
    const payload = filmReadyPayload(filmTitle ?? "Push test");
    const results: DeliveryResult[] = [];
    for (const environment of ["sandbox", "production"] as const) {
      const tokens = rows.filter((row) => row.environment === environment).map((row) => row.token);
      results.push(...(await sendAlerts(config, environment, tokens, payload)));
    }
    for (const result of results) {
      if (isRejectedToken(result)) await ctx.runMutation(internal.pushTokens.dropRejected, { token: result.token });
    }
    // Device tokens are not logged in full.
    console.log(
      `Push test: ${results.map((r) => `${r.token.slice(0, 8)}… ${r.status}${r.reason ? ` ${r.reason}` : ""}`).join(", ") || "no tokens"}`,
    );
    return results;
  },
});
