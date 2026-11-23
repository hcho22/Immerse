"use node";
// "Your Film is ready" (V2-FR-70): the one push notification v2 sends, at the reveal, to every member with the full app
// who allowed notifications, the Host included, and no removed guest. It is sent from Convex through Apple's push
// service over HTTP/2 (section 9.6, lib/apns.ts), once per event: the event is marked sent before the send, so a step
// run twice sends nothing more. Tokens Apple rejects are deleted (section 8).
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalAction } from "./_generated/server";
import { apnsConfig, filmReadyPayload, isRejectedToken, sendAlerts, type ApnsConfig, type DeliveryResult } from "./lib/apns";

type AlertClaim = { title: string; tokens: Array<{ token: string; environment: "sandbox" | "production" }> } | null;

export const sendFilmReady = internalAction({
  args: { eventId: v.id("events") },
  handler: async (ctx, { eventId }): Promise<DeliveryResult[]> => {
    let config: ApnsConfig;
    try {
      config = apnsConfig();
    } catch (error) {
      // A deployment without Apple's key sends nothing; the reveal itself has happened.
      console.error(`Your Film is ready was not sent: ${String(error)}`);
      return [];
    }
    const claim: AlertClaim = await ctx.runMutation(internal.pushTokens.claimFilmReadyAlert, { eventId });
    if (claim === null) return [];
    const payload = filmReadyPayload(claim.title);
    const results: DeliveryResult[] = [];
    for (const environment of ["sandbox", "production"] as const) {
      const tokens = claim.tokens.filter((row) => row.environment === environment).map((row) => row.token);
      try {
        results.push(...(await sendAlerts(config, environment, tokens, payload)));
      } catch (error) {
        console.error(`Your Film is ready could not reach Apple's ${environment} service: ${String(error)}`);
      }
    }
    for (const result of results) {
      if (isRejectedToken(result)) await ctx.runMutation(internal.pushTokens.dropRejected, { token: result.token });
    }
    console.log(`Your Film is ready: ${results.length} sent, ${results.filter((r) => r.status === 200).length} accepted`);
    return results;
  },
});
