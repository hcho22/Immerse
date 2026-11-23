// The Host's balance of Rolls and its ledger (V2-FR-28, V2-FR-61, V2-FR-62, section 8). Stage 2 has free Rolls only:
// everyone's once-ever free amount, set aside for events and returned at their End Time. Purchases, refunds and the
// subscriber's larger free amount are Stage 4's; the ledger already has their kinds.
import type { Doc, Id } from "./_generated/dataModel";
import { query, type MutationCtx, type QueryCtx } from "./_generated/server";
import { requireAccount } from "./lib/callers";
import { freeRollsForEveryone } from "./lib/config";

export async function ledgerOf(ctx: QueryCtx, accountId: Id<"accounts">) {
  return ctx.db
    .query("rollLedger")
    .withIndex("by_account", (q) => q.eq("accountId", accountId))
    .collect();
}

// Credits carry a positive count and set-asides and refunds a negative one, so the balance is their sum; a refund after
// the Rolls were used can take it below zero (V2-FR-65).
export function balanceOfRows(rows: Doc<"rollLedger">[]): number {
  return rows.reduce((total, row) => total + row.rolls, 0);
}

function hasEveryonesFreeRolls(rows: Doc<"rollLedger">[]): boolean {
  return rows.some((row) => row.kind === "free" && row.freeGrant !== "subscriber");
}

// Credits everyone's free Rolls to an Account once ever (V2-FR-62): at Account creation, and before any set-aside for
// an Account made before free Rolls were credited. Repeating it credits nothing more.
export async function ensureFreeRolls(ctx: MutationCtx, accountId: Id<"accounts">, now: number) {
  if (hasEveryonesFreeRolls(await ledgerOf(ctx, accountId))) return;
  const rolls = freeRollsForEveryone();
  await ctx.db.insert("rollLedger", { accountId, kind: "free", freeGrant: "everyone", rolls, at: now });
}

export async function balanceOf(ctx: QueryCtx, accountId: Id<"accounts">): Promise<number> {
  return balanceOfRows(await ledgerOf(ctx, accountId));
}

// Sets Rolls aside from the balance for an event (V2-FR-28, V2-FR-61).
export async function setAside(
  ctx: MutationCtx,
  accountId: Id<"accounts">,
  eventId: Id<"events">,
  rolls: number,
  now: number,
  requestId?: string,
) {
  await ctx.db.insert("rollLedger", { accountId, kind: "setAside", rolls: -rolls, eventId, requestId, at: now });
}

// At the End Time, or when the Host deletes the event before it, every Roll no guest took returns to the Host's
// balance (V2-FR-28); in a deleted Host's event they have no balance to return to and lapse (V2-FR-06). Repeating it
// returns nothing more.
export async function settleUnclaimedRolls(ctx: MutationCtx, event: Doc<"events">, now: number) {
  if (event.rollsSettledAt !== undefined) return;
  const unclaimed = Math.max(0, event.rollsSetAside - event.rollsTaken);
  if (event.hostAccountId !== undefined && unclaimed > 0) {
    await ctx.db.insert("rollLedger", {
      accountId: event.hostAccountId,
      kind: "return",
      rolls: unclaimed,
      eventId: event._id,
      at: now,
    });
  }
  await ctx.db.patch(event._id, { rollsSettledAt: now });
}

// The signed-in Host's balance, with everyone's free Rolls counted before they are first credited.
export const balance = query({
  args: {},
  handler: async (ctx) => {
    const account = await requireAccount(ctx);
    const rows = await ledgerOf(ctx, account._id);
    const pendingFree = hasEveryonesFreeRolls(rows) ? 0 : freeRollsForEveryone();
    return { rolls: balanceOfRows(rows) + pendingFree };
  },
});

// The balance history (V2-FR-28): each set-aside, return, purchase and credit, newest first.
export const history = query({
  args: {},
  handler: async (ctx) => {
    const account = await requireAccount(ctx);
    const rows = await ledgerOf(ctx, account._id);
    const titles = new Map<string, string>();
    for (const row of rows) {
      if (row.eventId !== undefined && !titles.has(row.eventId)) {
        titles.set(row.eventId, (await ctx.db.get(row.eventId))?.title ?? "");
      }
    }
    return rows
      .sort((a, b) => b.at - a.at)
      .map((row) => ({
        kind: row.kind,
        rolls: row.rolls,
        at: row.at,
        eventTitle: row.eventId !== undefined ? titles.get(row.eventId) || undefined : undefined,
      }));
  },
});
