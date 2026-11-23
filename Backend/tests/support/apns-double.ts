// A stand-in for Apple's push notification service: an HTTP/2 server over TLS that records each request and
// answers per device token as a test chose. Like Apple's, it speaks only HTTP/2 (no HTTP/1.1 fallback).
import { execFileSync } from "node:child_process";
import { generateKeyPairSync, verify } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import http2 from "node:http2";
import { tmpdir } from "node:os";
import { join } from "node:path";

export type ApnsRequest = {
  httpVersion: string;
  method: string;
  path: string;
  headers: Record<string, string | string[] | undefined>;
  body: string;
};

// A self-signed certificate for 127.0.0.1, made with openssl for this run only.
function selfSignedCertificate() {
  const directory = mkdtempSync(join(tmpdir(), "immerse-apns-"));
  try {
    execFileSync(
      "openssl",
      [
        "req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes", "-days", "1",
        "-subj", "/CN=127.0.0.1", "-addext", "subjectAltName=IP:127.0.0.1",
        "-keyout", join(directory, "key.pem"), "-out", join(directory, "cert.pem"),
      ],
      { stdio: "ignore" },
    );
    return { key: readFileSync(join(directory, "key.pem"), "utf8"), cert: readFileSync(join(directory, "cert.pem"), "utf8") };
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

export async function startApnsDouble() {
  const { key, cert } = selfSignedCertificate();
  const signing = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const requests: ApnsRequest[] = [];
  const answers = new Map<string, { status: number; reason?: string }>();
  const server = http2.createSecureServer({ key, cert, allowHTTP1: false }, (request, response) => {
    let body = "";
    request.setEncoding("utf8");
    request.on("data", (chunk: string) => (body += chunk));
    request.on("end", () => {
      requests.push({ httpVersion: request.httpVersion, method: request.method, path: request.url, headers: request.headers, body });
      const token = request.url.split("/").pop() ?? "";
      const answer = answers.get(token) ?? { status: 200 };
      response.writeHead(answer.status, { "apns-id": "00000000-0000-0000-0000-000000000001" });
      response.end(answer.reason ? JSON.stringify({ reason: answer.reason }) : "");
    });
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  if (address === null || typeof address === "string") throw new Error("no address");
  const config = {
    APNS_KEY_ID: "ABC123DEFG",
    APNS_TEAM_ID: "TEAM123456",
    APNS_TOPIC: "com.immerse.FilmJournal",
    APNS_PRIVATE_KEY: signing.privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
    APNS_ORIGIN: `https://127.0.0.1:${address.port}`,
    APNS_CA_PEM: cert,
  };
  Object.assign(process.env, config);
  return {
    requests,
    config,
    answer(token: string, status: number, reason?: string) {
      answers.set(token, { status, reason });
    },
    // Checks a provider token's ES256 signature with the signing key's public half, as Apple does.
    verifyProviderToken(token: string) {
      const [header, claims, signature] = token.split(".");
      const valid = verify(
        "sha256",
        Buffer.from(`${header}.${claims}`),
        { key: signing.publicKey, dsaEncoding: "ieee-p1363" },
        Buffer.from(signature!, "base64url"),
      );
      return {
        valid,
        header: JSON.parse(Buffer.from(header!, "base64url").toString()),
        claims: JSON.parse(Buffer.from(claims!, "base64url").toString()),
      };
    },
    close: () => new Promise<void>((resolve) => server.close(() => resolve())),
  };
}
