// The Convex-to-Apple push test (open check OC-7), against an HTTP/2 stand-in for Apple's service: the Node action
// sends the alert over HTTP/2 with an ES256 provider token, and tokens Apple rejects are deleted.
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { api, internal } from "../convex/_generated/api";
import { startApnsDouble } from "./support/apns-double";
import { newBackend, newHost, randomId, refusalCode } from "./support/convex";

let apns: Awaited<ReturnType<typeof startApnsDouble>>;
beforeEach(async () => {
  apns = await startApnsDouble();
});
afterEach(async () => {
  await apns.close();
});

const tokenA = "a1".repeat(32);
const tokenB = "b2".repeat(32);

describe("push from Convex to Apple's service", () => {
  test("an Account's registered iPhone gets the alert, over HTTP/2, with a valid provider token", async () => {
    const t = newBackend();
    const { host, accountId } = await newHost(t, "user_host");
    await host.mutation(api.pushTokens.register, { installationId: randomId(), token: tokenA, environment: "sandbox" });
    const results = await t.action(internal.push.sendTestAlert, { accountId });
    expect(results).toMatchObject([{ token: tokenA, status: 200 }]);
    expect(apns.requests).toHaveLength(1);
    const [request] = apns.requests;
    expect(request!.httpVersion).toBe("2.0");
    expect(request!.method).toBe("POST");
    expect(request!.path).toBe(`/3/device/${tokenA}`);
    expect(request!.headers["apns-topic"]).toBe("com.immerse.FilmJournal");
    expect(request!.headers["apns-push-type"]).toBe("alert");
    expect(request!.headers["apns-priority"]).toBe("10");
    expect(JSON.parse(request!.body)).toEqual({
      aps: { alert: { title: "Push test", body: "Your Film is ready" }, sound: "default" },
    });
    const authorization = String(request!.headers.authorization);
    expect(authorization.startsWith("bearer ")).toBe(true);
    const providerToken = apns.verifyProviderToken(authorization.slice("bearer ".length));
    expect(providerToken.valid).toBe(true);
    expect(providerToken.header).toEqual({ alg: "ES256", kid: "ABC123DEFG" });
    expect(providerToken.claims.iss).toBe("TEAM123456");
    expect(Math.abs(providerToken.claims.iat - Date.now() / 1000)).toBeLessThan(60 * 41);
  });

  test("a token Apple says is gone is deleted, and one it accepts is kept", async () => {
    const t = newBackend();
    const { host, accountId } = await newHost(t, "user_host");
    await host.mutation(api.pushTokens.register, { installationId: randomId(), token: tokenA, environment: "production" });
    await host.mutation(api.pushTokens.register, { installationId: randomId(), token: tokenB, environment: "production" });
    apns.answer(tokenA, 410, "Unregistered");
    const results = await t.action(internal.push.sendTestAlert, { accountId, filmTitle: "Ana & Leo" });
    expect(results.map((r) => [r.token, r.status])).toEqual([
      [tokenA, 410],
      [tokenB, 200],
    ]);
    expect(JSON.parse(apns.requests[0]!.body).aps.alert.title).toBe("Ana & Leo");
    // Signed with this test's key, not a token cached from an earlier key.
    expect(apns.verifyProviderToken(String(apns.requests[0]!.headers.authorization).slice("bearer ".length)).valid).toBe(true);
    const left = await t.run((ctx) => ctx.db.query("pushTokens").collect());
    expect(left.map((row) => row.token)).toEqual([tokenB]);
  });

  test("a token for the wrong environment is deleted; other failures keep it", async () => {
    const t = newBackend();
    const { host, accountId } = await newHost(t, "user_host");
    await host.mutation(api.pushTokens.register, { installationId: randomId(), token: tokenA, environment: "sandbox" });
    await host.mutation(api.pushTokens.register, { installationId: randomId(), token: tokenB, environment: "sandbox" });
    apns.answer(tokenA, 400, "BadDeviceToken");
    apns.answer(tokenB, 429, "TooManyRequests");
    await t.action(internal.push.sendTestAlert, { accountId });
    const left = await t.run((ctx) => ctx.db.query("pushTokens").collect());
    expect(left.map((row) => row.token)).toEqual([tokenB]);
  });

  test("an Account with no registered iPhone sends nothing", async () => {
    const t = newBackend();
    const { accountId } = await newHost(t, "user_host");
    expect(await t.action(internal.push.sendTestAlert, { accountId })).toEqual([]);
    expect(apns.requests).toHaveLength(0);
  });
});

describe("push tokens", () => {
  test("an installation holds one token, a reinstall's token moves to the new installation, and sign-out drops it", async () => {
    const t = newBackend();
    const { host } = await newHost(t, "user_host");
    const installation = randomId();
    await host.mutation(api.pushTokens.register, { installationId: installation, token: tokenA, environment: "sandbox" });
    await host.mutation(api.pushTokens.register, { installationId: installation, token: tokenA, environment: "sandbox" });
    await host.mutation(api.pushTokens.register, { installationId: installation, token: tokenB, environment: "sandbox" });
    expect((await t.run((ctx) => ctx.db.query("pushTokens").collect())).map((r) => r.token)).toEqual([tokenB]);
    const reinstall = randomId();
    await host.mutation(api.pushTokens.register, { installationId: reinstall, token: tokenB, environment: "sandbox" });
    expect((await t.run((ctx) => ctx.db.query("pushTokens").collect())).map((r) => r.installationId)).toEqual([reinstall]);
    await host.mutation(api.pushTokens.unregister, { installationId: reinstall });
    await host.mutation(api.pushTokens.unregister, { installationId: reinstall });
    expect(await t.run((ctx) => ctx.db.query("pushTokens").collect())).toHaveLength(0);
  });

  test("malformed tokens are refused, and one Account cannot drop another's token", async () => {
    const t = newBackend();
    const { host } = await newHost(t, "user_host");
    const { host: other } = await newHost(t, "user_other", "Other");
    expect(await refusalCode(host.mutation(api.pushTokens.register, { installationId: "short", token: tokenA, environment: "sandbox" }))).toBe("invalid");
    expect(await refusalCode(host.mutation(api.pushTokens.register, { installationId: randomId(), token: "XYZ", environment: "sandbox" }))).toBe("invalid");
    const installation = randomId();
    await host.mutation(api.pushTokens.register, { installationId: installation, token: tokenA, environment: "sandbox" });
    await other.mutation(api.pushTokens.unregister, { installationId: installation });
    expect(await t.run((ctx) => ctx.db.query("pushTokens").collect())).toHaveLength(1);
  });
});
