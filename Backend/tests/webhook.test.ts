// Clerk's `user.deleted` webhook (section 9.8): only a request signed with the endpoint's Svix secret is acted on,
// and it removes the person's records as Delete Account does.
import { createHmac, randomBytes } from "node:crypto";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { verifySvixSignature } from "../convex/http";
import { startClerkDouble } from "./support/clerk-double";
import { everyRow, newBackend, newEvent, newHost } from "./support/convex";

const secret = `whsec_${randomBytes(24).toString("base64")}`;

function signed(body: string, at = Math.floor(Date.now() / 1000), key = secret) {
  const id = `msg_${randomBytes(8).toString("hex")}`;
  const signature = createHmac("sha256", Buffer.from(key.slice("whsec_".length), "base64"))
    .update(`${id}.${at}.${body}`)
    .digest("base64");
  return { "svix-id": id, "svix-timestamp": String(at), "svix-signature": `v1,${signature}` };
}

let clerk: Awaited<ReturnType<typeof startClerkDouble>>;
beforeEach(async () => {
  clerk = await startClerkDouble();
  process.env.CLERK_WEBHOOK_SECRET = secret;
});
afterEach(async () => {
  await clerk.close();
});

describe("Svix signatures", () => {
  const body = JSON.stringify({ type: "user.deleted", data: { id: "user_x" } });
  const check = (headers: Record<string, string>, raw = body, now?: number) =>
    verifySvixSignature(
      secret,
      { id: headers["svix-id"]!, timestamp: headers["svix-timestamp"]!, signature: headers["svix-signature"]! },
      raw,
      now,
    );

  test("a correct signature verifies", async () => {
    expect(await check(signed(body))).toBe(true);
  });

  test("one correct signature among several verifies", async () => {
    const headers = signed(body);
    expect(await check({ ...headers, "svix-signature": `v1,bm90IGl0 ${headers["svix-signature"]}` })).toBe(true);
  });

  test("a changed body, another secret, or an old timestamp does not", async () => {
    expect(await check(signed(body), body.replace("user_x", "user_y"))).toBe(false);
    expect(await check(signed(body, undefined, `whsec_${randomBytes(24).toString("base64")}`))).toBe(false);
    const old = Math.floor(Date.now() / 1000) - 6 * 60;
    expect(await check(signed(body, old))).toBe(false);
    expect(await check({ ...signed(body), "svix-signature": "v2,abc" })).toBe(false);
  });
});

describe("the webhook endpoint", () => {
  test("a signed user.deleted removes the person's records, without asking Clerk again", async () => {
    const t = newBackend();
    const { accountId } = await newHost(t, "user_maya", "Maya");
    await newEvent(t, "user_maya");
    const body = JSON.stringify({ type: "user.deleted", object: "event", data: { id: "user_maya", object: "user", deleted: true } });
    const response = await t.fetch("/clerk/webhook", { method: "POST", headers: signed(body), body });
    expect(response.status).toBe(200);
    const rows = await everyRow(t);
    expect(JSON.stringify(rows).includes(accountId)).toBe(false);
    expect(rows.filter((r) => r.table === "clerkDeletions")).toHaveLength(0);
    expect(clerk.requests).toHaveLength(0);
    // Delivered again, as Svix retries, it changes nothing.
    expect((await t.fetch("/clerk/webhook", { method: "POST", headers: signed(body), body })).status).toBe(200);
    expect(await everyRow(t)).toEqual(rows);
  });

  test("an unsigned or wrongly signed request is refused and changes nothing", async () => {
    const t = newBackend();
    await newHost(t, "user_maya", "Maya");
    const before = await everyRow(t);
    const body = JSON.stringify({ type: "user.deleted", data: { id: "user_maya" } });
    expect((await t.fetch("/clerk/webhook", { method: "POST", body })).status).toBe(401);
    const forged = signed(body, undefined, `whsec_${randomBytes(24).toString("base64")}`);
    expect((await t.fetch("/clerk/webhook", { method: "POST", headers: forged, body })).status).toBe(401);
    expect(await everyRow(t)).toEqual(before);
  });

  test("other events are acknowledged and ignored", async () => {
    const t = newBackend();
    await newHost(t, "user_maya", "Maya");
    const before = await everyRow(t);
    const body = JSON.stringify({ type: "user.updated", data: { id: "user_maya" } });
    expect((await t.fetch("/clerk/webhook", { method: "POST", headers: signed(body), body })).status).toBe(200);
    expect(await everyRow(t)).toEqual(before);
  });
});
