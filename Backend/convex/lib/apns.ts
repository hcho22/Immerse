"use node";
// Apple's push notification service, with token-based authentication over HTTP/2 (section 9.6, open check OC-7).
//
// Apple's service accepts only HTTP/2. `fetch` in Convex's default runtime offers no way to require it, so the
// sender runs in Convex's Node runtime ("use node" in push.ts), whose `node:http2` speaks it directly; no relay is
// needed unless the real check shows otherwise. Only Node modules are used here, so this file is imported only from
// Node actions and tests.
import { sign } from "node:crypto";
import http2 from "node:http2";

export type ApnsConfig = {
  keyId: string;
  teamId: string;
  // The .p8 signing key's PEM text.
  privateKey: string;
  // The app's bundle identifier.
  topic: string;
  // Overrides Apple's addresses for a local stand-in, with the certificate authority it trusts.
  origin?: string;
  ca?: string;
};

export const APNS_ORIGINS = {
  production: "https://api.push.apple.com",
  sandbox: "https://api.sandbox.push.apple.com",
} as const;

export function apnsConfig(): ApnsConfig {
  const read = (name: string) => {
    const value = process.env[name];
    if (value === undefined || value === "") throw new Error(`Push is not configured: ${name} is not set`);
    return value;
  };
  return {
    keyId: read("APNS_KEY_ID"),
    teamId: read("APNS_TEAM_ID"),
    privateKey: read("APNS_PRIVATE_KEY").replace(/\\n/g, "\n"),
    topic: read("APNS_TOPIC"),
    origin: process.env.APNS_ORIGIN || undefined,
    ca: process.env.APNS_CA_PEM?.replace(/\\n/g, "\n") || undefined,
  };
}

function base64Url(data: Buffer | string): string {
  return Buffer.from(data).toString("base64url");
}

// Apple refuses a provider token refreshed more often than every 20 minutes and one older than an hour, so a warm
// action reuses its token for 40 minutes.
const TOKEN_REUSE_SECONDS = 40 * 60;
let cachedToken: { keyId: string; teamId: string; privateKey: string; issuedAt: number; token: string } | null = null;

export function providerToken(config: ApnsConfig, nowSeconds = Math.floor(Date.now() / 1000)): string {
  if (
    cachedToken !== null &&
    cachedToken.keyId === config.keyId &&
    cachedToken.teamId === config.teamId &&
    cachedToken.privateKey === config.privateKey &&
    nowSeconds - cachedToken.issuedAt < TOKEN_REUSE_SECONDS
  ) {
    return cachedToken.token;
  }
  const header = base64Url(JSON.stringify({ alg: "ES256", kid: config.keyId }));
  const claims = base64Url(JSON.stringify({ iss: config.teamId, iat: nowSeconds }));
  const signature = sign("sha256", Buffer.from(`${header}.${claims}`), {
    key: config.privateKey,
    dsaEncoding: "ieee-p1363",
  });
  const token = `${header}.${claims}.${base64Url(signature)}`;
  cachedToken = { keyId: config.keyId, teamId: config.teamId, privateKey: config.privateKey, issuedAt: nowSeconds, token };
  return token;
}

// The one alert v2 sends: the Film Title and "Your Film is ready", as text only (V2-FR-70). The event's id rides along,
// unseen, so a tap opens that event once the app has checked the person may still see it.
export function filmReadyPayload(filmTitle: string, eventId?: string) {
  const payload = { aps: { alert: { title: filmTitle, body: "Your Film is ready" }, sound: "default" } };
  return eventId === undefined ? payload : { ...payload, eventId };
}

export type DeliveryResult = { token: string; status: number; reason?: string; apnsId?: string };

// Apple's answers that mean a token will never work again, so it is deleted: 410 Unregistered, and 400
// BadDeviceToken (a token for the other environment or malformed).
export function isRejectedToken(result: DeliveryResult): boolean {
  return result.status === 410 || (result.status === 400 && result.reason === "BadDeviceToken");
}

// Sends one payload to each token over one HTTP/2 connection to the environment's address.
export async function sendAlerts(
  config: ApnsConfig,
  environment: keyof typeof APNS_ORIGINS,
  tokens: string[],
  payload: object,
): Promise<DeliveryResult[]> {
  if (tokens.length === 0) return [];
  const origin = config.origin ?? APNS_ORIGINS[environment];
  const session = http2.connect(origin, config.ca ? { ca: config.ca } : {});
  const connected = new Promise<void>((resolve, reject) => {
    session.once("connect", () => resolve());
    session.once("error", reject);
  });
  try {
    await connected;
    const body = JSON.stringify(payload);
    const authorization = `bearer ${providerToken(config)}`;
    return await Promise.all(
      tokens.map(
        (token) =>
          new Promise<DeliveryResult>((resolve, reject) => {
            const request = session.request({
              ":method": "POST",
              ":path": `/3/device/${token}`,
              authorization,
              "apns-topic": config.topic,
              "apns-push-type": "alert",
              "apns-priority": "10",
              "content-type": "application/json",
            });
            let status = 0;
            let apnsId: string | undefined;
            let text = "";
            request.setEncoding("utf8");
            request.on("response", (headers) => {
              status = Number(headers[":status"]);
              const id = headers["apns-id"];
              apnsId = Array.isArray(id) ? id[0] : id;
            });
            request.on("data", (chunk: string) => (text += chunk));
            request.on("end", () => {
              let reason: string | undefined;
              if (text) {
                try {
                  reason = (JSON.parse(text) as { reason?: string }).reason;
                } catch {
                  reason = text;
                }
              }
              resolve({ token, status, reason, apnsId });
            });
            request.on("error", reject);
            request.end(body);
          }),
      ),
    );
  } finally {
    session.close();
  }
}
