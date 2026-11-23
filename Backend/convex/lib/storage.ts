// The private picture bucket, through R2's S3-compatible API (section 9.3, 9.4).
//
// Convex signs every address itself with R2's S3 credentials: Cloudflare's documentation says presigned addresses
// must be signed with an S3 client, since the Workers binding cannot sign them, and work only on R2's S3 domain.
// aws4fetch is that client: small, and it runs in Convex's default runtime. The bucket has no public access, so an
// object can be read only through a signed request, and Convex signs a read address only after the reveal
// (reads.ts). The same code runs against a local S3-compatible emulator in tests.
import { AwsClient } from "aws4fetch";

export type StorageConfig = {
  // R2's S3 endpoint, https://<account id>.r2.cloudflarestorage.com, or a local emulator's address.
  endpoint: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
  // "auto" for R2.
  region: string;
};

// A one-time upload address lasts five minutes: long enough for a 25 MB picture over a poor connection to start,
// short enough that a leaked address is soon useless. A slow upload that outlives it fails and asks again.
export const UPLOAD_ADDRESS_SECONDS = 300;
// A read address lasts one minute: the app asks for addresses just before it downloads.
export const READ_ADDRESS_SECONDS = 60;
// The largest developed picture the server accepts. A 12-megapixel JPEG is far smaller; confirming reads the
// object whole inside an action, whose memory is bounded.
export const MAX_PICTURE_BYTES = 25 * 1024 * 1024;
export const PICTURE_CONTENT_TYPES = ["image/jpeg", "image/heic"] as const;

export function storageConfig(): StorageConfig {
  const read = (name: string) => {
    const value = process.env[name];
    if (value === undefined || value === "") throw new Error(`Storage is not configured: ${name} is not set`);
    return value;
  };
  return {
    endpoint: read("R2_ENDPOINT").replace(/\/+$/, ""),
    bucket: read("R2_BUCKET"),
    accessKeyId: read("R2_ACCESS_KEY_ID"),
    secretAccessKey: read("R2_SECRET_ACCESS_KEY"),
    region: process.env.R2_REGION || "auto",
  };
}

function client(config: StorageConfig) {
  return new AwsClient({
    accessKeyId: config.accessKeyId,
    secretAccessKey: config.secretAccessKey,
    service: "s3",
    region: config.region,
  });
}

function objectUrl(config: StorageConfig, key: string): URL {
  const encodedKey = key.split("/").map(encodeURIComponent).join("/");
  return new URL(`${config.endpoint}/${encodeURIComponent(config.bucket)}/${encodedKey}`);
}

export type SignedRequest = { url: string; method: "PUT" | "GET"; headers: Record<string, string> };

// A presigned PUT for one key, bound to the picture's content type and SHA-256: both headers are signed, so a
// request with a different content type is refused, and S3-compatible storage that checks `x-amz-checksum-sha256`
// refuses a body that does not match it. The size cannot be bound by a presigned PUT, which is why confirming
// checks it (section 9.3).
export async function presignUpload(
  config: StorageConfig,
  key: string,
  contentType: string,
  sha256Base64: string,
  expiresInSeconds = UPLOAD_ADDRESS_SECONDS,
): Promise<SignedRequest> {
  const url = objectUrl(config, key);
  url.searchParams.set("X-Amz-Expires", String(expiresInSeconds));
  const headers = { "content-type": contentType, "x-amz-checksum-sha256": sha256Base64 };
  const signed = await client(config).sign(new Request(url, { method: "PUT", headers }), {
    aws: { signQuery: true, allHeaders: true },
  });
  return { url: signed.url, method: "PUT", headers: { "Content-Type": contentType, "x-amz-checksum-sha256": sha256Base64 } };
}

// A presigned GET for one key.
export async function presignRead(
  config: StorageConfig,
  key: string,
  expiresInSeconds = READ_ADDRESS_SECONDS,
): Promise<SignedRequest> {
  const url = objectUrl(config, key);
  url.searchParams.set("X-Amz-Expires", String(expiresInSeconds));
  const signed = await client(config).sign(new Request(url, { method: "GET" }), { aws: { signQuery: true } });
  return { url: signed.url, method: "GET", headers: {} };
}

export type StoredObject = { size: number; bytes: Uint8Array } | null;

// The object's bytes, or null when no object has that key. Reads at most `limit` bytes plus one, so an oversized
// object is recognized without reading it all.
export async function readObject(config: StorageConfig, key: string, limit = MAX_PICTURE_BYTES): Promise<StoredObject> {
  const response = await client(config).fetch(objectUrl(config, key), {
    method: "GET",
    headers: { range: `bytes=0-${limit}` },
  });
  if (response.status === 404) return null;
  // An empty object has no byte 0 to start a range at.
  if (response.status === 416) return { size: 0, bytes: new Uint8Array() };
  if (response.status !== 200 && response.status !== 206) {
    throw new Error(`Storage read failed with HTTP ${response.status}`);
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  // A 206 carries the whole object's size after the slash of Content-Range.
  const range = response.headers.get("content-range");
  const size = range !== null ? Number(range.split("/")[1]) : bytes.byteLength;
  return { size: Number.isFinite(size) ? size : bytes.byteLength, bytes };
}

// Deletes an object; deleting a key that holds nothing succeeds, so every deletion can be repeated.
export async function deleteObject(config: StorageConfig, key: string): Promise<void> {
  const response = await client(config).fetch(objectUrl(config, key), { method: "DELETE" });
  if (response.status !== 204 && response.status !== 200 && response.status !== 404) {
    throw new Error(`Storage delete failed with HTTP ${response.status}`);
  }
}
