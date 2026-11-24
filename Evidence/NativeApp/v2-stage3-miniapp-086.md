# 086 - v2 Stage 3: the mini-app, the join page and the web album

This record covers the software of the [v2 PRD](../../2026-09-29-film-camera-experience-v1/2026-11-22-film-camera-experience-v2-prd.md)'s Stage 3, "The no-install mini-app and the join page" (section 12), built on Stage 1 ([084](v2-stage1-backend-084.md)) and Stage 2 ([085](v2-stage2-events-085.md)).
The captain asked for it on 2026-11-23 ("immerse - start stage 3"), ahead of the proofs of Stages 1 and 2 on the real services.
Open check OC-1 had found, the same day, that the mini-app fits Apple's size cap, so the mini-app is the primary path and the install-the-full-app fallback is not needed for size.

**Stage 3 is not proved.**
Everything below runs against local stand-ins and in the iOS simulator: Convex's open-source backend and convex-test, MinIO for R2, Cloudflare's own Workers runtime run locally, and a Debug stand-in for the server inside the apps.
No account, deployment, bucket, Worker, domain, DNS record, App ID, App Clip identifier, key or certificate was created.
The PRD says compile-only or simulator evidence is not a pass; the proofs on real iPhones, a real domain and the real services are section J of [the manual validation plan](manual-validation.md), all **UNTESTED: no iPhone, domain, App Clip identifier or real service provisioned**.

## What was built

| PRD | Server (`Backend`) | iPhone (`App/Immerse`, `Packages/ImmerseServer`) |
| --- | --- | --- |
| The mini-app (V2-FR-19, V2-FR-21, V2-FR-35, V2-FR-71) | Nothing new: the mini-app calls the same functions as the full app | The `ImmerseClip` App Clip target, which builds the full app's own Group Film code: `JoinConfirmationView`, `CaptureView`, `GroupFilms` (Development, the upload queue), `GroupFilmEventView`, `GroupAlbumSection`; `Clip/` holds only its entry point, its state and its root screen |
| The hand-off to the full app (V2-FR-19, V2-FR-04, V2-FR-23) | Nothing new: the server already answers a repeated join and a repeated picture as held | `GroupFilmsFolder` (the App Group folder both apps keep Group Films in), `KeychainGuestIdentityStore.miniApp`, each `LocalPlace` recording the guest identity that holds it, and the full app's mark on the folder |
| The join page and its messages (V2-FR-15, V2-FR-18, V2-FR-20) | `worker/` (a Cloudflare Worker), `convex/web.ts`, `convex/http.ts` | Nothing |
| The web album and its switch (V2-FR-47, V2-FR-48) | `hosting:setWebAlbum`, `web.ts`, the Worker's album, picture and download routes, each picture's CRC-32 kept at confirmation | The Host's switch on the event's page after the reveal, with its words |
| OC-6: saving in the mini-app (V2-FR-44) | Nothing | One picture at a time through the system's share sheet; the whole album in the full app or from the web album |
| The App Clip's size (OC-1, RK-V2-01) | Nothing | `Scripts/verify-app-clip-size.sh`, run by validation's new `mini-app` part |

Personal Films, the Trial, the subscription, capture and the renderer's looks are unchanged.
The app alone (the `Immerse` scheme, which every v1 build and every existing test uses) does not build, sign or carry the App Clip; `Scripts/verify-release-excludes-testing-unlock.sh` now also fails if the app alone carries one.
The edits to files personal Films run are compile-time only: three `#if !APPCLIP` regions keep two Debug settings rows and the alert's delegate out of the App Clip, and the app alone compiles them exactly as before.

## Choices this stage made

Each is a proposed engineering approach of PRD section 9 or a gap the PRD leaves to engineering; none changes a product rule.

- **The mini-app calls Convex's HTTP API with URLSession, not Convex's Swift client.**
  OC-1 measured the Swift client's Rust core at about 5.3 MB, more than the whole mini-app, which measures 4,494,156 bytes without it.
  The mini-app needs nothing the client would add: it reads the event when it opens, when the guest pulls to refresh and every half minute while pictures wait, as the full app does, and a guest's phone has no live count to watch.
  One client for both apps (`ConvexHTTPClient` behind `ServerFunctions`) also means one upload path and one set of tests.
- **Group Films live in the App Group folder the two apps share, in place.**
  Apple's way to hand an App Clip's data to its full app is a shared container ("Sharing data between your App Clip and your full app").
  The full app opens the folder the mini-app wrote rather than copying it, so there is no step that could stop halfway: nothing is lost and nothing is sent twice because nothing moves.
  A build with no App Group, which is every build without the server configuration, keeps its own folder as in Stage 2, and a build that gains the group moves that folder across once, by one rename.
- **The mini-app's guest identity is in its own Keychain item, which the full app reads.**
  Apple says not to keep secrets in the shared container, and that from iOS 15.4 "information that the App Clip stores in the keychain is accessible to its corresponding full app".
  It also keeps V2-FR-04's rule that an unsigned place is bound to the phone: the item is this device only and in no backup.
  The two apps use different Keychain items, as Apple advises, so neither overwrites the other's.
- **Each place records the guest identity that holds it.**
  A phone can hold two: one the full app made earlier, which survives its deletion in the Keychain, and one the mini-app made, which cannot read the first.
  The full app acts on each place as its own identity, joins new events with an identity it already holds rather than making a third, and never acts on a place as a stranger when its identity cannot be read: the pictures wait.
- **Only one app writes.**
  iOS gives every link to the full app once it is installed.
  The full app marks the shared folder when it starts, and a mini-app that is still open finds the mark, stops and shows "Continue in Immerse".
- **The app with the App Clip inside is a target of its own (`ImmerseWithClip`).**
  An App Clip needs its own App ID and provisioning profile, which nobody has made.
  Embedding it in the one app target would make every v1 device build try to sign it, and every test build compile it; `ui-flows` already runs 100 of its 110 minutes on CI.
  The two targets share one definition (an XcodeGen template), the same bundle identifier and the same name on the Home Screen.
- **In the mini-app, Take a Roll opens the shooting screen at once.**
  V2-FR-21 asks that the mini-app go from the link to the shooting screen with the name and one tap.
  The full app keeps Stage 2's step through the event's page.
- **The join page's Worker holds no credential for the picture bucket.**
  Section 9.4 proposes a Worker reading R2 through its binding.
  This Worker instead asks Convex for every page and every picture, and Convex signs a one-minute read address only while the event is revealed, its web album is on, the link's code is current and the picture is stored.
  So the rule is held in one place on the server (`web.ts`, beside `reads.ts`), a fault in the Worker cannot read a sealed picture, which is risk RK-V2-07, and the same path runs against the R2 stand-in in tests.
- **A read address never reaches a browser.**
  The Worker fetches the picture and passes its bytes on, with no caching.
  Switching the album off therefore stops the very next picture, also at an address a viewer copied earlier, rather than within the minute an address would have lived.
- **The album downloads as a ZIP, in parts.**
  The server keeps each picture's CRC-32 when it confirms the upload, having the bytes in hand, so the Worker writes each ZIP entry's header whole and passes the picture through without spending processor time on it.
  A part holds 20 pictures by default, since the Worker makes two requests of its own a picture and Cloudflare's free plan allows 50 a request; the number is configuration.
  File names are picture numbers; no Guest Name is written into the file (V2-FR-46).
- **The page previews with the title only.**
  It carries no preview image of any kind (V2-FR-15).
  Apple asks for one before a link tapped in Messages opens an App Clip directly, so such a link opens the join page, where the App Clip card shows; `Backend/SETUP.md` says so, and adding an image would be the captain's choice.
- **The per-address limit is on opening links.**
  Stage 2 left it to this Worker: 60 openings a minute from one address, through Cloudflare's rate limiting binding.
  Picture requests are not limited; a wrong code and a wrong picture give the same refusal, so they are no way to test codes.
- **Who is opening the link is read conservatively.**
  Safari's version follows iOS's, so a Safari before 26 is told to update.
  An iPhone whose iOS cannot be told, as inside another app's browser, is shown the way to join with the requirement, never refused.
  The page cannot see that an Apple Account is a child's or has Ask to Buy on, where Apple offers no App Clips, so every iPhone's page says what to do when no card shows: install Immerse and open the link again.

## OC-1 again: the App Clip's size

The figures below are of the commit this record was written with; the script prints the current ones on every run.
`Scripts/verify-app-clip-size.sh` archives the `ImmerseWithClip` scheme for devices in Release, unsigned, thins the archive with `ipatool`, the App Store thinning tool inside Xcode, and sums the files of `AppClips/ImmerseClip.app` in every variant, as the OC-1 investigation did.

| Variant | Uncompressed |
| --- | --- |
| `0cf19a6f...` (iPhones) | 4,494,156 bytes |
| `9245e4c4...` (other devices that run iPhone apps) | 4,494,156 bytes |
| universal | 4,494,156 bytes |

That is 30 percent of Apple's 15,000,000-byte cap, with 10,505,844 bytes to spare; compressed (`zip -9`) it is 1,895,016 bytes.
The executable is 3,864,504 bytes, the five Manrope fonts 488,036 and the asset catalog 134,984.
It is 0.84 MB above OC-1's scratch App Clip (3,649,290 bytes), which had no Group Film screens, upload queue or server client in it.
The script fails validation above a budget of 12,000,000 bytes, which leaves room for the signature and profile a real export adds (under 0.1 MB) and for growth; it also fails if the Release App Clip holds a Debug-only stand-in or a sign-in SDK.
The same figure from Xcode's App Thinning Size Report on a signed export needs the App Clip's provisioning profile and is manual scenario J10.

## OC-6: what the mini-app can save to Photos

**Reading: the mini-app cannot save to Photos itself, and does not try; it hands one picture at a time to the system's share sheet, and sends the guest to the full app or the web album for the whole album. What the share sheet's own Save Image does inside an App Clip on an iPhone is unproved.**

Apple's pages, read on 2026-11-23:

- "Choosing the right functionality for your App Clip" lists PhotoKit among the frameworks that "provide no functionality at runtime" in an App Clip, and says that for most of these "their APIs return values that indicate unavailability, empty data, or error codes at runtime".
- The same page: "To help protect user data, App Clips can't access ... Data from apps like Calendar, Contacts, Files, Health, Messages, Reminders, and Photos".
- No Apple page read says whether the share sheet's Save Image, which is the system's and not the app's, works when an App Clip presents it.

What was exercised here: the mini-app's own share sheet in the iOS 26.5 simulator, with a picture file from the album.
The sheet opened over the picture and offered Copy, Save Image, Assign to Contact and more ([screenshot](v2-stage3-miniapp-086/mini-app-share-sheet.png)).
The simulator runs the App Clip target as an ordinary app, so this shows the mini-app's path works and what iOS offers for a JPEG file, not what an App Clip is allowed on an iPhone.

So the mini-app is built not to depend on the answer:

- It never calls PhotoKit and never asks for Photos access; the full app's save code is compiled out of it.
- **Save** on a picture downloads the full picture, checks it against the album's checksum, and presents the share sheet with the file, after the once-only note that a saved copy cannot be recalled.
- It offers no whole-album save; it says the full app saves the whole album, and names the web album too while the Host shares it.
- Manual scenario J08 records exactly what the share sheet offers and saves in the App Clip on an iPhone; if Save Image is missing there, the guest still has the full app and the web album, and the mini-app's words change, not its design.

## OC-10: how long iOS keeps the mini-app's data

**Reading: Apple's documentation names no time. It is not answered here.**

Apple's App Clips page says "the system removes an App Clip from a device after a period of inactivity", and "Recommending your app to App Clip users" says "App Clips only remain on a device for a limited amount of time".
Neither says how long, or whether the shared container goes with it when no full app is installed.
So the mini-app's words promise no time: they say the pictures wait on this iPhone alone, that iOS can clear a mini-app that has not been used for a while, and that installing Immerse keeps the place and the pictures.
The guest identity is in the Keychain, apart from the container, so a guest whose mini-app was cleared may still be known when they come back through the link; the Join Confirmation now gives such a member their place back from the server instead of showing an event that is "no longer on this iPhone".
Manual scenario J11 measures it over days.

## What ran

All on a MacBook running macOS 26 with Xcode 26.5 and Node 24, on 2026-11-23.

| Suite | Result | What it holds |
| --- | --- | --- |
| `npm test --prefix Backend` (convex-test, MinIO) | 153 passed | Stages 1 and 2's tests, and 36 new: `web-album.test.ts` (the switch only after the reveal, only by the Host, kept as it was for a deleted Host's event; only the Worker may ask; each state of a link; no picture listed and no address signed before the reveal, with the switch off, after it is switched off again, for a removed picture, a removed guest's pictures, a replaced code, and a deleted or gone event) and `join-page.test.ts` (the Worker: each of V2-FR-18's messages, the route for an iPhone that can join and one that cannot be told, Apple's association file, no camera, upload or file picker, the title-only preview, the album in order with gaps, a picture's details, the ZIP whole and in parts, the next picture failing when the album is switched off, a download stopping mid-way, the album's end notice, the rate limit) |
| `npm run test:local-backend --prefix Backend` | 18 passed | Stages 1 and 2's runs, and `stage3.test.ts`: the Worker running in workerd through Miniflare, asking Convex's own backend over HTTP and reading pictures from MinIO; an iPhone, an Android phone and a computer at an open event; no picture before the reveal; the title alone after it with the album off; every picture, its details and the ZIP with it on; nothing again with it off; the rate limit; a Worker without the deployment's secret shown nothing; and the hand-off on the phone's own Swift client |
| `swift test --package-path Packages/ImmerseServer` | 52 passed, 3 skipped on their own (run by the suite above) | The mini-app's configuration with no sign-in key in it, the App Group as configuration, the shared folder, its one-time move and the full app's mark, the web album's switch as sent and read; the hand-off on the local backend is `HandOffServerTests` |
| `ImmerseTests/MiniAppHandOffTests` (iPhone 17 Pro simulator, iOS 26.5) | 7 passed | A guest joins and shoots in the mini-app's build of the code on a folder standing for the shared container, through the real capture commit path and Development; the full app then opens the folder with the mini-app's identity to read. The place, the Roll, the exposures left, the pictures not yet sent and the queue are there; each waiting picture is sent once and the two already sent are not sent again; a picture saved but not yet developed develops and goes; the same link finds the guest's own place; a new event uses the identity the phone holds; a place whose identity cannot be read waits instead of being refused |
| `ImmerseTests/GroupFilmsTests` | 6 passed | Stage 2's hosted tests on the reworked setup |
| `ImmerseClipUITests/MiniAppUITests` (the App Clip in the simulator) | 5 passed, with two accessibility audits | From the link to the shooting screen with a name and one tap and no sign-in; the words for paused, every Roll taken, not yet open, ended and no such event; opened with no link or another site's link; a waiting picture never called sent, with the request to keep the mini-app open; the revealed album with the invitation to install and one picture into the share sheet |
| `ImmerseUITests/GroupFilmUITests` | 4 passed | Stage 2's three, and the Host switching the web album on after the reveal and off again |
| The rest of `ImmerseTests`, StoreKit aside (it runs on the iOS 26.2 billing simulator, which this Mac does not have; CI runs it) | 157 hosted tests passed in all | v1's and Stages 1 and 2's hosted tests on the reworked setup |
| `Scripts/verify-release-excludes-testing-unlock.sh` | Passed | The Debug-only stand-ins absent from Release, and the app alone carrying no App Clip |
| `Scripts/verify-app-clip-size.sh` | Passed | 4,494,156 bytes in every variant, nothing Debug-only and no sign-in SDK in the Release App Clip |
| `python3 -m unittest discover -s Scripts/Tests` | 85 passed | The scripts' own tests, with the fifth part |

`HostingUITests` and `JournalFlowTests` were also run here, since they audit screens beside the ones this change touches: 10 of their 13 tests passed, and three failed a contrast audit on a row lying across the screen's bottom edge (a Settings permission row, and two notes on v1's Load screen).
The same three fail in the same way from `main`'s own tree (`eb432ea`) on the same simulator, so they are this Mac's simulator and not this change; CI passes them on `main`, and CI's run of this change is the check that counts.

The App Clip was opened in the simulator by its link through XCTest (`XCUIApplication.open`), which hands the link to the App Clip as it starts.
Xcode's `_XCAppClipURL`, which delivers the link as iOS does, is honoured only by Xcode's own Run action; the `ImmerseClip` scheme carries it for running by hand.
Screenshots of the mini-app from that run are in [v2-stage3-miniapp-086](v2-stage3-miniapp-086).

## The validation scenarios this change was held to

| Scenario | Result | Evidence |
| --- | --- | --- |
| The web album returns no picture before the reveal, when switched off, after switching off again, for a removed picture or a removed guest, or for a deleted or ended event | Passed on stand-ins | `web-album.test.ts`, `join-page.test.ts`, `local-backend/stage3.test.ts` |
| The join page: each cannot-join message and each can-join route | Passed on stand-ins | `join-page.test.ts`, `local-backend/stage3.test.ts` |
| The mini-app: joining with a name and one tap, offline shooting and queued upload, and the album | Passed in the simulator; shooting through the capture commit path rather than a camera | `MiniAppUITests`, `MiniAppHandOffTests`, `GroupFilmsTests` |
| The hand-off: place, Roll, unsent pictures and queue survive with no duplicate upload | Passed in the simulator and on the local backend, with the shared container and the Keychain stood in | `MiniAppHandOffTests`, `HandOffServerTests` |
| The thinned size against 15 MB | Passed: 4,494,156 bytes | `Scripts/verify-app-clip-size.sh` |
| v1 flows offline with no sign-in prompt | Unchanged: the app alone is built as before, and Stage 1's `HostingUITests` hold it | The `ui-flows` part |
| The printed-QR timing (M-2) | **Untested**: no iPhone, App Clip identifier or domain | J01 |
| The real hand-off | **Untested**: no iPhone or App Group | J03 |
| Android and a computer on a real domain | **Untested**: no domain or Worker | J05, J07 |
| Real Photos saving (OC-6) | **Untested**: no iPhone | J08 |

## Two faults found along the way, and fixed

- **The note before a first save could not show over a picture.**
  Stage 2 presented it from the album, under the picture's full-screen view, where nothing can be presented, so the first Save from a picture did nothing.
  The picture's own view now presents it (`SavedCopiesNote`); the mini-app's screen test saves a picture this way.
- **A member with no place on the phone was sent to an empty page.**
  The Join Confirmation's "Open the event" for someone the server knows as a member opened a page that said the event was not on this iPhone, when the phone had lost its copy (a reinstall; a mini-app iOS had cleared).
  It now asks the server for the place first, which joining again returns unchanged.

## What the stand-ins and the simulator cannot show

Stages 1 and 2's lists stand, and Stage 3 adds:

- **A scanned QR code opening the mini-app**, the App Clip card, and the time from scan to shooting screen (M-2): an App Clip opens from a real link only once Apple holds an approved build and the domain is associated.
- **The real hand-off**: the App Group container outliving the App Clip, the full app reading the App Clip's Keychain item, and iOS giving the link to the full app once it is installed. In the tests a folder and two identity stores stand in for them.
- **The mini-app on a real camera**, offline, and an App Clip being suspended with pictures waiting.
- **Real browsers**: Safari, Chrome and Firefox on an iPhone, an Android phone and a computer, the page in each one's own time zone, and saving from it.
- **Cloudflare itself**: the Worker on the join host, its limits on requests of its own, the rate limiting binding, and Apple fetching the association file from it.
- **What the share sheet saves from an App Clip on an iPhone** (OC-6), and **how long iOS keeps an unused mini-app** (OC-10).
- **App Review** of the App Clip and its experience.

## Remaining gaps

- Every Stage 3 proof: section J, J01 to J11.
- Stages 1 and 2's proofs stay open (sections V and S), and V2-ACC-04 with them.
- A link tapped in Messages opens the join page rather than the mini-app directly, because the page carries no preview image (above).
- Buying Rolls and the subscriber's free Rolls are Stage 4.
