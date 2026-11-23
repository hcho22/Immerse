// What the backend holds: v2 PRD section 8, for what Stage 1 needs.
//
// Stage 1 builds Accounts, the guest identity of section 9.2, picture upload records, push tokens and the
// account-scoped records Delete Account must remove (the Roll ledger and the subscription link). Events and
// memberships are sketched only as far as the upload path and the read grants need them; Stage 2 (Load Film,
// joining, Rolls, the reveal) completes them. Nothing here ever holds a personal Film, an original capture, a
// location, a contact list, an advertising identifier or anything for analytics.
//
// Removal markers (section 8) are kept in place rather than in a table of their own: a withdrawn or removed
// picture keeps its row with only its event, shooter and exposure number (`pictureState`), and a removed or
// deleted shooter keeps its membership row with that status, so a late or repeated upload cannot bring either
// back (section 9.8).
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export const cameraValidator = v.union(v.literal("disposable"), v.literal("6x6"), v.literal("instant"));

// How the age 13-or-over confirmation was made (open check OC-9): Apple's Declared Age Range, where iOS says the
// person is in a region whose law requires it, or the person's own birth month and year, which the app checks and
// never sends.
export const ageConfirmationValidator = v.union(v.literal("declaredAgeRange"), v.literal("birthMonthAndYear"));

export const pictureState = v.union(
  // Asked for an upload address; the phone keeps its copy.
  v.literal("uploading"),
  // Stored whole in R2, confirmed by size and checksum; sealed until the event reveals.
  v.literal("stored"),
  // Withdrawn by its shooter, or removed by the Host, support, deletion of its shooter or its event. Only the
  // exposure number remains.
  v.literal("removed"),
);

export default defineSchema({
  // Clerk's user id, the confirmation of age 13 or over and when it was given, the display name the Host chose,
  // the creation time. Clerk itself holds the sign-in method and the email, Apple or Google identity.
  accounts: defineTable({
    // Convex's `tokenIdentifier` for the Clerk session (issuer and subject), the key every request is matched by.
    tokenIdentifier: v.string(),
    clerkUserId: v.string(),
    displayName: v.string(),
    ageConfirmedAt: v.number(),
    ageConfirmation: ageConfirmationValidator,
    createdAt: v.number(),
    // Set when Delete Account starts; from then on the Account can do nothing but finish its deletion.
    deletionRequestedAt: v.optional(v.number()),
  })
    .index("by_token", ["tokenIdentifier"])
    .index("by_clerk_user", ["clerkUserId"]),

  // A Clerk user whose Account was deleted here but whose deletion at Clerk has not yet been confirmed. Delete
  // Account retries it, and the same Clerk user cannot make a new Account until it is gone (V2-FR-05: signing in
  // again creates a new, empty Account, which needs a new Clerk user).
  clerkDeletions: defineTable({
    clerkUserId: v.string(),
    requestedAt: v.number(),
    attempts: v.number(),
  }).index("by_clerk_user", ["clerkUserId"]),

  // Each purchase credit, free credit, set-aside, return, refund and reversal (Stage 4 writes them). On Delete
  // Account the purchase rows stay for accounting without the Account; every other row goes.
  rollLedger: defineTable({
    accountId: v.optional(v.id("accounts")),
    kind: v.union(
      v.literal("purchase"),
      v.literal("free"),
      v.literal("setAside"),
      v.literal("return"),
      v.literal("refund"),
      v.literal("refundReversed"),
    ),
    rolls: v.number(),
    appleTransactionId: v.optional(v.string()),
    eventId: v.optional(v.id("events")),
    at: v.number(),
  })
    .index("by_account", ["accountId"])
    .index("by_transaction", ["appleTransactionId"]),

  // Apple's original transaction id for a confirmed subscription, linked to one Account (Stage 4).
  subscriptionLinks: defineTable({
    accountId: v.id("accounts"),
    originalTransactionId: v.string(),
    linkedAt: v.number(),
  })
    .index("by_account", ["accountId"])
    .index("by_original_transaction", ["originalTransactionId"]),

  // The device token for the alert, per signed-in or joined installation of the full app.
  pushTokens: defineTable({
    // A random id the app makes once per installation, so a new token replaces the old one.
    installationId: v.string(),
    token: v.string(),
    environment: v.union(v.literal("sandbox"), v.literal("production")),
    accountId: v.optional(v.id("accounts")),
    guestIdentityId: v.optional(v.id("guestIdentities")),
    updatedAt: v.number(),
  })
    .index("by_installation", ["installationId"])
    .index("by_token", ["token"])
    .index("by_account", ["accountId"])
    .index("by_guest_identity", ["guestIdentityId"]),

  // A random id and a secret's verifier, never a device identifier; the Account it was claimed into, if any.
  guestIdentities: defineTable({
    publicId: v.string(),
    secretVerifier: v.string(),
    accountId: v.optional(v.id("accounts")),
    createdAt: v.number(),
    claimedAt: v.optional(v.number()),
  })
    .index("by_public_id", ["publicId"])
    .index("by_account", ["accountId"]),

  // The short-lived token a guest identity is given for one event (section 9.2). Only a hash of the token is kept.
  guestSessions: defineTable({
    tokenHash: v.string(),
    guestIdentityId: v.id("guestIdentities"),
    eventId: v.id("events"),
    expiresAt: v.number(),
  })
    .index("by_token_hash", ["tokenHash"])
    .index("by_guest_identity", ["guestIdentityId"])
    .index("by_event", ["eventId"]),

  // Sketch for Stage 1: what the upload path and the read grants read. Stage 2 adds the Film Stock, the package
  // and treatment versions, the Start Time, the Reveal Delay, Rolls, the joining state, the Join Code verifier and
  // the web album switch.
  events: defineTable({
    title: v.string(),
    // Absent once the Host deleted their Account (V2-FR-06): the event runs on with no Host.
    hostAccountId: v.optional(v.id("accounts")),
    hostLeftAt: v.optional(v.number()),
    camera: cameraValidator,
    exposuresPerRoll: v.number(),
    endsAt: v.number(),
    revealsAt: v.number(),
    state: v.union(
      v.literal("open"),
      v.literal("ended"),
      v.literal("revealed"),
      v.literal("gone"),
      v.literal("deleted"),
    ),
    createdAt: v.number(),
  }).index("by_host", ["hostAccountId"]),

  // Which guest identity or Account holds which Roll in which event, the Guest Name, exposures used, left or
  // removed. Exactly one of accountId and guestIdentityId is set.
  memberships: defineTable({
    eventId: v.id("events"),
    accountId: v.optional(v.id("accounts")),
    guestIdentityId: v.optional(v.id("guestIdentities")),
    guestName: v.string(),
    exposuresUsed: v.number(),
    status: v.union(v.literal("joined"), v.literal("left"), v.literal("removed"), v.literal("deleted")),
    joinedAt: v.number(),
  })
    .index("by_event", ["eventId"])
    .index("by_event_and_account", ["eventId", "accountId"])
    .index("by_event_and_guest_identity", ["eventId", "guestIdentityId"])
    .index("by_account", ["accountId"])
    .index("by_guest_identity", ["guestIdentityId"]),

  // Event, shooter, exposure number, capture time, upload and seal state, size, checksum, storage key. The picture
  // itself is in Cloudflare R2. A removed picture keeps only its number.
  pictures: defineTable({
    eventId: v.id("events"),
    membershipId: v.id("memberships"),
    exposureNumber: v.number(),
    state: pictureState,
    captureTime: v.optional(v.number()),
    contentType: v.optional(v.string()),
    size: v.optional(v.number()),
    // SHA-256 of the file, base64, as the phone computed it and as the upload address requires.
    sha256: v.optional(v.string()),
    storageKey: v.optional(v.string()),
    requestedAt: v.number(),
    storedAt: v.optional(v.number()),
    removedAt: v.optional(v.number()),
  })
    .index("by_shooter_and_exposure", ["membershipId", "exposureNumber"])
    .index("by_event", ["eventId"])
    .index("by_storage_key", ["storageKey"]),

  // R2 objects to delete. Deletion writes the marker (the picture's state) first and queues the object here, so a
  // failed storage call is retried and never forgotten.
  storageDeletions: defineTable({
    storageKey: v.string(),
    queuedAt: v.number(),
    attempts: v.number(),
  }).index("by_storage_key", ["storageKey"]),
});
