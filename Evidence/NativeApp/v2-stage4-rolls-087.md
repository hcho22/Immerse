# 087 - v2 Stage 4: buying Rolls and the subscriber's free Rolls

This record covers the software of the [v2 PRD](../../2026-09-29-film-camera-experience-v1/2026-11-22-film-camera-experience-v2-prd.md)'s Stage 4, "Buying Rolls and the subscriber benefit" (section 12), built on Stage 1 ([084](v2-stage1-backend-084.md)), Stage 2 ([085](v2-stage2-events-085.md)) and Stage 3 ([086](v2-stage3-miniapp-086.md)).
The captain asked for it on 2026-11-24 ("immerse - implement stage 4"), ahead of the proofs of Stages 1 to 3 on the real services.

The PRD says the pricing decision sets the prices and free amounts before this stage starts (open check OC-5).
**OC-5 is still open**, with the v1 subscription's price (DEC-02).
So Stage 4 is built with no price, pack size or free amount anywhere in the app or the server's code (V2-FR-64): the server reads the packs, their Rolls and the free amounts from its deployment's configuration, the app reads each pack's price from the App Store, and the repository holds only placeholders, which the server refuses, so a deployment copied from `Backend/.env.example` sells nothing and links no subscription.
The synthetic packs of the local StoreKit file (`App/Immerse/Tests/Fixtures/LocalRolls.storekit`, 5 and 25 Rolls at $0.01 and $0.02) and of the Debug stand-in are test inputs, not proposed numbers.
OC-5 must be decided before App Store Connect's products are created and before the sandbox and App Review proofs.

**Stage 4 is not proved.**
Everything below runs against local stand-ins: convex-test and Convex's open-source backend, a stand-in for the App Store that signs with a certificate chain made for the run and answers the App Store Server API as Apple documents it, Apple's local StoreKit testing, and a Debug stand-in for the server and the store inside the app.
No product, in-app purchase, subscription group, key, sandbox tester, notification URL, account or deployment was created.
The proofs in Apple's sandbox, on real iPhones and by App Review are section K of [the manual validation plan](manual-validation.md), all **UNTESTED: pricing undecided (OC-5); no App Store Connect product, key, sandbox tester or real service provisioned**.

## What was built

| PRD | Server (`Backend`) | iPhone (`App/Immerse`, `Packages/ImmerseServer`) |
| --- | --- | --- |
| Roll packs through in-app purchase (V2-FR-60, V2-FR-64) | `purchases:catalog` from `ROLL_PACKS`; each Account's purchase token; `purchases:report` verifies the signed transaction against the pinned Apple Root CA - G3 (`lib/appleSigned.ts`), asks Get Transaction Info (`lib/appStoreApi.ts`) and credits the Account the token names, once (`purchases.ts`, `appStore.ts`) | `RollShop` with `StoreKitRollStore` (StoreKit 2, the token on every purchase, finished only once the server holds it), `RollsSheet` (`RollsView.swift`), `RollServer` |
| The balance (V2-FR-61, V2-FR-28) | The ledger of Stage 2 with purchases, refunds and reversals in it, and its history | The balance and its history on the Rolls sheet, and in Settings' Rolls row |
| Failed, pending and refunded purchases (V2-FR-65) | `/apple/notifications` (`http.ts`, `appStore.ts`): `ONE_TIME_CHARGE`, `REFUND` and `REFUND_REVERSED`, each applied only as Apple's API confirms the transaction; a balance below zero blocks new set-asides (`rolls.ts`) | Nothing added for a failure or a cancellation; Ask to Buy waits, and its Rolls arrive from StoreKit's updates or the server; a purchase not yet held by the server is reported again at launch; the words for each case in `RollShopCopy` |
| The subscriber's free Rolls (V2-FR-62, V2-FR-63) | `purchases:linkSubscription`: Get All Subscription Statuses, a link of one subscription to one Account in `subscriptionLinks`, the configured amount once ever | `RollShop.linkSubscriptionIfNeeded` sends the v1 subscription's signed transaction once a subscriber signs in, where the build knows the subscription's products |
| Where the Rolls sheet opens | Nothing | Load Film's set-aside, the Host's event page (adding Rolls) and Settings; the mini-app has none of it |
| Delete Account (V2-FR-05) | A deleted Account's purchases stay without it, and its subscription link loses its Account but stays (below) | Delete Account's words say the subscription's free Rolls are not given again |

Personal Films, the Trial, the v1 subscription and its entitlement, capture and the renderer's looks are unchanged.
The v1 subscription is only read: `RollShop` asks StoreKit for its current transaction and sends it to the server, and `SubscriptionController` still owns its own transactions; Roll purchases are consumables, which it never sees.
A build without a server configuration has no Rolls sheet, as it has no hosting.

## Choices this stage made

`Backend/README.md`, "Choices", lists each with its reason: Apple's signatures checked against a pinned root in one file rather than Apple's library; a purchase credited from Apple's current answer rather than from the app's copy; one record per Apple transaction made to agree with Apple's latest view, so a refund, a reversal and a late retry apply in Apple's order; the app account token naming the Account; the subscription confirmed by Apple's status; and nothing on sale until configured.
Each is a proposed engineering approach of PRD section 9 or a gap the PRD leaves to engineering.

Three more, on the iPhone:

- **The app finishes a Roll purchase only once the server holds it.** StoreKit keeps an unfinished transaction and offers it again at every launch, so a report lost to a dropped connection, a crash or a refusal is not lost; nothing is credited from the app's side alone.
- **A refund reaches the server from both sides.** Apple's `REFUND` notification is the PRD's path; the app also reports a revoked transaction from StoreKit's updates, which the server treats like any report and confirms with Apple.
- **The mini-app sells nothing.** The Rolls sheet, its shop and the Debug Roll store are left out of the App Clip's target (`project.yml`), as Apple's guideline 2.5.16 and the PRD's section 11 require.

## A reading for the captain

The PRD says Delete Account removes the Account's "link to a subscription" (V2-FR-05), that a subscriber's free Rolls are given once ever (V2-FR-62), and that one subscription feeds one Account (V2-FR-63).
Read together, the build keeps the subscription's row after Delete Account with no Account on it, as the record that its free Rolls were given, so a new Account presenting the same subscription gets none; nothing in the row names the person.
If the captain reads V2-FR-05 instead as letting a deleted subscriber's subscription feed a new Account, the row is deleted with the Account and the test `after Delete Account the subscription's Rolls do not come again to a new Account` changes; section K (K08) asks him.

## What ran

All on a MacBook running macOS 26 with Xcode 26.5 and Node 24, on 2026-11-24.

| Suite | Result | What it holds |
| --- | --- | --- |
| `npm run typecheck --prefix Backend` | Passed | |
| `npm test --prefix Backend` (convex-test, MinIO) | 14 files, 182 passed | Stages 1 to 3's tests, and Stage 4's: `purchases.test.ts` (20: the packs from configuration and placeholders refused, one token per Account, a purchase credited once however often it is reported and once when reported twice at once, to the Account its token names, Apple's current view deciding over the app's copy, nothing while Apple cannot be asked and the next report crediting, a consumable not on sale waiting, a forged, altered or foreign transaction refused, only the configured environments, the pinned root, an Ask to Buy credited from Apple's notification, a refund taking the balance below zero and blocking set-asides without touching an event, a refund before its purchase, a reversal, an unsigned, forged or foreign notification changing nothing, a notification Apple's API does not confirm changing nothing and waiting, a deleted Account's purchases, the same view applied twice writing one row), `subscriber.test.ts` (8: once ever after Apple's confirmation, a renewal or a second report adding none, a second Account getting none and not told which Account holds it, two Accounts at once with exactly one credited, nothing for an expired, retrying or refunded subscription, nothing further after a lapse or refund with the Rolls credited staying, one Account taking one subscriber's free Rolls, none again after Delete Account, only a signed-in Account with this app's subscription signed by Apple), and `deletion.test.ts`'s Stage 4 rows |
| `npm run test:local-backend --prefix Backend` | 4 files, 21 passed | Stages 1 to 3's runs, and `stage4.test.ts`: Convex's own backend checking Apple's signatures in its Node runtime and asking the App Store stand-in over HTTP; a purchase credited once, refunded by notification and reversed; the subscriber's free Rolls to one Account only; and the app's own Swift client buying, reporting and linking through the HTTP API (`LocalBackendRollTests`) |
| `swift test --package-path Packages/ImmerseServer` | 57 run, 1 skipped on its own (run by the suite above), none failed | `RollServerTests` (5): what is on sale, the token, each answer to a report, the link's answers and the history as the server sends them |
| `ImmerseTests/RollShopTests` (iPhone 17 Pro simulator, iOS 26.5) | 4 passed | A cancelled purchase changes nothing and says nothing; a signed-out buyer is asked to sign in and nothing is bought; a purchase the server refuses stays unfinished and names support; an active subscription is sent once for its free Rolls |
| `ImmerseTests/RollShopStoreKitTests` (Apple's local StoreKit testing) | **Not run here**: 5 tests | A bought pack carries the token, is credited once and finished only once the server holds it; one the server cannot confirm stays unfinished and is credited when the app runs again; Ask to Buy adds nothing until approved and nothing when declined; a failed purchase changes nothing; a refund reaches the server. They need StoreKit's local test session, which iOS 26.5 does not activate (Apple's known Code=3 issue); v1's `StoreKitSubscriptionTests` fail the same way on this Mac's iOS 26.5 simulator, and this Mac cannot download iOS 26.2. CI runs both on its iOS 26.2 billing simulator, and CI's run of this change is the check that counts |
| `ImmerseUITests/RollsUITests` | 4 passed | The Host buys a pack and sees the balance and its history; Ask to Buy waits and the Rolls arrive once approved; a failed purchase changes nothing; Load Film offers Rolls and says when none are on sale |
| `ImmerseUITests/HostingUITests`, `GroupFilmUITests` | 9 passed | Stages 1 to 3's screens beside the Rolls sheet: Settings' Account section, the Host's event page and Load Film |
| The rest of `ImmerseTests`, StoreKit aside (above) | 161 hosted tests passed in all | v1's and Stages 1 to 3's hosted tests, `RollShopTests` among them, on this change |
| `ImmerseClipUITests` (the App Clip in the simulator) | 6 passed | Stage 3's mini-app screens on the Group Film code this change touches, with nothing for sale in them |
| `python3 -m unittest discover -s Scripts/Tests` | 85 passed | The scripts' own tests |
| `Scripts/verify-release-excludes-testing-unlock.sh` | Passed | The Debug-only stand-ins, the Debug Roll store included, absent from Release |

Screenshots of the Rolls sheet from that run are in [v2-stage4-rolls-087](v2-stage4-rolls-087).

## The validation scenarios this change was held to

| Scenario | Result | Evidence |
| --- | --- | --- |
| One verified transaction credits once, delivered twice or concurrently | Passed on stand-ins | `purchases.test.ts`, `local-backend/stage4.test.ts` |
| A failed or cancelled purchase changes nothing | Passed on stand-ins and in the simulator | `RollShopTests`, `RollsUITests`, `RollShopStoreKitTests` (CI) |
| A pending purchase credits only on completion | Passed on stand-ins and in the simulator | `purchases.test.ts`, `RollsUITests`, `RollShopStoreKitTests` (CI) |
| A refund removes the Rolls without touching Rolls set aside or taken, may take the balance below zero and blocks new set-asides | Passed on stand-ins | `purchases.test.ts` |
| A reversal adds them back | Passed on stand-ins | `purchases.test.ts`, `local-backend/stage4.test.ts` |
| An unsigned or forged notification changes nothing | Passed on stand-ins | `purchases.test.ts` |
| Subscriber Rolls only after confirmation, not to a second Account with the same subscription, nothing more after a lapse or refund | Passed on stand-ins | `subscriber.test.ts`, `local-backend/stage4.test.ts` |
| No price, pack size or free amount in the app | Held: the app reads packs from the server and prices from the App Store; the placeholders sell nothing | `purchases.test.ts`, `RollsUITests` (not on sale) |
| v1 flows offline with no sign-in | Unchanged: no v1 file changed beyond Settings' Rolls row, which shows only with a server configuration | `HostingUITests` (personal Films never ask for sign-in; a build with no server shows nothing of hosting) |
| A purchase in Apple's sandbox, credited once and removed by a real refund notification | **Untested**: pricing undecided, nothing provisioned | K01 to K06 |
| A real subscriber's free Rolls, and a second Account | **Untested**: nothing provisioned | K07, K08 |
| App Review | **Untested**: nothing submitted | K10 |

## What the stand-ins cannot show

Stages 1 to 3's lists stand, and Stage 4 adds:

- **Apple's real certificate chain** verifying against the pinned root, and what the sandbox's transactions and notifications actually carry.
- **The App Store Server API** answering with the real In-App Purchase key, in the sandbox and in production.
- **How the sandbox refunds a consumable**, how soon Apple sends `REFUND`, and whether the sandbox can send `REFUND_REVERSED` at all; the reversal is held here only by signed test fixtures.
- **Ask to Buy with a real family**, and StoreKit's real purchase sheet.
- **App Review** of the purchases, sign-in, Delete Account, the App Clip and the user-generated content features.

## Remaining gaps

- The pricing decision (OC-5, tracker V2-DEC-01), and with it every App Store Connect product of `Backend/SETUP.md` step 10.
- Every Stage 4 proof: section K, K01 to K10.
- `RollShopStoreKitTests` first runs on CI's iOS 26.2 billing simulator.
- The reading above on Delete Account and the subscription's link.
- Stages 1 to 3's proofs stay open (sections V, S and J).
