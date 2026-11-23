// A fresh in-memory Convex backend per test (convex-test), with helpers for the people and places the tests need.
import { convexTest } from "convex-test";
import { randomBytes } from "node:crypto";
import { api, internal } from "../../convex/_generated/api";
import type { Id } from "../../convex/_generated/dataModel";
import schema from "../../convex/schema";
import { sha256Base64 } from "../../convex/lib/crypto";

export const modules = import.meta.glob("../../convex/**/*.*s");

export const ISSUER = "https://clerk.immerse.test";

export function newBackend() {
  return convexTest(schema, modules);
}

export type Backend = ReturnType<typeof newBackend>;

// A Clerk session as Convex sees it once verified.
export function signedIn(t: Backend, clerkUserId: string) {
  return t.withIdentity({ subject: clerkUserId, issuer: ISSUER, tokenIdentifier: `${ISSUER}|${clerkUserId}` });
}

export async function newHost(t: Backend, clerkUserId: string, displayName = "Maya") {
  const host = signedIn(t, clerkUserId);
  await host.mutation(api.accounts.createAccount, {
    displayName,
    ageConfirmed: true,
    ageConfirmation: "birthMonthAndYear",
  });
  const accountId = await t.run(async (ctx) => {
    const account = await ctx.db
      .query("accounts")
      .withIndex("by_clerk_user", (q) => q.eq("clerkUserId", clerkUserId))
      .unique();
    return account!._id;
  });
  return { host, accountId };
}

export async function newEvent(t: Backend, clerkUserId: string): Promise<Id<"events">> {
  const { eventId } = await t.mutation(internal.proofs.createProofEvent, { clerkUserId });
  return eventId;
}

export function randomId(bytes = 18) {
  return randomBytes(bytes).toString("base64url");
}

export type Guest = { publicId: string; secret: string; token: string };

// A guest with no Account holding a Roll in the event, with a current token.
export async function newGuest(t: Backend, eventId: Id<"events">, guestName = "Jo"): Promise<Guest> {
  const publicId = randomId();
  const secret = randomId(32);
  await t.mutation(internal.proofs.addProofGuest, { eventId, publicId, secret, guestName });
  const { token } = await t.mutation(api.guests.startSession, { publicId, secret, eventId });
  return { publicId, secret, token };
}

// A picture-sized file of random bytes.
export async function pictureFile(size = 4 * 1024 * 1024) {
  const bytes = new Uint8Array(randomBytes(size));
  return { bytes, size, sha256: await sha256Base64(bytes), contentType: "image/jpeg" };
}

// The upload address's request, sent as the app sends it with URLSession.
export function put(address: { url: string; headers: Record<string, string> }, body: Uint8Array, headers?: Record<string, string>) {
  return fetch(address.url, { method: "PUT", headers: headers ?? address.headers, body: body as Uint8Array<ArrayBuffer> });
}

// Runs every queued storage deletion now.
export async function drainStorageDeletions(t: Backend) {
  await t.action(internal.storageQueue.drain, {});
}

// Reads every row of every table, for checks that nothing names a deleted person.
export async function everyRow(t: Backend) {
  return t.run(async (ctx) => {
    const tables = Object.keys(schema.tables) as Array<keyof typeof schema.tables>;
    const rows: Array<{ table: string; row: Record<string, unknown> }> = [];
    for (const table of tables) {
      for (const row of await ctx.db.query(table).collect()) rows.push({ table, row: row as Record<string, unknown> });
    }
    return rows;
  });
}

export async function refusalCode(promise: Promise<unknown>): Promise<string | undefined> {
  try {
    await promise;
  } catch (error) {
    const data = (error as { data?: { code?: string } }).data;
    if (data?.code) return data.code;
    throw error;
  }
  return undefined;
}
