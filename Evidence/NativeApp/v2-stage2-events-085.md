# 085 - v2 Stage 2: Group Films in the full app, with free Rolls only

This record covers the software of the [v2 PRD](../../2026-09-29-film-camera-experience-v1/2026-11-22-film-camera-experience-v2-prd.md)'s Stage 2, "Events in the full app, with free Rolls only" (section 12), built on Stage 1 ([084](v2-stage1-backend-084.md)).
The captain asked for it on 2026-11-23 ("immerse - start stage 2, support 48hrs"), ahead of Stage 1's proofs on the real services, and answered OQ-12 in the same words.

**Stage 2 is not proved.**
Everything below runs against local stand-ins: Convex's open-source backend and convex-test, MinIO for R2, and test doubles at the Clerk, Apple push and support-relay boundaries.
No account, deployment, bucket, key or certificate was created.
The PRD says compile-only or simulator evidence is not a pass; the whole event on real iPhones, every section 7 case on them, and the real cost of an event are section S of [the manual validation plan](manual-validation.md), all **UNTESTED: physical execution deferred, no real service provisioned**.

## What was built

| PRD | Server (`Backend/convex`) | iPhone |
| --- | --- | --- |
| Load Film with an optional later Start Time, the limits (V2-FR-10 to V2-FR-14, V2-FR-26) | `hosting:create`, with the request id that makes a repeated Load Film one event | `GroupFilmLoadView`: title, the three photo Cameras with their Camera Preview, the 6×6's Film Stock for everyone, Rolls, Start Time, End Time, Reveal Delay, the sharing rule, a confirmation that names the Camera Lock |
| The Join Code, its link and QR code, pausing and replacing it (V2-FR-15 to V2-FR-18) | `lib/joinCode.ts`, `hosting:setJoiningPaused`, `hosting:replaceJoinCode`, `joining:preview` with V2-FR-18's cases | `JoinCodeCard` (CoreImage QR code, share sheet), the link opening the app as a universal link (`onOpenURL`, `onContinueUserActivity`), `JoinConfirmationView` with each case's words |
| Joining, Rolls, free Rolls only (V2-FR-21 to V2-FR-28, V2-FR-62) | `joining:join`, `rolls.ts` (everyone's free Rolls once ever, set-asides, returns and lapses) | A name and one tap; the Roll's local Film in a store of its own |
| Shooting offline, Development on the phone, the upload queue (V2-FR-30 to V2-FR-36) | `pictures.ts` with the viewing copy, Withdraw Before Reveal's marker | `GroupFilms` (Development one picture at a time while on the screen, `EventPictureDevelopment`, `UploadQueue`, originals deleted on confirmation) and the shooting screen stopping at the End Time |
| Sealing, the timed reveal, ending early, the album, saving (V2-FR-37 to V2-FR-45) | `schedule.ts`, `lib/phase.ts`, `reads:album` | `GroupAlbumSection` (the reveal ritual once, the grid with numbered gaps, details, saving one picture or the whole album, resumable) |
| Withdraw Before Reveal, removals, removing a guest, reporting, deleting the event, leaving and rejoining (V2-FR-50 to V2-FR-56) | `joining.ts`, `hosting.ts`, `reports.ts`, `support.ts` | The event page's member and Host controls, each behind its warning |
| Claim and Delete Guest Identity (V2-FR-04, V2-FR-57), which section 7's cases need | `identities.ts` | "Keep My Place with My Account", Delete Guest Identity in Settings |
| The alert (V2-FR-70) | `alerts.ts`, once per event, to the Host and every member who may see the album | Asked once after Load Film or joining; a tap opens the event once the server says the person may see it |
| The 12-month end and its notices (V2-FR-48) | The album's end scheduled at the reveal, the purge, the notices read from the times | The notice on the event's page |
| A deleted Host's events (V2-FR-06) | Runs on with no Host; unclaimed Rolls lapse; reports go to support alone | "The Host has left Immerse" |
| OQ-12 | Reports posted, signed, to the operator's relay; `support:openReports` lists those past 48 hours | The support address in Settings and the report sheet, from configuration |

Personal Films, the Trial and the subscription are unchanged.
An event Roll is a Film with its own access kind (`FilmAccess.groupRoll`), kept in the Group Films' own store under `Application Support/GroupFilms`, whose Trial store refuses every use (`NoTrialStore`), so a Roll can never start, use or block the Trial (V2-FR-07).
The only changes to code personal Films run are additive and guarded: the shooting screen and the photo view read an environment value that is nil for every personal Film, the Instant's originals question returns nothing for an event Roll, and the two FilmPersistence methods that delete an event Roll's media refuse a personal Film.
A build without the server configuration file shows none of it.

## Choices this stage made

Each is a proposed engineering approach of PRD section 9 or a gap the PRD leaves to engineering; none changes a product rule.

- **The Join Code is derived and stored only as a verifier.** Section 8 says the code is stored as a verifier, but the Host needs the current code on any iPhone they sign in on. The code is the first 128 bits of an HMAC of the event's id and the code's generation under `JOIN_CODE_SECRET`; the database keeps SHA-256 verifiers of every generation, so a replaced code is told apart from one that never existed. A database leak gives no code. The secret must never change once events exist (`Backend/SETUP.md`).
- **Every rule reads the event's state from its times.** `lib/phase.ts` derives scheduled, open, ended, revealed and gone from the Start Time, End Time, reveal time and album end; the scheduled steps only do what comes with each change. A step that runs late never lets anyone join after the End Time, and never keeps an album sealed after its time. The reveal records when it ran (`revealedAt`) beside when it was due (`revealsAt`), for M-3.
- **A removed picture keeps its capture time.** The album's numbered gap needs its place in capture order; the time names nobody. Its shooter's link stays as the marker that the exposure can never come back, as Stage 1 kept it.
- **Each picture develops through Development's own call.** `EventPictureDevelopment` renders a Disposable or 6×6 capture with `CaptureDevelopment` and the treatment Development assigns it, so it is byte for byte what the Roll's Development makes (`EventPictureDevelopmentTests`), and leaves the capture sealed. An Instant print develops at the camera, as in a personal Instant Film, and its print is read back. A Group Film picture and a personal one develop the same from the same original only when they share a Film's id, since each Film seeds its own grain; what is shared is the Development itself.
- **The phone uploads a viewing copy.** A JPEG of at most 1,600 pixels on its longest side, made with ImageIO and carrying no metadata but the color space and size ImageIO always writes (V2-FR-46); the album browses viewing copies and saving downloads the full picture.
- **Originals go at confirmation.** V2-FR-36 deletes an original once the server confirms its developed picture; the queue keeps its own copy of the developed picture until then, so a crash between developing and sending loses nothing (V2-FR-34).
- **No background mode is declared.** The full app sends what waits in the time iOS gives an app that leaves the screen (`beginBackgroundTask`), and sends the rest when opened, whenever the network returns, and every half minute while open. A background processing run would need `UIBackgroundModes` in every build's Info.plist, which a v1 build that never uses it should not declare (App Store guideline 2.5.4). M-1 counts pictures "taken on phones that came back online with the app opened", which this meets; a later stage can add the background run with a v2-only Info.plist.
- **Reports reach the support address through a relay the operator runs.** Convex has no mail service; it posts each report, signed with HMAC-SHA256, and retries until the relay accepts it. The relay and the support address are configuration (`Backend/SETUP.md`, step 5a). The report reasons are this build's default wording (sexual content, violence, harassment, privacy, something else), which the captain can change without touching the server's rules.
- **Free Rolls are credited at Account creation**, once ever, from `FREE_ROLLS_EVERYONE` (default 3, "about 3" in V2-FR-62); a subscriber's larger amount is `FREE_ROLLS_SUBSCRIBER`, which Stage 4 credits once Apple confirms the subscription.
- **Per-address rate limits on the Join Code are left to Stage 3's Worker.** The app calls Convex directly, whose functions do not see the caller's address; the code's 128 bits make guessing infeasible meanwhile (V2-FR-15's acceptance names both).
- **Delete Guest Identity and Claim Guest Identity are built here**, though section 12's Stage 2 list does not name them, because section 7's cases that Stage 2 proves ("A guest signs in to an Account that already holds a place in the same event", "A guest deletes their Account") need them.
- **The alert carries the event's id**, unseen, so a tap can open the event once the app has checked the person's access (V2-FR-70: "Opening it checks the person's current access before showing anything").

## What ran

All on a MacBook running macOS 26 with Xcode 26.5 and Node 24, on 2026-11-23.

| Suite | Result | What it holds |
| --- | --- | --- |
| `npm test --prefix Backend` (convex-test, MinIO) | 117 passed | Stage 1's 64, ported to the album, and 53 new: `events.test.ts` (Load Film, limits, free Rolls once, the Join Code, pausing, replacing, the last-Roll race, joining, the times and their rescheduling), `reveal.test.ts` (on fake timers: the opening, the end returning Rolls, the reveal on time, a late step, ending early, the notices, the 12-month end and purge, a deleted Host's event), `control.test.ts` (withdrawal, removals, removing a guest and the Account it was claimed into, reports through the signed relay and its retries, support, deleting the event, leaving and rejoining, claiming, Delete Guest Identity), `album.test.ts` (every route to a sealed picture, capture order, a late arrival, the alert) |
| `npm run test:local-backend --prefix Backend` | 11 passed | Stage 1's run, now with the phone's own Swift client joining as a guest and sending a picture with its viewing copy; and `stage2.test.ts`: a whole event on Convex's own backend whose real scheduler ended and revealed it with every client idle, 2 ms after its time, sent the alert through the HTTP/2 stand-in to the Host and a guest, took a guest's pictures shot "offline" after the reveal into the album in capture order, delivered a report to the relay, and removed the pictures from storage when the event was deleted |
| `swift test --package-path Packages/ImmerseServer` | 41 passed, 1 skipped | The event API, guest tokens replaced once when refused, the Join Code's link, the guest identity, the upload queue (a restart, capture order, failures that stay, a pass that stops offline, withdrawal, a half-written folder), the viewing copy in the upload path; the skipped test is the local-backend one, which the run above executes |
| `swift test` in FilmDomain, FilmPersistence, FilmRuntime (`EventPictureDevelopmentTests`) | passed | Each event picture is what the Roll's Development makes and leaves the Roll sealed; the Instant's is the print developed at the camera; a personal Film is refused; originals go and retired captures keep their exposure; the viewing copy is small and carries no identifying metadata |
| `ImmerseTests/GroupFilmsTests` (iPhone 17 Pro simulator, iOS 26.5) | 4 passed | A guest shoots offline through the real capture commit path; both pictures develop unseen and wait; nothing is lost offline; online each uploads and its original goes; offline withdrawal deletes what waits at once and tells the server later; a removed guest's phone deletes what waits; an event Roll never touches the Trial |
| `ImmerseUITests/GroupFilmUITests` | 3 passed | The Host loads a Group Film and gets its QR code and link at once; a guest opens the link and joins with a name and one tap with no sign-in; the revealed album shows its pictures in order with a numbered gap and each picture's shooter |
| `ImmerseUITests/HostingUITests`, `ImmerseTests/HostingSessionTests` | passed | Stage 1's sign-in and Delete Account, with the signed-in screen now Load Film |

The screen tests run against `DebugGroupFilms`, a Debug-only stand-in for the event functions, which `Scripts/verify-release-excludes-testing-unlock.sh` holds out of Release.

## OC-2: what one event costs (open check, section 10)

**Measured on the stand-ins.**
The Stage 2 end-to-end run counted, through a proxy in front of the R2 stand-in and a counter on every client call, for an event of three shooters with three pictures each and three members reading the album:

- Uploads: 2 Class A operations a picture (the picture and its viewing copy).
- Confirmation: 2 Class B operations a picture, since the server reads both objects back to check their size and checksum (Stage 1's choice, section 9.3).
- Reading: 1 Class B operation a picture for each member who browses the album (the viewing copy), and 1 more for each member who saves it (the full picture).
- Convex function calls: 5 a picture (`requestUpload` and its `reserveUpload`, `confirmUpload` and its `pictureToConfirm` and `markStored`), 2 for each album load (`album` and `albumEntries`), and a few dozen a member over an event's life for the link, joining, syncing and tokens.

The run's own totals were 18 Class A, 72 Class B and these client calls: `requestUpload` 9, `confirmUpload` 9, `reads:album` 6, `joining:preview` 3, `joining:join` 3, `guests:startSession` 3, `hosting:view` 2, `hosting:create` 1, and one each of the push registrations and the report.

**The model.**
Section 10's assumptions stand where nothing measured replaces them: every Roll taken and finished on the Disposable, a developed picture of 4 MB, every member saving every picture once, 12 months kept, allowances ignored.
Two numbers are new and still assumed: a viewing copy of 0.4 MB (a 1,600-pixel JPEG; unmeasured on a real photograph), and every member browsing the album once besides saving it.

| Event | Pictures | Stored (pictures and viewing copies) | R2 storage, 12 months | R2 Class A | R2 Class B | R2 total | Section 10's R2 estimate | Convex function calls |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 3 Rolls | 81 | 0.36 GB | $0.064 | 162, $0.001 | 810, $0.000 | about $0.07 | about $0.06 | about 600 |
| 25 Rolls | 675 | 2.97 GB | $0.535 | 1,350, $0.006 | 36,450, $0.013 | about $0.55 | about $0.50 | about 4,600 |
| 100 Rolls | 2,700 | 11.88 GB | $2.138 | 5,400, $0.024 | 550,800, $0.198 | about $2.36 | about $2.05 | about 18,000 |
| 200 Rolls | 5,400 | 23.76 GB | $4.277 | 10,800, $0.049 | 2,181,600, $0.785 | about $5.11 | about $4.30 | about 36,000 |

How the 200-Roll row is made: 5,400 × 4.4 MB = 23.76 GB × $0.015 × 12 = $4.28; 10,800 uploads × $4.50 per million = $0.05; (10,800 confirmation reads + 201 members × 5,400 × 2) × $0.36 per million = $0.79; egress free.

**Reading.**
The model lands within about a fifth of section 10's R2 estimate at every size, higher because it stores and reads the viewing copies and reads every upload back once; storage, not operations, is most of it.
Section 10's conclusion holds: with R2's free egress an event's pictures cost a few dollars at the 200-Roll limit, where Convex's file storage would cost hundreds.
Convex's function calls are small against the 25 million a month Professional includes (36,000 for a 200-Roll event); section 10 records no price past them.

**What only the real services can confirm.**
The real developed file sizes per Camera and their viewing copies on real photographs (no real full-size photograph exists in this repository; renders of synthetic scenes are not a measure), how often members browse and save, Convex's billed function calls (whether its meter counts each internal call an action makes, as this model does), the bandwidth and memory of the action that reads each upload back, Cloudflare's billed operations, and whether R2 storage is billed on these sizes.
Manual scenario S12 measures one real event against this table.

## What the stand-ins cannot show

Stage 1's list stands ([084](v2-stage1-backend-084.md)), and Stage 2 adds:

- **A whole event on real iPhones** (M-1, M-3, nobody seeing a picture before the reveal), shooting offline on a real camera, Development on a real phone's GPU, the upload queue over a real mobile connection, and a phone killed mid-upload: section S.
- **The universal link.** The associated domain and Apple's association file on a real host (`Backend/SETUP.md`, step 4); in the simulator the link was handed to the app by a Debug launch argument.
- **The alert on a real iPhone**, through Apple's real push service from Convex's hosted runtime, and its tap.
- **The support relay and the support address**, which are the operator's.
- **Saving to Photos** from the album on a real iPhone, a whole album of 1,000 pictures, and its resumption.
- **The 12-month end on Convex's cloud.** The tests check the step is scheduled 12 months after the reveal and does what it should when run.
- **Rate limits per address** on the Join Code (Stage 3).

## Remaining gaps

- Every Stage 2 proof: section S, S01 to S12.
- V2-ACC-04 (Stage 1) stays open: on Clerk's free plan a Host can be asked to sign in again during an event that runs past seven days from their sign-in.
- Background processing runs for the upload queue are left out of this stage (above); V2-FR-35's "where iOS allows it" is met by the time iOS gives an app leaving the screen.
- The mini-app, the join page and the web album are Stage 3; buying Rolls and the subscriber's free Rolls are Stage 4.
