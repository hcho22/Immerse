// The server's HTTP routes: Clerk's webhook, what the join page's Worker asks before it shows anything (web.ts), and
// Apple's App Store Server Notifications (Stage 4).
//
// Clerk's webhook (section 9.8): a Clerk user deleted anywhere, in Clerk's dashboard included, has their server
// records removed as Delete Account removes them. Clerk sends webhooks through Svix; a request whose signature does
// not verify against the endpoint's signing secret, or whose timestamp is more than five minutes off, is refused.
import { httpRouter } from "convex/server";
import { internal } from "./_generated/api";
import { httpAction } from "./_generated/server";
import { bytesToBase64, constantTimeEqual } from "./lib/crypto";
import { presignRead, READ_ADDRESS_SECONDS, storageConfig } from "./lib/storage";
import type { NotificationReply } from "./appStore";
import type { PictureGrant, WebPage } from "./web";

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

// The join page's Worker proves itself with the secret it shares with this deployment. Without the secret set, every
// request is refused: the web surfaces stay closed until the operator configures them (Backend/SETUP.md).
function fromTheWorker(request: Request): boolean {
  const secret = process.env.WEB_GATEWAY_SECRET;
  if (secret === undefined || secret.length < 32) return false;
  const sent = request.headers.get("authorization") ?? "";
  return constantTimeEqual(sent, `Bearer ${secret}`);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

async function fields(request: Request): Promise<Record<string, unknown> | null> {
  try {
    const body: unknown = await request.json();
    return typeof body === "object" && body !== null ? (body as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

// What a Join Code's link shows in a browser (V2-FR-18), with the album while the Host shares it on the web (V2-FR-47).
http.route({
  path: "/web/page",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    if (!fromTheWorker(request)) return json({ error: "refused" }, 401);
    const body = await fields(request);
    if (body === null || typeof body.code !== "string") return json({ error: "malformed" }, 400);
    const page: WebPage = await ctx.runQuery(internal.web.page, { code: body.code });
    return json(page);
  }),
});

// A one-minute read address for one picture of a shared web album, for the Worker to fetch and pass on. This and
// reads.ts are the only places a read address is made, and neither makes one before the reveal.
http.route({
  path: "/web/picture",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    if (!fromTheWorker(request)) return json({ error: "refused" }, 401);
    const body = await fields(request);
    if (body === null || typeof body.code !== "string" || typeof body.pictureId !== "string") {
      return json({ error: "malformed" }, 400);
    }
    const copy = body.copy === "full" ? "full" : "view";
    const grant: PictureGrant = await ctx.runQuery(internal.web.pictureGrant, {
      code: body.code,
      pictureId: body.pictureId,
      copy,
    });
    if (!grant.granted) return json({ granted: false }, 404);
    const address = await presignRead(storageConfig(), grant.storageKey);
    return json({
      granted: true,
      url: address.url,
      contentType: grant.contentType,
      size: grant.size,
      expiresInSeconds: READ_ADDRESS_SECONDS,
    });
  }),
});

// Apple's App Store Server Notifications, version 2 (V2-FR-65, section 9.7): purchases, refunds and refund reversals.
// The body is `{"signedPayload": "<JWS>"}`; only a payload Apple signed changes anything (appStore.ts). Anything but a
// 2xx answer makes Apple send it again, for up to a few days.
http.route({
  path: "/apple/notifications",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await fields(request);
    if (body === null || typeof body.signedPayload !== "string") return json({ error: "malformed" }, 400);
    try {
      const reply: NotificationReply = await ctx.runAction(internal.appStore.receiveNotification, {
        signedPayload: body.signedPayload,
      });
      return json({ handled: reply.handled }, reply.status);
    } catch (error) {
      console.error(`An App Store notification could not be applied now: ${(error as Error).message}`);
      return json({ error: "retry" }, 500);
    }
  }),
});

export default http;
