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
  | "pictureRemoved"
  // Only the event's Host may do this (V2-FR-11, section 4.2), and a deleted Host's event has none (V2-FR-06).
  | "notTheHost"
  // No event has this Join Code (V2-FR-15).
  | "unknownCode"
  // The Join Code was replaced; its link no longer works (V2-FR-17).
  | "codeReplaced"
  // The event opens at its Start Time; nobody can join or shoot before it (V2-FR-12).
  | "notYetOpen"
  // Joining is paused (V2-FR-16).
  | "joiningPaused"
  // Every Roll has been taken (V2-FR-24).
  | "rollsTaken"
  // The End Time has passed: nobody joins, and the Host changes no setup (V2-FR-12, V2-FR-24, V2-FR-27).
  | "shootingEnded"
  // The Host removed this person from this event; they can never take part in it again (V2-FR-24, V2-FR-53).
  | "removedFromEvent"
  // More than 200 Rolls in the event's life (V2-FR-26).
  | "rollLimit"
  // The Host's balance holds fewer Rolls than this needs (V2-FR-60, section 7).
  | "balanceTooLow"
  // This needs the reveal first: removing a picture, reporting one, or seeing the album (V2-FR-51 to V2-FR-54).
  | "notRevealed"
  // The event has revealed: Withdraw Before Reveal is over (V2-FR-50).
  | "alreadyRevealed"
  // The guest identity was claimed into another Account (V2-FR-04).
  | "identityClaimed";

export function refuse(code: RefusalCode, message?: string): never {
  throw new ConvexError({ code, message: message ?? code });
}
