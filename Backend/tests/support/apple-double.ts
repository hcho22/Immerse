// Stand-ins for Apple's side of buying Rolls (v2 PRD section 9.7), made fresh for each test, with nothing real:
//
// - A certificate chain shaped like the App Store's: a root, an intermediate carrying Apple's WWDR marker extension and
//   a leaf carrying the App Store's receipt-signing marker, all made here. The server trusts this root only because
//   the test sets APPLE_ROOT_CA_PEM to it. It signs transactions and notifications as the App Store signs them (ES256
//   JWS with the chain in `x5c`).
// - A forger's chain of the same shape under a root the server does not trust, for the refusals.
// - The App Store Server API's two answers the server asks for, Get Transaction Info and Get All Subscription
//   Statuses, over HTTP on 127.0.0.1, checking each request's token against an In-App Purchase key made here.
import "reflect-metadata";
import { generateKeyPairSync, verify } from "node:crypto";
import { createServer, type Server } from "node:http";
import * as x509 from "@peculiar/x509";

const ALGORITHM = { name: "ECDSA", namedCurve: "P-256", hash: "SHA-256" } as const;
export const LEAF_MARKER = "1.2.840.113635.100.6.11.1";
export const INTERMEDIATE_MARKER = "1.2.840.113635.100.6.2.1";
const DAY_MS = 86_400_000;

export const BUNDLE_ID = "com.immerse.FilmJournal";
export const APP_APPLE_ID = 6700000000;
export const PACK_SMALL = "test.immerse.rolls.small";
export const PACK_LARGE = "test.immerse.rolls.large";
export const MONTHLY = "test.immerse.monthly";
export const YEARLY = "test.immerse.yearly";

type Chain = { leafKey: CryptoKey; x5c: string[]; rootPem: string };

// A chain of root, intermediate and leaf. Each marker extension can be left off, for the refusals.
export async function makeChain(options: { leafMarker?: boolean; intermediateMarker?: boolean; expired?: boolean } = {}) {
  const { leafMarker = true, intermediateMarker = true, expired = false } = options;
  const notBefore = new Date(Date.now() - (expired ? 400 : 1) * DAY_MS);
  const notAfter = new Date(Date.now() + (expired ? -300 : 365) * DAY_MS);
  const keys = () => crypto.subtle.generateKey(ALGORITHM, true, ["sign", "verify"]) as Promise<CryptoKeyPair>;
  const rootKeys = await keys();
  const root = await x509.X509CertificateGenerator.createSelfSigned({
    serialNumber: "01",
    name: "CN=Test Root CA, O=Immerse tests",
    notBefore,
    notAfter,
    signingAlgorithm: ALGORITHM,
    keys: rootKeys,
    extensions: [new x509.BasicConstraintsExtension(true, undefined, true)],
  });
  const intermediateKeys = await keys();
  const intermediate = await x509.X509CertificateGenerator.create({
    serialNumber: "02",
    subject: "CN=Test WWDR CA, O=Immerse tests",
    issuer: root.subject,
    notBefore,
    notAfter,
    signingAlgorithm: ALGORITHM,
    publicKey: intermediateKeys.publicKey,
    signingKey: rootKeys.privateKey,
    extensions: [
      new x509.BasicConstraintsExtension(true, 0, true),
      ...(intermediateMarker ? [new x509.Extension(INTERMEDIATE_MARKER, false, new Uint8Array([5, 0]))] : []),
    ],
  });
  const leafKeys = await keys();
  const leaf = await x509.X509CertificateGenerator.create({
    serialNumber: "03",
    subject: "CN=Test StoreKit Signing, O=Immerse tests",
    issuer: intermediate.subject,
    notBefore,
    notAfter,
    signingAlgorithm: ALGORITHM,
    publicKey: leafKeys.publicKey,
    signingKey: intermediateKeys.privateKey,
    extensions: [
      new x509.BasicConstraintsExtension(false, undefined, true),
      ...(leafMarker ? [new x509.Extension(LEAF_MARKER, false, new Uint8Array([5, 0]))] : []),
    ],
  });
  const chain: Chain = {
    leafKey: leafKeys.privateKey,
    x5c: [leaf, intermediate, root].map((certificate) => certificate.toString("base64")),
    rootPem: root.toString("pem"),
  };
  return chain;
}

function segment(value: object) {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

// Signs a payload as the App Store does: ES256, the chain in `x5c`.
export async function signWith(chain: Chain, payload: object): Promise<string> {
  const head = `${segment({ alg: "ES256", x5c: chain.x5c })}.${segment(payload)}`;
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, chain.leafKey, Buffer.from(head));
  return `${head}.${Buffer.from(signature).toString("base64url")}`;
}

export type TransactionFields = {
  transactionId: string;
  originalTransactionId?: string;
  productId: string;
  type?: string;
  environment?: "Production" | "Sandbox" | "Xcode";
  bundleId?: string;
  appAccountToken?: string;
  purchaseDate?: number;
  signedDate?: number;
  revocationDate?: number;
  expiresDate?: number;
};

// A transaction's payload, with the fields Apple's JWSTransactionDecodedPayload carries.
export function transactionPayload(fields: TransactionFields) {
  const now = Date.now();
  const subscription = fields.productId === MONTHLY || fields.productId === YEARLY;
  return {
    transactionId: fields.transactionId,
    originalTransactionId: fields.originalTransactionId ?? fields.transactionId,
    bundleId: fields.bundleId ?? BUNDLE_ID,
    productId: fields.productId,
    purchaseDate: fields.purchaseDate ?? now - 1_000,
    originalPurchaseDate: fields.purchaseDate ?? now - 1_000,
    quantity: 1,
    type: fields.type ?? (subscription ? "Auto-Renewable Subscription" : "Consumable"),
    inAppOwnershipType: "PURCHASED",
    signedDate: fields.signedDate ?? now,
    environment: fields.environment ?? "Sandbox",
    transactionReason: "PURCHASE",
    storefront: "USA",
    storefrontId: "143441",
    ...(fields.appAccountToken !== undefined ? { appAccountToken: fields.appAccountToken } : {}),
    ...(fields.revocationDate !== undefined ? { revocationDate: fields.revocationDate, revocationReason: 0 } : {}),
    ...(fields.expiresDate !== undefined ? { expiresDate: fields.expiresDate } : {}),
    ...(subscription && fields.expiresDate === undefined ? { expiresDate: now + 30 * DAY_MS } : {}),
  };
}

type Recorded = { method: string; path: string; authorization: string | undefined };

// The App Store as the tests see it: what Apple signs, and what its server API answers.
export async function startAppleDouble() {
  const chain = await makeChain();
  const forger = await makeChain();
  const apiKey = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  // Apple's current view of each transaction, and each subscription's status, by id.
  const transactions = new Map<string, TransactionFields>();
  const subscriptions = new Map<string, { status: number; transactionId: string }>();
  const requests: Recorded[] = [];
  let unavailable = false;

  async function sign(fields: TransactionFields) {
    return signWith(chain, transactionPayload({ ...fields, signedDate: fields.signedDate ?? Date.now() }));
  }

  const server: Server = createServer(async (request, response) => {
    requests.push({ method: request.method ?? "", path: request.url ?? "", authorization: request.headers.authorization });
    const answer = (status: number, body?: object) => {
      response.writeHead(status, { "content-type": "application/json" });
      response.end(body === undefined ? "" : JSON.stringify(body));
    };
    if (unavailable) return answer(503, { errorCode: 5000000, errorMessage: "An unknown error occurred." });
    if (!tokenIsValid(request.headers.authorization)) return answer(401);
    const match = /^\/inApps\/v1\/(transactions|subscriptions)\/([^/?]+)$/.exec(request.url ?? "");
    if (request.method !== "GET" || match === null) return answer(404);
    const id = decodeURIComponent(match[2]!);
    if (match[1] === "transactions") {
      const fields = transactions.get(id);
      if (fields === undefined) return answer(404, { errorCode: 4040010, errorMessage: "Transaction id not found." });
      return answer(200, { signedTransactionInfo: await sign({ ...fields, signedDate: undefined }) });
    }
    const transaction = transactions.get(id);
    const original = transaction?.originalTransactionId ?? transaction?.transactionId;
    const status = original === undefined ? undefined : subscriptions.get(original);
    if (transaction === undefined || status === undefined) {
      return answer(404, { errorCode: 4040010, errorMessage: "Transaction id not found." });
    }
    const latest = transactions.get(status.transactionId)!;
    return answer(200, {
      environment: latest.environment ?? "Sandbox",
      bundleId: BUNDLE_ID,
      appAppleId: APP_APPLE_ID,
      data: [
        {
          subscriptionGroupIdentifier: "21000000",
          lastTransactions: [
            {
              originalTransactionId: original,
              status: status.status,
              signedTransactionInfo: await sign({ ...latest, signedDate: undefined }),
              signedRenewalInfo: await signWith(chain, { originalTransactionId: original, signedDate: Date.now() }),
            },
          ],
        },
      ],
    });
  });

  // The App Store Server API's token check: ES256 under the In-App Purchase key, for this app, not expired.
  function tokenIsValid(authorization: string | undefined): boolean {
    if (authorization === undefined || !authorization.startsWith("Bearer ")) return false;
    const [header, claims, signature] = authorization.slice("Bearer ".length).split(".");
    if (header === undefined || claims === undefined || signature === undefined) return false;
    const valid = verify(
      "sha256",
      Buffer.from(`${header}.${claims}`),
      { key: apiKey.publicKey, dsaEncoding: "ieee-p1363" },
      Buffer.from(signature, "base64url"),
    );
    const head = JSON.parse(Buffer.from(header, "base64url").toString());
    const body = JSON.parse(Buffer.from(claims, "base64url").toString());
    const now = Date.now() / 1000;
    return (
      valid &&
      head.alg === "ES256" &&
      head.kid === "TESTKEY123" &&
      body.iss === "00000000-0000-0000-0000-000000000000" &&
      body.aud === "appstoreconnect-v1" &&
      body.bid === BUNDLE_ID &&
      body.iat <= now + 5 &&
      body.exp > now &&
      body.exp - body.iat <= 3600
    );
  }

  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  if (address === null || typeof address === "string") throw new Error("no address");
  const settings: Record<string, string> = {
    APPLE_ROOT_CA_PEM: chain.rootPem,
    APP_STORE_API_ORIGIN: `http://127.0.0.1:${address.port}`,
    APP_STORE_KEY_ID: "TESTKEY123",
    APP_STORE_ISSUER_ID: "00000000-0000-0000-0000-000000000000",
    APP_STORE_PRIVATE_KEY: apiKey.privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
    APPLE_BUNDLE_ID: BUNDLE_ID,
    APPLE_APP_APPLE_ID: String(APP_APPLE_ID),
    APPLE_ENVIRONMENTS: "Production,Sandbox",
    // Synthetic test sizes, not proposed pack sizes (OC-5).
    ROLL_PACKS: `${PACK_SMALL}:5,${PACK_LARGE}:25`,
    SUBSCRIPTION_PRODUCT_IDS: `${MONTHLY},${YEARLY}`,
    FREE_ROLLS_SUBSCRIBER: "20",
  };
  const previous = Object.fromEntries(Object.keys(settings).map((name) => [name, process.env[name]]));
  Object.assign(process.env, settings);

  return {
    chain,
    forger,
    requests,
    settings,
    // Apple's record of a purchase, as Get Transaction Info will answer it, and the transaction the app holds.
    async purchase(fields: TransactionFields) {
      transactions.set(fields.transactionId, fields);
      return sign(fields);
    },
    // Changes Apple's record, such as a refund, and returns the transaction as Apple signs it now.
    async update(transactionId: string, change: Partial<TransactionFields>) {
      const fields = { ...transactions.get(transactionId)!, ...change };
      transactions.set(transactionId, fields);
      return sign(fields);
    },
    // A subscription's status: 1 active, 2 expired, 3 billing retry, 4 grace period, 5 revoked.
    async subscribe(fields: TransactionFields, status = 1) {
      transactions.set(fields.transactionId, fields);
      subscriptions.set(fields.originalTransactionId ?? fields.transactionId, { status, transactionId: fields.transactionId });
      return sign(fields);
    },
    setSubscriptionStatus(originalTransactionId: string, status: number, latestTransactionId?: string) {
      const current = subscriptions.get(originalTransactionId)!;
      subscriptions.set(originalTransactionId, { status, transactionId: latestTransactionId ?? current.transactionId });
    },
    sign,
    // An App Store Server Notification, version 2, signed with the given chain (Apple's by default).
    async notification(
      notificationType: string,
      transaction: TransactionFields | null,
      options: { chain?: Chain; bundleId?: string; environment?: string; appAppleId?: number; signedDate?: number } = {},
    ) {
      const environment = options.environment ?? transaction?.environment ?? "Sandbox";
      return signWith(options.chain ?? chain, {
        notificationType,
        notificationUUID: crypto.randomUUID(),
        version: "2.0",
        signedDate: options.signedDate ?? Date.now(),
        data: {
          appAppleId: options.appAppleId ?? APP_APPLE_ID,
          bundleId: options.bundleId ?? BUNDLE_ID,
          bundleVersion: "1",
          environment,
          ...(transaction === null
            ? {}
            : { signedTransactionInfo: await signWith(options.chain ?? chain, transactionPayload(transaction)) }),
        },
      });
    },
    set unavailable(value: boolean) {
      unavailable = value;
    },
    close: async () => {
      for (const [name, value] of Object.entries(previous)) {
        if (value === undefined) delete process.env[name];
        else process.env[name] = value;
      }
      await new Promise<void>((resolve) => server.close(() => resolve()));
    },
  };
}

export type AppleDouble = Awaited<ReturnType<typeof startAppleDouble>>;
