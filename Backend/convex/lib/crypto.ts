// Hashing and random tokens with Web Crypto, which Convex's default runtime, its Node runtime and the tests share.

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

export function bytesToBase64Url(bytes: Uint8Array): string {
  return bytesToBase64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function sha256(data: Uint8Array | string): Promise<Uint8Array> {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  return new Uint8Array(await crypto.subtle.digest("SHA-256", bytes as Uint8Array<ArrayBuffer>));
}

export async function sha256Hex(data: Uint8Array | string): Promise<string> {
  return bytesToHex(await sha256(data));
}

export async function sha256Base64(data: Uint8Array | string): Promise<string> {
  return bytesToBase64(await sha256(data));
}

// An unguessable token of `byteCount` random bytes, base64url without padding.
export function randomToken(byteCount = 32): string {
  return bytesToBase64Url(crypto.getRandomValues(new Uint8Array(byteCount)));
}

// A random (version 4) UUID, lowercase, as StoreKit's app account token takes one.
export function randomUuid(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6]! & 0x0f) | 0x40;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = bytesToHex(bytes);
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

// Compares two strings in time that depends only on their lengths.
export function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index += 1) difference |= a.charCodeAt(index) ^ b.charCodeAt(index);
  return difference === 0;
}

// A base64 SHA-256 digest is exactly 44 characters ending in one "=".
export function isBase64Sha256(value: string): boolean {
  return /^[A-Za-z0-9+/]{43}=$/.test(value);
}
