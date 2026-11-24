// What the backend holds: v2 PRD section 8.
//
// Stage 1 built Accounts, the guest identity of section 9.2, picture upload records, push tokens and the
// account-scoped records Delete Account must remove. Stage 2 adds Group Films with their Join Codes, memberships with
// their Rolls, the viewing copies, reports and the Roll ledger's free credits and set-asides. Stage 3 adds only each
// picture's CRC-32, for the web album's download. Stage 4 adds each Account's purchase token, the Roll purchases Apple
// confirmed with their refunds, and the subscription link. Nothing here ever holds a personal Film, an original
// capture, a location, a contact list, an advertising identifier or anything for analytics.
//
// Removal markers (section 8) are kept in place rather than in a table of their own: a withdrawn or removed
// picture keeps its row with only its event, shooter, exposure number and place in capture order (`pictureState`), a
// removed or deleted shooter keeps its membership row with that status, and Withdraw Before Reveal records the last
// exposure it took (`withdrawnThrough`), so a late or repeated upload cannot bring any of them back (section 9.8).
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export const cameraValidator = v.union(v.literal("disposable"), v.literal("6x6"), v.literal("instant"));
export const filmStockValidator = v.union(v.literal("color"), v.literal("blackAndWhite"));

// Section 6.1's states as stored. Ending and the web album's switch are read from the times and the event's fields.
export const eventState = v.union(
  v.literal("scheduled"),
  v.literal("open"),
  v.literal("ended"),
  v.literal("revealed"),
  v.literal("gone"),
  v.literal("deleted"),
);

// The reasons a member can give when reporting a picture (V2-FR-54). The list is this build's default wording.
export const reportReasonValidator = v.union(
  v.literal("sexual"),
  v.literal("violence"),
  v.literal("harassment"),
  v.literal("privacy"),
  v.literal("other"),
);

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
    // A random UUID the app sets as each Roll purchase's app account token (section 9.7), which Apple returns in the
    // signed transaction, so a purchase is credited to the Account that bought it even when the app never reports it.
    // Absent on an Account made before Stage 4 until it first shops (`purchases:shoppingToken`).
    appAccountToken: v.optional(v.string()),
  })
    .index("by_token", ["tokenIdentifier"])
    .index("by_clerk_user", ["clerkUserId"])
    .index("by_app_account_token", ["appAccountToken"]),

  // A Clerk user whose Account was deleted here but whose deletion at Clerk has not yet been confirmed. Delete
  // Account retries it, and the same Clerk user cannot make a new Account until it is gone (V2-FR-05: signing in
  // again creates a new, empty Account, which needs a new Clerk user).
  clerkDeletions: defineTable({
    clerkUserId: v.string(),
    requestedAt: v.number(),
    attempts: v.number(),
  }).index("by_clerk_user", ["clerkUserId"]),

  // Each purchase credit, free credit, set-aside, return, refund and reversal. A purchase's rows carry Apple's
  // transaction id, and their sum is what that purchase adds to the balance now. On Delete Account the purchase rows
  // stay for accounting without the Account; every other row goes.
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
    // Which once-ever free amount a free row is (V2-FR-62): everyone's, or a subscriber's (Stage 4).
    freeGrant: v.optional(v.union(v.literal("everyone"), v.literal("subscriber"))),
    // The app's request id for adding Rolls, so a repeated request sets aside once (V2-FR-81).
    requestId: v.optional(v.string()),
    at: v.number(),
  })
    .index("by_account", ["accountId"])
    .index("by_account_and_request", ["accountId", "requestId"])
    .index("by_transaction", ["appleTransactionId"]),

  // A Roll purchase as Apple last confirmed it (V2-FR-60, V2-FR-65, section 6.5): one row per Apple transaction, from
  // the app's report or Apple's server notification, whichever came first. Its Rolls are fixed when it is first seen,
  // so a later change to the packs on sale never changes what it credits or what its refund removes. On Delete
  // Account it stays for accounting and refunds without the Account or its token.
  purchases: defineTable({
    transactionId: v.string(),
    originalTransactionId: v.string(),
    productId: v.string(),
    environment: v.union(v.literal("Production"), v.literal("Sandbox")),
    // The pack's Rolls when the purchase was first seen; absent for a consumable of this app that is not a Roll pack on
    // sale, which credits nothing until the packs name it.
    rolls: v.optional(v.number()),
    // The app account token Apple returned with the purchase, until the Account it names is deleted.
    appAccountToken: v.optional(v.string()),
    // The Account it credits. Set once and never moved; removed with the Account on Delete Account.
    accountId: v.optional(v.id("accounts")),
    // When it was first credited to an Account, which it never is again, even after that Account is deleted.
    assignedAt: v.optional(v.number()),
    purchasedAt: v.number(),
    // Refunded as of Apple's latest signed view of the transaction (`stateSignedAt`): an older view never undoes a
    // newer one, so a refund and its reversal apply in Apple's order whatever order they arrive in.
    revoked: v.boolean(),
    revokedAt: v.optional(v.number()),
    stateSignedAt: v.number(),
    firstSeenAt: v.number(),
  })
    .index("by_transaction", ["transactionId"])
    .index("by_account", ["accountId"])
    .index("by_app_account_token", ["appAccountToken"]),

  // Apple's original transaction id for a confirmed subscription, linked to one Account (V2-FR-63). Its subscriber
  // Rolls are credited once, when the link is made. On Delete Account the link to the Account is removed and the row
  // stays without it, so the same subscription never brings subscriber Rolls to a second Account.
  subscriptionLinks: defineTable({
    accountId: v.optional(v.id("accounts")),
    originalTransactionId: v.string(),
    environment: v.union(v.literal("Production"), v.literal("Sandbox")),
    linkedAt: v.number(),
    // The subscriber Rolls credited at the link.
    rollsCredited: v.number(),
    // When the linked Account was deleted.
    accountDeletedAt: v.optional(v.number()),
  })
    .index("by_account", ["accountId"])
    .index("by_original_transaction", ["environment", "originalTransactionId"]),

  // The device token for the alert, per signed-in or joined installation of the full app. One installation has one
  // row, which can carry both the Account signed in on it and the phone's guest identity (V2-FR-70).
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

    // A Group Film: title, Host, Camera, Film Stock, the Host's treatment version at Load Film, Rolls set aside and taken,
  // Start Time if any, End Time, Reveal Delay, joining state, the Join Code's generation (the code itself is derived and
  // stored only as a verifier, in `joinCodes`), the web album switch, the reveal time and the state (section 6.1).
  events: defineTable({
    title: v.string(),
    // Absent once the Host deleted their Account (V2-FR-06): the event runs on with no Host.
    hostAccountId: v.optional(v.id("accounts")),
    hostLeftAt: v.optional(v.number()),
    camera: cameraValidator,
    // Required on the 6×6 and refused elsewhere (V2-FR-10, ADR 0014).
    filmStock: v.optional(filmStockValidator),
    // The Developed Treatment version current on the Host's phone at Load Film (section 8); each phone develops with
    // its own (V2-FR-33).
    treatmentVersion: v.string(),
    exposuresPerRoll: v.number(),
    // Every Roll ever set aside for the event, taken or not; at most 200 (V2-FR-26).
    rollsSetAside: v.number(),
    rollsTaken: v.number(),
    // A later Start Time, when the Host set one (V2-FR-12); the event is Scheduled until it.
    startsAt: v.optional(v.number()),
    endsAt: v.number(),
    revealDelayMs: v.number(),
    // End Time plus Reveal Delay, or the moment the Host ended early (V2-FR-40).
    revealsAt: v.number(),
    joiningPaused: v.boolean(),
    joinCodeGeneration: v.number(),
    // The view-only web album (V2-FR-47): off unless the Host switches it on after the reveal (hosting:setWebAlbum).
    webAlbumOn: v.boolean(),
    // The stored state; `lib/phase.ts` derives the current one from the times, so nothing waits on the scheduler.
    state: eventState,
    revealedAt: v.optional(v.number()),
    // Twelve months after the reveal (V2-FR-48).
    albumEndsAt: v.optional(v.number()),
    // When unclaimed Rolls returned to the Host's balance or lapsed (V2-FR-28, V2-FR-06).
    rollsSettledAt: v.optional(v.number()),
    alertSentAt: v.optional(v.number()),
    deletedAt: v.optional(v.number()),
    // The app's request id for Load Film, so a repeated Load Film makes one event (V2-FR-81).
    createRequestId: v.optional(v.string()),
    // The scheduled steps of section 9.5, cancelled and made again when the times change.
    jobs: v.object({
      open: v.optional(v.id("_scheduled_functions")),
      end: v.optional(v.id("_scheduled_functions")),
      reveal: v.optional(v.id("_scheduled_functions")),
      gone: v.optional(v.id("_scheduled_functions")),
    }),
    createdAt: v.number(),
  })
    .index("by_host", ["hostAccountId"])
    .index("by_host_and_request", ["hostAccountId", "createRequestId"]),

  // Every Join Code an event has had, as a verifier (SHA-256 of the code), so a replaced code is told apart from one
  // that never existed (V2-FR-17, V2-FR-18). The current code is the event's `joinCodeGeneration`.
  joinCodes: defineTable({
    eventId: v.id("events"),
    verifier: v.string(),
    generation: v.number(),
    retiredAt: v.optional(v.number()),
  })
    .index("by_verifier", ["verifier"])
    .index("by_event", ["eventId"]),

  // Which guest identity or Account holds which Roll in which event, the Guest Name, exposures used, left or
  // removed. Exactly one of accountId and guestIdentityId is set while the place has a person; a deleted shooter's
  // row keeps neither, as the marker that their exposures are gone.
  memberships: defineTable({
    eventId: v.id("events"),
    accountId: v.optional(v.id("accounts")),
    guestIdentityId: v.optional(v.id("guestIdentities")),
    guestName: v.string(),
    exposuresUsed: v.number(),
    status: v.union(v.literal("joined"), v.literal("left"), v.literal("removed"), v.literal("deleted")),
    joinedAt: v.number(),
    leftAt: v.optional(v.number()),
    removedAt: v.optional(v.number()),
    // Withdraw Before Reveal (V2-FR-50): every exposure up to this number is gone for good, so a picture of it that
    // arrives later is refused.
    withdrawnThrough: v.optional(v.number()),
  })
    .index("by_event", ["eventId"])
    .index("by_event_and_account", ["eventId", "accountId"])
    .index("by_event_and_guest_identity", ["eventId", "guestIdentityId"])
    .index("by_account", ["accountId"])
    .index("by_guest_identity", ["guestIdentityId"]),

  // Event, shooter, exposure number, capture time, upload and seal state, size, checksum, storage key, and the smaller
  // viewing copy the phone makes (section 9.4). The pictures themselves are in Cloudflare R2. A removed picture keeps
  // only its number and its place in capture order, for the album's numbered gap.
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
    // CRC-32 of the file, computed by the server when it confirms the upload, for the web album's download (Stage 3).
    crc32: v.optional(v.number()),
    // The viewing copy, a smaller JPEG the phone made from the developed picture.
    viewSize: v.optional(v.number()),
    viewSha256: v.optional(v.string()),
    viewStorageKey: v.optional(v.string()),
    requestedAt: v.number(),
    storedAt: v.optional(v.number()),
    removedAt: v.optional(v.number()),
    // Whether it was ever stored: only those take a place in the album, and leave a numbered gap when removed.
    everStored: v.optional(v.boolean()),
    // Who removed it, for the record support keeps: its shooter, the Host, support, or a deletion.
    removedBy: v.optional(
      v.union(
        v.literal("shooter"),
        v.literal("host"),
        v.literal("support"),
        v.literal("withdrawal"),
        v.literal("guestRemoved"),
        v.literal("deletion"),
      ),
    ),
  })
    .index("by_shooter_and_exposure", ["membershipId", "exposureNumber"])
    .index("by_event", ["eventId"])
    .index("by_event_and_state", ["eventId", "state"])
    .index("by_storage_key", ["storageKey"]),

  // A report of a picture (V2-FR-54): the picture, the reason, when, and which member reported, never shown to the
  // Host. It reaches the Host in the app and the support address through the operator's relay.
  reports: defineTable({
    eventId: v.id("events"),
    pictureId: v.id("pictures"),
    reporterMembershipId: v.id("memberships"),
    reason: reportReasonValidator,
    at: v.number(),
    deliveredAt: v.optional(v.number()),
    deliveryAttempts: v.number(),
    resolvedAt: v.optional(v.number()),
    resolution: v.optional(v.union(v.literal("removed"), v.literal("kept"))),
    // Ninety days after it is resolved, or the event's end if sooner (section 8).
    expiresAt: v.optional(v.number()),
  })
    .index("by_event", ["eventId"])
    .index("by_picture_and_reporter", ["pictureId", "reporterMembershipId"])
    .index("by_delivery", ["deliveredAt"])
    .index("by_resolution", ["resolvedAt"]),

  // R2 objects to delete. Deletion writes the marker (the picture's state) first and queues the object here, so a
  // failed storage call is retried and never forgotten.
  storageDeletions: defineTable({
    storageKey: v.string(),
    queuedAt: v.number(),
    attempts: v.number(),
    // When a drain may next take the row: when it is queued, while a drain holds it, and after a failure's backoff.
    nextAttemptAt: v.number(),
  })
    .index("by_storage_key", ["storageKey"])
    .index("by_next_attempt", ["nextAttemptAt"]),
});
