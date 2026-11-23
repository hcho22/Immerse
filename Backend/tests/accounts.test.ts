// Accounts and the age confirmation (V2-FR-01, V2-FR-03): every server operation that needs an Account refuses a
// request without a valid Clerk session, and no Account exists without the age 13-or-over confirmation.
import { describe, expect, test } from "vitest";
import { api } from "../convex/_generated/api";
import { newBackend, newEvent, newHost, refusalCode, signedIn } from "./support/convex";

describe("Accounts", () => {
  test("a signed-out person is told so, and a signed-in person with no Account is asked to make one", async () => {
    const t = newBackend();
    expect(await t.query(api.accounts.me, {})).toEqual({ state: "signedOut" });
    expect(await signedIn(t, "user_new").query(api.accounts.me, {})).toEqual({ state: "noAccount" });
  });

  test("an Account is made only with the age confirmation, and records when it was given", async () => {
    const t = newBackend();
    const person = signedIn(t, "user_new");
    // The confirmation must be the literal `true`: anything else fails validation before the function runs.
    await expect(
      person.mutation(api.accounts.createAccount, {
        displayName: "Maya",
        ageConfirmed: false as never,
        ageConfirmation: "birthMonthAndYear",
      }),
    ).rejects.toThrow();
    await expect(
      person.mutation(api.accounts.createAccount, { displayName: "Maya", ageConfirmation: "birthMonthAndYear" } as never),
    ).rejects.toThrow();
    expect(await t.run((ctx) => ctx.db.query("accounts").collect())).toHaveLength(0);
    const before = Date.now();
    expect(
      await person.mutation(api.accounts.createAccount, {
        displayName: "  Maya  ",
        ageConfirmed: true,
        ageConfirmation: "declaredAgeRange",
      }),
    ).toEqual({ created: true });
    const me = await person.query(api.accounts.me, {});
    expect(me.state).toBe("signedIn");
    if (me.state !== "signedIn") return;
    expect(me.account.displayName).toBe("Maya");
    expect(me.account.ageConfirmedAt).toBeGreaterThanOrEqual(before);
    const [account] = await t.run((ctx) => ctx.db.query("accounts").collect());
    expect(account?.ageConfirmation).toBe("declaredAgeRange");
    // No age or birth date is ever held, only the confirmation.
    expect(Object.keys(account!)).not.toContain("birthYear");
  });

  test("making an Account again changes nothing", async () => {
    const t = newBackend();
    const { host } = await newHost(t, "user_host");
    const [first] = await t.run((ctx) => ctx.db.query("accounts").collect());
    expect(
      await host.mutation(api.accounts.createAccount, {
        displayName: "Someone else",
        ageConfirmed: true,
        ageConfirmation: "declaredAgeRange",
      }),
    ).toEqual({ created: false });
    const rows = await t.run((ctx) => ctx.db.query("accounts").collect());
    expect(rows).toEqual([first]);
  });

  test("a display name is 1 to 40 characters", async () => {
    const t = newBackend();
    const person = signedIn(t, "user_new");
    for (const displayName of ["", "   ", "x".repeat(41)]) {
      expect(
        await refusalCode(
          person.mutation(api.accounts.createAccount, { displayName, ageConfirmed: true, ageConfirmation: "birthMonthAndYear" }),
        ),
      ).toBe("invalid");
    }
    const { host } = await newHost(t, "user_host");
    expect(await host.mutation(api.accounts.setDisplayName, { displayName: "Maya R" })).toEqual({ displayName: "Maya R" });
    expect(await host.mutation(api.accounts.setDisplayName, { displayName: "Maya R" })).toEqual({ displayName: "Maya R" });
    expect(await refusalCode(host.mutation(api.accounts.setDisplayName, { displayName: "" }))).toBe("invalid");
  });

  test("every operation that needs an Account refuses a request without a Clerk session", async () => {
    const t = newBackend();
    await newHost(t, "user_host");
    const eventId = await newEvent(t, "user_host");
    const refusals = await Promise.all([
      refusalCode(t.mutation(api.accounts.createAccount, { displayName: "X", ageConfirmed: true, ageConfirmation: "birthMonthAndYear" })),
      refusalCode(t.mutation(api.accounts.setDisplayName, { displayName: "X" })),
      refusalCode(t.action(api.deletion.deleteAccount, {})),
      refusalCode(t.mutation(api.pushTokens.register, { installationId: "a".repeat(22), token: "ab".repeat(32), environment: "sandbox" })),
      refusalCode(t.mutation(api.pushTokens.unregister, { installationId: "a".repeat(22) })),
      refusalCode(
        t.action(api.pictures.requestUpload, {
          eventId,
          exposureNumber: 1,
          captureTime: Date.now(),
          contentType: "image/jpeg",
          size: 10,
          sha256: "A".repeat(43) + "=",
        }),
      ),
      refusalCode(t.action(api.pictures.confirmUpload, { eventId, exposureNumber: 1 })),
      refusalCode(t.action(api.reads.readAddresses, { eventId })),
    ]);
    expect(refusals).toEqual(Array(refusals.length).fill("unauthenticated"));
  });

  test("a Clerk session with no Account cannot act as one", async () => {
    const t = newBackend();
    await newHost(t, "user_host");
    const eventId = await newEvent(t, "user_host");
    const person = signedIn(t, "user_new");
    expect(await refusalCode(person.mutation(api.accounts.setDisplayName, { displayName: "X" }))).toBe("noAccount");
    expect(await refusalCode(person.action(api.reads.readAddresses, { eventId }))).toBe("noAccount");
  });
});
