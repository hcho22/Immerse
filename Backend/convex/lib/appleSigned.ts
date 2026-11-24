"use node";
// Apple's signed data: a StoreKit 2 transaction, a subscription's renewal information and an App Store Server
// Notification are each a JWS signed by the App Store with ES256, carrying its certificate chain in the `x5c` header
// (v2 PRD section 9.7). Apple's App Store Server Library checks them as this file does: the chain must lead from
// the leaf through Apple's intermediate to the Apple Root CA - G3 this file pins, the leaf and the intermediate must
// carry Apple's marker extensions, each certificate must be valid at the moment the data was signed, and the leaf's
// key must verify the signature. Nothing the JWS says about itself is trusted before that, and its root certificate
// is never read from the JWS.
//
// Only Node's crypto is used, so this file is imported only from Node actions and the tests.
import { X509Certificate, verify } from "node:crypto";

// Apple Root CA - G3, from https://www.apple.com/certificateauthority/ (SHA-256 fingerprint
// 63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79), valid until 2039.
export const APPLE_ROOT_CA_G3_PEM = `-----BEGIN CERTIFICATE-----
MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwS
QXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9u
IEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcN
MTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBS
b290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9y
aXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49
AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtf
TjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517
IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySr
MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gA
MGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4
at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM
6BgD56KyKA==
-----END CERTIFICATE-----
`;

// Apple's marker extensions: the App Store's receipt-signing leaf, and Apple's WWDR intermediate.
const LEAF_MARKER_OID = "1.2.840.113635.100.6.11.1";
const INTERMEDIATE_MARKER_OID = "1.2.840.113635.100.6.2.1";

// A signature dated more than this far in the future is refused.
const CLOCK_SKEW_MS = 60_000;

export class SignedDataRefused extends Error {}

// The roots a signature may lead to: Apple's own, unless APPLE_ROOT_CA_PEM names another. Only the tests set it, to a
// root they made; a real deployment leaves it unset.
export function trustedRoots(): X509Certificate[] {
  const override = process.env.APPLE_ROOT_CA_PEM?.replace(/\\n/g, "\n");
  return [new X509Certificate(override && override.trim() !== "" ? override : APPLE_ROOT_CA_G3_PEM)];
}

// The extension OIDs a certificate carries, read from its DER: tbsCertificate's [3] extensions.
export function extensionOids(der: Uint8Array): string[] {
  const read = (bytes: Uint8Array, at: number) => {
    const tag = bytes[at]!;
    let length = bytes[at + 1]!;
    let header = 2;
    if (length & 0x80) {
      const count = length & 0x7f;
      if (count === 0 || count > 4) throw new SignedDataRefused("Malformed certificate");
      length = 0;
      for (let index = 0; index < count; index += 1) length = length * 256 + bytes[at + 2 + index]!;
      header += count;
    }
    if (at + header + length > bytes.length) throw new SignedDataRefused("Malformed certificate");
    return { tag, start: at + header, end: at + header + length };
  };
  const children = (bytes: Uint8Array, start: number, end: number) => {
    const found: Array<{ tag: number; start: number; end: number }> = [];
    for (let at = start; at < end; ) {
      const element = read(bytes, at);
      found.push(element);
      at = element.end;
    }
    return found;
  };
  const certificate = read(der, 0);
  const [tbs] = children(der, certificate.start, certificate.end);
  if (tbs === undefined || tbs.tag !== 0x30) throw new SignedDataRefused("Malformed certificate");
  const extensions = children(der, tbs.start, tbs.end).find((element) => element.tag === 0xa3);
  if (extensions === undefined) return [];
  const [list] = children(der, extensions.start, extensions.end);
  if (list === undefined || list.tag !== 0x30) return [];
  const oids: string[] = [];
  for (const extension of children(der, list.start, list.end)) {
    const [oid] = children(der, extension.start, extension.end);
    if (oid === undefined || oid.tag !== 0x06) throw new SignedDataRefused("Malformed certificate");
    oids.push(decodeOid(der.subarray(oid.start, oid.end)));
  }
  return oids;
}

function decodeOid(bytes: Uint8Array): string {
  const parts: number[] = [];
  let value = 0;
  for (const byte of bytes) {
    value = value * 128 + (byte & 0x7f);
    if ((byte & 0x80) === 0) {
      if (parts.length === 0) parts.push(value < 80 ? Math.floor(value / 40) : 2, value < 80 ? value % 40 : value - 80);
      else parts.push(value);
      value = 0;
    }
  }
  return parts.join(".");
}

function validAt(certificate: X509Certificate, at: number): boolean {
  return new Date(certificate.validFrom).getTime() <= at && at <= new Date(certificate.validTo).getTime();
}

function decodeSegment(segment: string | undefined): Record<string, unknown> {
  if (segment === undefined || !/^[A-Za-z0-9_-]+$/.test(segment)) throw new SignedDataRefused("Malformed JWS");
  try {
    const value: unknown = JSON.parse(Buffer.from(segment, "base64url").toString("utf8"));
    if (typeof value !== "object" || value === null || Array.isArray(value)) throw new Error("not an object");
    return value as Record<string, unknown>;
  } catch {
    throw new SignedDataRefused("Malformed JWS");
  }
}

// Verifies a JWS the App Store signed and returns its payload. Throws `SignedDataRefused` for anything else.
export function verifyAppleSigned(jws: string, roots: X509Certificate[] = trustedRoots(), now = Date.now()) {
  if (typeof jws !== "string" || jws.length > 64 * 1024) throw new SignedDataRefused("Malformed JWS");
  const [headerSegment, payloadSegment, signatureSegment, extra] = jws.split(".");
  if (extra !== undefined || signatureSegment === undefined || !/^[A-Za-z0-9_-]+$/.test(signatureSegment)) {
    throw new SignedDataRefused("Malformed JWS");
  }
  const header = decodeSegment(headerSegment);
  const payload = decodeSegment(payloadSegment);
  if (header.alg !== "ES256") throw new SignedDataRefused("Not signed with ES256");
  const chain = header.x5c;
  if (!Array.isArray(chain) || chain.length < 2 || !chain.every((entry) => typeof entry === "string")) {
    throw new SignedDataRefused("No certificate chain");
  }
  let leaf: X509Certificate;
  let intermediate: X509Certificate;
  let leafDer: Buffer;
  let intermediateDer: Buffer;
  try {
    leafDer = Buffer.from(chain[0] as string, "base64");
    intermediateDer = Buffer.from(chain[1] as string, "base64");
    leaf = new X509Certificate(leafDer);
    intermediate = new X509Certificate(intermediateDer);
  } catch {
    throw new SignedDataRefused("Malformed certificate");
  }
  const root = roots.find((candidate) => intermediate.checkIssued(candidate) && intermediate.verify(candidate.publicKey));
  if (root === undefined) throw new SignedDataRefused("The chain does not lead to Apple's root");
  if (!leaf.checkIssued(intermediate) || !leaf.verify(intermediate.publicKey)) {
    throw new SignedDataRefused("The leaf is not issued by the intermediate");
  }
  if (!intermediate.ca || leaf.ca) throw new SignedDataRefused("The chain's certificate roles are wrong");
  if (!extensionOids(leafDer).includes(LEAF_MARKER_OID)) throw new SignedDataRefused("The leaf is not the App Store's");
  if (!extensionOids(intermediateDer).includes(INTERMEDIATE_MARKER_OID)) {
    throw new SignedDataRefused("The intermediate is not Apple's");
  }
  // As Apple's library does without its online checks, the chain is judged at the moment the data was signed.
  const signedDate = payload.signedDate;
  if (typeof signedDate !== "number" || !Number.isFinite(signedDate)) throw new SignedDataRefused("No signing date");
  if (signedDate > now + CLOCK_SKEW_MS) throw new SignedDataRefused("Signed in the future");
  if (![leaf, intermediate, root].every((certificate) => validAt(certificate, signedDate))) {
    throw new SignedDataRefused("A certificate was not valid when the data was signed");
  }
  const signed = verify(
    "sha256",
    Buffer.from(`${headerSegment}.${payloadSegment}`),
    { key: leaf.publicKey, dsaEncoding: "ieee-p1363" },
    Buffer.from(signatureSegment, "base64url"),
  );
  if (!signed) throw new SignedDataRefused("The signature does not verify");
  return payload;
}
