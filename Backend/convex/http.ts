// Clerk's webhook (section 9.8): a Clerk user deleted anywhere, in Clerk's dashboard included, has their server
// records removed as Delete Account removes them. Clerk sends webhooks through Svix; a request whose signature does
// not verify against the endpoint's signing secret, or whose timestamp is more than five minutes off, is refused.
import { httpRouter } from "convex/server";
import { internal } from "./_generated/api";
import { httpAction } from "./_generated/server";
import { bytesToBase64, constantTimeEqual } from "./lib/crypto";

const TOLERANCE_SECONDS = 5 * 60;

export async function verifySvixSignature(
  secret: string,
  headers: { id: string | null; timestamp: string | null; signature: string | null },
  body: string,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<boolean> {
  const { id, timestamp, signature } = headers;
  if (!id || !timestamp || !signature || !secret.startsWith("whsec_")) return false;
  const sentAt = Number(timestamp);
  if (!Number.isFinite(sentAt) || Math.abs(nowSeconds - sentAt) > TOLERANCE_SECONDS) return false;
  const keyBytes = Uint8Array.from(atob(secret.slice("whsec_".length)), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const expected = bytesToBase64(
    new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${id}.${timestamp}.${body}`))),
  );
  // The header holds space-separated "v1,<signature>" entries; any one may match.
  return signature
    .split(" ")
    .map((entry) => entry.split(","))
    .some(([version, value]) => version === "v1" && value !== undefined && constantTimeEqual(value, expected));
}

const http = httpRouter();

http.route({
  path: "/clerk/webhook",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const secret = process.env.CLERK_WEBHOOK_SECRET;
    const body = await request.text();
    const verified =
      secret !== undefined &&
      (await verifySvixSignature(
        secret,
        {
          id: request.headers.get("svix-id"),
          timestamp: request.headers.get("svix-timestamp"),
          signature: request.headers.get("svix-signature"),
        },
        body,
      ));
    if (!verified) return new Response("Signature refused", { status: 401 });
    let event: { type?: string; data?: { id?: unknown } };
    try {
      event = JSON.parse(body);
    } catch {
      return new Response("Malformed body", { status: 400 });
    }
    if (event.type === "user.deleted" && typeof event.data?.id === "string") {
      await ctx.runAction(internal.deletion.userDeletedAtClerk, { clerkUserId: event.data.id });
    }
    // Other events need nothing; answering 200 stops Clerk retrying them.
    return new Response(null, { status: 200 });
  }),
});

export default http;
