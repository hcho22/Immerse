# 084 - v2 Stage 1: the backend and sign-in, on local stand-ins

Recorded 2026-11-23.
The captain approved the [v2 PRD](../../2026-09-29-film-camera-experience-v1/2026-11-22-film-camera-experience-v2-prd.md) and asked for its Stage 1, "The backend and sign-in" (section 12), ahead of the PRD's own line that v2 starts after v1 is on the App Store.
This record says what was built, what the automated tests showed against local stand-ins, how open checks OC-3, OC-4, OC-7, OC-8 and OC-9 read, and what stays unproved.

**Stage 1 is not proved.**
The PRD says each stage ends with what it proves on real iPhones and the real services, and that compile-only or simulator evidence is not a pass.
No real service is provisioned ([Backend/SETUP.md](../../Backend/SETUP.md) lists what to create), and no iPhone has run any of it.
The proofs are section V of [the manual validation plan](manual-validation.md), each **UNTESTED**.
OC-1, the mini-app's size, was measured by a separate investigation and is not part of this change.

## What was built

| Part | Where | PRD |
| --- | --- | --- |
| The Convex backend: the schema of section 8 for what Stage 1 needs, with every public function authorizing its caller on the server and every state change safe to repeat | `Backend/convex/` | V2-FR-80, V2-FR-81, section 8 |
| Clerk sign-in with Apple, Google and email, linked to Convex auth | `Backend/convex/auth.config.ts`, `App/Immerse/Sources/ClerkHostSignIn.swift` | V2-FR-01 |
| Hosting reachable only from Group Film under Start a Film, and only in a build with a server configuration | `GroupFilmGate.swift`, `HostingSetup.swift`, `Config/Server.xcconfig` | V2-FR-02 |
| The age 13-or-over confirmation | `GroupFilmGate.swift`, `Packages/ImmerseServer/.../AgeGate.swift`, `accounts:createAccount` | V2-FR-03, OC-9 |
| Delete Account, server-side and repeatable, from Settings in two taps | `Backend/convex/deletion.ts`, `clerk.ts`, `storageQueue.ts`, `http.ts`, `AccountSettings.swift` | V2-FR-05, V2-FR-06, section 9.8 |
| The private R2 upload path with one-time addresses, confirmed by size and checksum | `Backend/convex/pictures.ts`, `lib/storage.ts`, `PictureUploader.swift` | V2-FR-34, V2-FR-35, section 9.3, OC-3 |
| The guest token and the read grants | `Backend/convex/guests.ts`, `lib/callers.ts`, `reads.ts` | V2-FR-23, V2-FR-37, sections 9.2 and 9.4, OC-4 |
| The Convex-to-Apple push test | `Backend/convex/push.ts`, `lib/apns.ts`, `pushTokens.ts` | V2-FR-70, section 9.6, OC-7 |
| The session lifetime, built so either Clerk plan works | `HostingSession.swift` | V2-FR-08, OC-8 |
| Debug-only tools for the iPhone proofs: a stand-in server for screen tests and the Server checks screen | `DebugHosting.swift`, `ServerChecksView.swift` | - |

Personal Films, the Trial, the subscription, capture, Development and the renderer are unchanged.
A build without `App/Immerse/Config/Server.local.xcconfig`, which is every build from the repository alone, has no server: it shows nothing of Group Films, never configures Clerk and makes no network request.
Its Settings privacy paragraph is v1's; with a server, the paragraph says personal Films stay on the iPhone and only Group Film pictures, Guest Names and a Host's Account reach the server (V2-FR-74).

The app links Clerk's iOS SDK at 1.7.3, its `ClerkKit` product alone, which has no dependencies of its own.
It calls Convex through Convex's HTTP API rather than Convex's Swift client.
The separate OC-1 measurement found the Swift client's Rust core adds about 5.3 MB to the mini-app, leaving it inside the 15 MB limit either way; Stage 1 needs no live subscriptions, so it takes the smaller path, and `ServerFunctions` is the one interface every caller uses, so Stage 2 or 3 can put the Swift client behind it where live counts or the reveal's state are wanted.

## What the automated tests showed

All of it ran on this Mac against local stand-ins on 2026-11-23: MinIO (RELEASE.2025-10-15T17-29-55Z) for R2, Convex's open-source local backend (`precompiled-2026-11-21-cf39368`, checked by SHA-256), a Clerk issuer stand-in serving OpenID discovery and an RS256 JWKS, a stand-in for Clerk's Backend API, and an HTTP/2-only TLS stand-in for Apple's push service.

| Suite | Result | Covers |
| --- | --- | --- |
| `Backend/tests` (convex-test) | 61 passed | Accounts and the age confirmation, Delete Account, the upload path, sealing and read grants, guest tokens, push, the webhook |
| `Backend/local-backend` (Convex's own backend) | 7 passed | The same path end to end through the HTTP API, including the iPhone's Swift client |
| `Packages/ImmerseServer` | 24 passed, 1 skipped on its own (run by the end-to-end suite) | The HTTP client, Accounts, the uploader, the age rule, the configuration |
| `ImmerseTests/HostingSessionTests` | 7 passed | Staying signed in without a network, the Account made after sign-in, Delete Account signing out only once the server confirms |
| `ImmerseUITests/HostingUITests` | 5 passed, with three accessibility audits | No hosting without a server; personal Films never asking for sign-in; the age decline; sign-in, the Account and Delete Account in two taps; the server's privacy words |
| `Scripts/verify-release-excludes-testing-unlock.sh` | Passed | The stand-in server and Server checks are in Debug and absent from Release |

## OC-3: the iPhone upload path

**Reading: the path of section 9.3 works against an S3-compatible bucket, from the iPhone's own client; R2 itself is unproved.**

A Convex action signs a presigned PUT with aws4fetch, which runs in Convex's default runtime, for one unguessable key, valid for five minutes, with the content type and `x-amz-checksum-sha256` among its signed headers.
The app's `PictureUploader` sends the file with `URLSession.upload(for:fromFile:)` and asks the server to confirm; the server reads the object back, checks its size and SHA-256, and only then records it stored.
The end-to-end run sent a 4 MB file from the Swift client through Convex's own backend to MinIO and had it confirmed.

| Case | What happened |
| --- | --- |
| A picture-sized file (4 MB) | Stored and confirmed; the object reads back whole |
| A picture sent twice after a lost reply | Stored once; the second request is answered "stored" and sends nothing |
| A different picture for an exposure already stored | Refused (`exposureTaken`) |
| A different content type from the signed one | Storage refuses the PUT (403); confirmation reports the object missing |
| A body that does not match the signed checksum | Storage refuses the PUT; confirmation reports the object missing |
| An object of the wrong size or content at the key (storage that ignores the checksum header) | Confirmation reports `mismatch`, the object is deleted, the picture moves to a new key, and the next send is stored |
| An empty object at the key | Confirmation reports `mismatch` |
| An expired upload address | Storage refuses the PUT (403); asking again gives a fresh address that works |
| The app killed after the upload, before confirming | The next launch asks again (an address for the same key) and confirms it stored |
| The app killed before uploading | Confirmation reports the object missing; the next address is for the same key, and the send is stored |
| A picture taken after the End Time | Refused (`afterEndTime`); one taken before it still uploads after the End Time and after the reveal |
| Malformed requests (content type, size 0 or over 25 MB, a bad checksum, an exposure out of range) | Refused before anything is recorded |
| Nobody signed in, a session with no Account, an Account with no place, a bad guest token, another event's token, a removed guest | Each refused with its own code |
| A withdrawn or removed picture | Refused for good, at request and at confirmation |

What only R2 can show: whether R2 refuses a body that does not match the signed checksum (the confirmation catches it either way), how long a 4 MB upload takes over a poor mobile connection, and that a presigned address works on R2's S3 domain only (manual check V04).
The background upload of the full app (V2-FR-35) is Stage 2's: Stage 1's uploader runs while the app is open.

## OC-4: the guest identity, and whether a sealed picture can be read

**Reading: the guest token rides on an argument every guest function checks; every way found to read a sealed picture returned nothing; encryption with a reveal-released key is not needed for the promise, with one residual risk stated below for the captain.**

A guest identity is a random id and a 32-byte secret made on the phone; the server keeps only a SHA-256 verifier of the secret (`guestIdentities`).
In exchange for the secret, a guest holding a current place in an event gets a one-hour token for that event; the server keeps only the token's hash (`guestSessions`).
An unknown identity, a wrong secret and an identity with no place all get the same refusal, so the exchange reveals nothing.
The token is an argument rather than Convex's own authentication because that needs no second token issuer with its own keys, and because revoking a token is deleting its row: a removed guest's token stops at once, which a signed token valid until its expiry would not.

Every attempt below ran in `Backend/tests/sealing.test.ts`, before the reveal unless it says otherwise:

| Attempt | Result |
| --- | --- |
| Read addresses as the Host, the picture's own shooter and another guest | Refused (`sealed`), no address issued |
| The same after shooting ended, before the reveal | Refused (`sealed`) |
| The object's storage address alone, unsigned | 403 |
| Listing the bucket without credentials | 403 |
| The upload address used for GET or HEAD, with or without its signed headers | Refused (400 or 403), no picture returned |
| An address signed with the wrong secret | 403 |
| Credentials of another key pair | 403 |
| Another event's guest token, after the reveal | Refused (`guestTokenRefused`) |
| A signed-in person with no place in the event, after the reveal | Refused (`notAMember`) |
| An expired read address | 403 |
| A read address reused after its picture's guest was removed | 404: the object is deleted |
| A removed guest's token, and their secret for a new token | Refused |
| An expired guest token | Refused; the secret gives a new one |
| A gone or deleted event | Refused (`eventGone`) |
| Reading the database for the secret or the token | Neither is stored, only their hashes |

After the reveal, a member (the Host, a guest, a guest who left) gets a presigned GET for each stored picture, valid for one minute, and reads it whole.
A presigned address is a bearer address until it expires: a removed member who saved one can use it for up to a minute after removal, for pictures they were already allowed to see.
A removed picture's object is deleted, so its address stops at once.

**Encryption.**
Before the reveal, no read address exists for any picture, the bucket has no public access or domain, and the server's key is the only credential that reads it.
So a leaked storage address shows nothing; the only readers left are someone who has the R2 credentials, or Cloudflare.
A key held in Convex and released at the reveal would protect against the first alone, at the cost of a second secret per picture and an extra step on every phone that views the album.
This change does not add it: the promise of V2-FR-37 holds with the bucket private and no address issued, and a leak of the R2 credentials is a leak of a server secret, handled by revoking the token.
The captain may still want encryption as defense in depth against a leaked R2 credential; the read path keeps one place (`reads.ts`) where a key could be released, so adding it later changes no product rule.

## OC-7: push from Convex to Apple's service

**Reading: a Convex Node action sends over HTTP/2 with token-based authentication; no relay was needed on the stand-ins; the hosted runtime is unproved.**

Apple's service accepts only HTTP/2, and `fetch` in Convex's default runtime gives no way to require it, so the sender runs in Convex's Node runtime (`"use node"`), whose `node:http2` speaks it directly.
It signs an ES256 provider token with the `.p8` key, reuses it for 40 minutes (Apple refuses one refreshed more often than every 20 minutes or older than an hour), and sends the alert's real shape: the Film Title and "Your Film is ready", text only (V2-FR-70).
Tokens Apple rejects as gone (410 `Unregistered`, 400 `BadDeviceToken`) are deleted (section 8); other failures keep them.
The test is an internal function, `push:sendTestAlert`, run from the deployment, never from the app, since v2 has no push but the reveal's.
On the stand-in, which speaks HTTP/2 only, the request arrived as HTTP/2 with the right path, topic, push type and priority, and a provider token that verifies with the key's public half; this held from Convex's own local backend too.
Whether Convex's hosted Node runtime opens an HTTP/2 connection to `api.sandbox.push.apple.com` is manual check V05; if it cannot, the PRD's fallback is the smallest Cloudflare relay that can.

## OC-8: staying signed in for eight days

**Reading: on Clerk's free plan a Host is signed out seven days after signing in, whatever the app does; Clerk Pro's custom native session lifetime is needed; the app works with either and the eight-day check is written.**

Clerk's pricing page lists Hobby with a "Fixed, 7 day session lifetime" and Pro with "Set a maximum session duration, from 5 minutes to 10 years" (https://clerk.com/pricing, read 2026-11-23).
Clerk's session options say "Maximum lifetime is the duration after which a session expires regardless of the user's activity", and that on a paid plan "you can set a custom maximum lifetime for native sessions between 5 minutes and 10 years in production"; "A long native lifetime doesn't extend the lifetime of session tokens" (https://clerk.com/docs/guides/secure/session-options, read 2026-11-23).
Clerk's iOS SDK at 1.7.3 keeps the client credential in the Keychain (`clerkDeviceToken`, accessible after first unlock, this device only), refreshes the one-minute session token while the app is in the foreground and refreshes the client on foregrounding (`Sources/ClerkKit/Lifecycle/SessionPollingManager.swift`, `Core/ClerkRuntime.swift`); none of that moves a session's maximum lifetime.
So the SDK's refresh cannot carry a Host past seven days, and an event of seven days with a 24-hour delay needs Pro's native lifetime ([SETUP.md](../../Backend/SETUP.md) recommends 30 days).
The app does not depend on the choice: it keeps the Host signed in while Clerk holds a session, never signs anyone out for a lost network (`HostingSessionTests`), and asks for sign-in again only when Clerk's session has ended and the Host acts on hosting.
Development instances have every option free, so the check can run before paying; manual check V03 is the eight-day procedure.

## OC-9: how age 13 or over is confirmed

**Reading: a neutral age screen, the person's birth month and year, everywhere; Apple's Declared Age Range with a gate at 13 where iOS says the region's law requires it.**

Sources, read on 2026-11-23:

- Apple's guide to the Declared Age Range API (https://developer.apple.com/documentation/declaredagerange/requesting-people-share-their-age-range-with-your-app): `requestAgeRange(ageGates:)` from iOS 26.0; "the system presents a sheet that describes the data you're requesting and asks people to grant permission to share their age range"; "In some regulated regions, the system automatically provides the person's age range" and "they can't decline sharing"; `declinedSharing` comes back only in a nonregulated region; `isEligibleForAgeFeatures` (iOS 26.2) says whether the person is in such a region. The entitlement is `com.apple.developer.declared-age-range`.
- Apple's age assurance page for developers (https://developer.apple.com/support/age-assurance/): "developers are responsible for their own age restrictions"; "In regions where legally required, you need to check the age of the people using your app with the Declared Age Range API"; on App Review, "No, there are no changes to the App Review process."
- Apple's developer news of 2026-06-03 (https://developer.apple.com/news/?id=sg176nne): Texas's rules apply to new Texas accounts from 2026-06-04, and "Developers can request age category data for these Apple Accounts through the Declared Age Range API." Apple's support page of 2026-10-26 (https://support.apple.com/en-us/125666) lists Apple Account age checks in Australia, Brazil, Singapore, South Korea, the UK and the United States (Texas).
- The App Store Review Guidelines, last updated 2026-10-16 (https://developer.apple.com/app-store/review/guidelines/): 5.1.4(a) allows asking for a birthdate "only for the purpose of complying with these statutes"; no guideline requires the API or a particular age gate for creating an account.
- The FTC's COPPA FAQ, H.3 (https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions): "simply including a check box stating, 'I am over 12 years old'" is not a neutral age screen; a neutral one "allows a user freely to enter the month and year of birth", and a general-audience operator "may rely on the age information its users enter".

So the least intrusive way App Review accepts is the person's own declaration, made neutrally, with Apple's API only where the law makes it required, which is also where the person cannot decline it and so sees no extra question.
The app does that before any sign-in, so no Account, at Clerk or on the server, exists without the confirmation: where `isEligibleForAgeFeatures` answers yes within three seconds, it asks Declared Age Range with a gate at 13 (13 or over goes on, under 13 is refused); otherwise, or when the person does not share or the API is unavailable, it asks for the birth month and year with nothing chosen for them.
A month and year cannot say which day someone turns 13, so the rule counts a person as 13 from the month after their thirteenth birthday month (`AgeGate`).
The month and year stay on the iPhone; the server records only that age was confirmed, when, and how (`declaredAgeRange` or `birthMonthAndYear`).
A person who says they are under 13 is told they cannot sign in, can still join as a guest and use personal Films, and is not offered the question again for a day, as the FTC advises against a back button that asks again.
The choice is the captain's to confirm: what would change it is California's AB 1043 if it requires an age signal at launch (reported for 2027-01-01, not checked against the statute), Texas's parental-consent rules if counsel reads them to cover creating an account, or Apple adding the API to the guidelines.

## Records that Stage 2 extends

- Events and memberships are sketched: Stage 2 adds the Film Stock, the package and treatment versions, the Start Time, the Reveal Delay, Rolls, the joining state, the Join Code verifier and the web album switch, and replaces `proofs.ts` with Load Film, joining and the timed reveal.
- Reports (section 8) are Stage 2's; when they exist, Delete Account must also remove the deleted person as a reporter.
- Viewing copies (section 9.4) are uploaded beside each picture from Stage 2.
- A rate limit on the guest token exchange and on joining is Stage 2's (risk RK-V2-10).
- Delete Guest Identity (V2-FR-57) and Claim Guest Identity (V2-FR-04) are Stage 2's; Delete Account already removes the identities claimed into an Account.
