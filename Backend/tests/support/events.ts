// Helpers for Stage 2's tests: Load Film, joining as a guest or with an Account, and storing a picture through the
// upload path, all through the public functions the app calls.
import { expect } from "vitest";
import { api } from "../../convex/_generated/api";
import type { Id } from "../../convex/_generated/dataModel";
import { DAY_MS, HOUR_MS } from "../../convex/lib/config";
import { type Backend, pictureFile, put, randomId, signedIn } from "./convex";

export type Runner = ReturnType<typeof signedIn> | Backend;
export type Credentials = { publicId: string; secret: string };

export function credentials(): Credentials {
  return { publicId: randomId(), secret: randomId(32) };
}

export type EventSetup = {
  title?: string;
  camera?: "disposable" | "6x6" | "instant";
  filmStock?: "color" | "blackAndWhite";
  rolls?: number;
  startsAt?: number;
  endsAt?: number;
  revealDelayMs?: number;
  requestId?: string;
};

// Load Film by the Host, with a Disposable open now for a day and revealing two hours after its end.
export async function loadFilm(host: ReturnType<typeof signedIn>, setup: EventSetup = {}) {
  const now = Date.now();
  return host.mutation(api.hosting.create, {
    requestId: setup.requestId ?? randomId(),
    title: setup.title ?? "Ana & Leo",
    camera: setup.camera ?? "disposable",
    filmStock: setup.filmStock,
    rolls: setup.rolls ?? 3,
    startsAt: setup.startsAt,
    endsAt: setup.endsAt ?? (setup.startsAt ?? now) + DAY_MS,
    revealDelayMs: setup.revealDelayMs ?? 2 * HOUR_MS,
    treatmentVersion: "film-look-5",
  });
}

// A guest with no Account joining through the link, with a fresh guest identity unless one is given.
export async function joinAsGuest(t: Backend, joinCode: string, guestName = "Jo", guest: Credentials = credentials()) {
  const reply = await t.mutation(api.joining.join, { code: joinCode, guestName, guest });
  return { ...reply, guest, token: reply.guestToken! };
}

// One developed picture, with its viewing copy, through the upload path to stored.
export async function storePicture(
  runner: Runner,
  eventId: Id<"events">,
  exposureNumber: number,
  options: { guestToken?: string; captureTime?: number; size?: number } = {},
) {
  const file = await pictureFile(options.size ?? 8 * 1024);
  const view = await pictureFile(2 * 1024);
  const address = await runner.action(api.pictures.requestUpload, {
    eventId,
    exposureNumber,
    captureTime: options.captureTime ?? Date.now(),
    contentType: file.contentType,
    size: file.size,
    sha256: file.sha256,
    view: { size: view.size, sha256: view.sha256 },
    guestToken: options.guestToken,
  });
  if (address.status !== "upload") throw new Error("expected an address");
  expect((await put(address, file.bytes)).status).toBe(200);
  expect((await put(address.view!, view.bytes)).status).toBe(200);
  expect(await runner.action(api.pictures.confirmUpload, { eventId, exposureNumber, guestToken: options.guestToken })).toEqual({
    status: "stored",
  });
  return { file, view };
}

// A fresh token from the guest identity's secret, as the app asks for one when its token runs out after an hour.
export async function freshToken(t: Backend, eventId: Id<"events">, guest: Credentials): Promise<string> {
  return (await t.mutation(api.guests.startSession, { ...guest, eventId })).token;
}
