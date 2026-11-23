// The Join Code (V2-FR-15, V2-FR-17): 128 bits that reveal nothing about the event or the Host, carried by one link and
// one QR code for the event's whole life unless the Host replaces it.
//
// The server stores each code only as a verifier (section 8), so its database alone gives no code away. The Host still
// needs the current code on any iPhone they sign in on, so the code is derived rather than kept: an HMAC of the event's
// id and the code's generation under JOIN_CODE_SECRET, a deployment secret. Replacing the code moves to the next
// generation, and the old verifier stays marked retired so its link can say it no longer works.
import { bytesToBase64Url, sha256Hex } from "./crypto";

export const JOIN_CODE = /^[A-Za-z0-9_-]{22}$/;

function secret(): string {
  const value = process.env.JOIN_CODE_SECRET;
  if (value === undefined || value.length < 32) {
    throw new Error("Join Codes are not configured: JOIN_CODE_SECRET must be at least 32 characters");
  }
  return value;
}

export async function joinCodeFor(eventId: string, generation: number): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret()), { name: "HMAC", hash: "SHA-256" }, false, [
    "sign",
  ]);
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`immerse-join:${eventId}:${generation}`));
  return bytesToBase64Url(new Uint8Array(mac).slice(0, 16));
}

export function joinCodeVerifier(code: string): Promise<string> {
  return sha256Hex(`immerse-join-code:${code}`);
}
