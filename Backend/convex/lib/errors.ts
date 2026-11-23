import { ConvexError } from "convex/values";

// Every refusal the server gives carries one of these codes in `ConvexError.data.code`, so the app can say the
// right thing without reading message text. A refusal never says more than the caller may know.
export type RefusalCode =
  // No valid Clerk session (V2-FR-01).
  | "unauthenticated"
  // A valid Clerk session with no Account yet: the app must confirm age 13 or over and create one (V2-FR-03).
  | "noAccount"
  // The Account is being deleted, or its Clerk user is still being deleted after Delete Account (V2-FR-05).
  | "accountDeleted"
  // The arguments are malformed: a name too long, a size out of range, a checksum of the wrong length.
  | "invalid"
  // The guest token is unknown, expired, or for another event (section 9.2).
  | "guestTokenRefused"
  // The caller holds no current place in this event, or was removed from it.
  | "notAMember"
  // The event is gone, deleted, or does not exist.
  | "eventGone"
  // The capture time is after the event's End Time (V2-FR-31).
  | "afterEndTime"
  // Pictures are sealed until the event reveals (V2-FR-37).
  | "sealed"
  // A different picture is already stored for this exposure.
  | "exposureTaken"
  // This picture was withdrawn or removed and can never come back (section 9.8).
  | "pictureRemoved";

export function refuse(code: RefusalCode, message?: string): never {
  throw new ConvexError({ code, message: message ?? code });
}
