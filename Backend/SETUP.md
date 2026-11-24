# Setting up the real services for v2 Stages 1 to 4

This is the list of what the captain creates, in the order to create it, before Stages 1 to 4 can be proved on iPhones and the real services ([the v2 PRD](../2026-09-29-film-camera-experience-v1/2026-11-22-film-camera-experience-v2-prd.md), section 12).
Nothing in it has been created: no account, project, deployment, bucket, application, key or certificate exists for Immerse's server yet.
Every value below goes into the Convex deployment's environment or the untracked `App/Immerse/Config/Server.local.xcconfig`, never into the repository.
`Backend/.env.example`, `App/Immerse/Config/Server.local.xcconfig.example` and `Backend/worker/wrangler.example.jsonc` hold placeholders only.
Stage 3 adds steps 1a (the App Clip's identifiers), 4a (the join page's Worker), the Worker's secret in step 5, the mini-app's lines in step 7 and step 9 (the App Clip experience); Stages 1 and 2 can be proved without them.
Stage 4 adds step 10 (App Store Connect: the Roll packs, the In-App Purchase key and the server notifications) and its values in step 5.
**Step 10 cannot start until the pricing decision (open check OC-5, with the v1 subscription's price, DEC-02) sets the packs, their sizes and prices, and the free amounts**: no number of it is in the repository, the app or the example configuration, which holds only placeholders that sell nothing.

Each step names the values it produces and where they go.
Where a vendor's dashboard has moved since 2026-11-22, the vendor's own page linked in the step is the authority.

## Before you start

1. **Clerk's plan: the free Hobby plan (open check OC-8, the captain's decision of 2026-11-23).**
   Clerk's Hobby plan fixes a session's maximum lifetime at seven days "regardless of activity", and its iOS SDK cannot extend that by refreshing.
   **On the free plan, a Host can be asked to sign in again during an event that runs past seven days from their sign-in** (an event of seven days plus a 24-hour reveal delay always does), so V2-FR-08 and success measure M-4 are not met for such events.
   The PRD's requirements are unchanged; this is a known gap of the chosen plan.
   The lifetime is a setting of the Clerk instance, not of the app or the server: the app never assumes it, and Clerk's SDK keeps refreshing the session while the app is in use.
   Moving to Clerk Pro later ($25 a month, or $20 billed yearly, as read on 2026-11-22), which sets a native session lifetime from 5 minutes to 10 years, is a change in Clerk's dashboard alone, with no code change; a lifetime of 30 days would cover every event.
   Manual check V03 shows the free plan's behavior at eight days.
2. **The pricing decision comes before Stage 4 (OC-5).**
   It sets how many Roll packs there are, how many Rolls each adds, the price of each, everyone's free Rolls (the server's default is the PRD's "about 3") and a subscriber's larger free amount.
   Until it is made, nothing is created in step 10, the server sells nothing (`purchases:catalog` lists no pack, and the app says Rolls are not on sale yet) and gives no subscriber's free Rolls, and Stage 4's sandbox and App Review proofs (section K of `Evidence/NativeApp/manual-validation.md`) cannot run.
3. **The App ID's capabilities.**
   The v2 build adds four capabilities to the existing App ID `com.immerse.FilmJournal`: Sign in with Apple, Push Notifications, Declared Age Range and Associated Domains.
   A build without the local configuration file signs with none of them, so v1 builds are unaffected until the configuration file is added on a Mac.

## 1. Apple Developer: capabilities and the push key

1. In Certificates, Identifiers & Profiles, open the App ID `com.immerse.FilmJournal` and enable **Sign in with Apple** (as a primary App ID), **Push Notifications**, **Declared Age Range** and **Associated Domains**.
   The app's v2 entitlements are in `App/Immerse/Config/ImmerseV2.entitlements`.
2. Under Keys, create one key with **Apple Push Notifications service (APNs)** enabled and download its `.p8` file once.
   It produces `APNS_KEY_ID` (the key's id), `APNS_PRIVATE_KEY` (the `.p8` file's text) and, from the membership page, `APNS_TEAM_ID`.
   `APNS_TOPIC` is the bundle identifier, `com.immerse.FilmJournal`.
   Keep the `.p8` file out of the repository and every shared folder.
3. Associated Domains carry a Group Film's link, `https://<join host>/j/<code>`, into the full app (V2-FR-15, V2-FR-19).
   The entitlement claims `applinks:<join host>` from the build setting `IMMERSE_JOIN_HOST` (step 7), and the join host serves Apple's association file (step 4, item 6).

## 1a. Apple Developer: the App Clip and the App Group (Stage 3)

The mini-app is an App Clip of the full app (V2-FR-19).
It needs identifiers of its own, which only the account's owner can create; nothing in the repository creates them.

1. Register an **App Group**, such as `group.<the operator's reverse domain>.immerse`; it is `IMMERSE_APP_GROUP`.
   The full app and the App Clip keep Group Films in its container, so a mini-app guest's place, Roll and pictures are there when the full app is installed.
2. Register the App Clip's App ID, `com.immerse.FilmJournal.Clip`, as an App Clip of `com.immerse.FilmJournal`, with **On Demand Install Capable** (Xcode's name for the App Clip capability), **Associated Domains** and **App Groups**, and add the App Group to it.
3. On the full app's App ID `com.immerse.FilmJournal`, enable **App Groups** and add the same group.
4. The entitlements are in the repository: `App/Immerse/Config/ImmerseClip.entitlements` for the App Clip (`appclips:<join host>`, the App Group, and its parent application), and `App/Immerse/Config/ImmerseV2WithClip.entitlements` for the full app when the App Clip is inside it (Stage 1 and 2's entitlements, `appclips:<join host>` beside `applinks:<join host>`, the App Group, and the App Clip it is associated with).
   The association between the two is what lets the full app read the guest identity the App Clip kept in the Keychain ([Apple: sharing data between your App Clip and your full app](https://developer.apple.com/documentation/appclip/sharing-data-between-your-app-clip-and-your-full-app)).
5. The App Clip links no sign-in SDK, asks for no notifications and has no in-app purchase; its Info.plist asks only for the camera.
6. Build the **ImmerseWithClip** scheme for the app with the App Clip inside it, which is what is archived for TestFlight and the App Store; the **Immerse** scheme stays the app alone, and the **ImmerseClip** scheme runs the App Clip by itself from Xcode with a link in `_XCAppClipURL`.
7. Before the first submission, read the App Clip's size from Xcode's App Thinning Size Report on a signed export (manual scenario J10); `Scripts/verify-app-clip-size.sh` holds the unsigned figure under its budget in CI.

## 2. Convex: the project and its deployment

1. Create a Convex account and a project for Immerse (https://www.convex.dev).
2. Note the development deployment's address, `https://<name>.convex.cloud`, which the app needs as `IMMERSE_CONVEX_URL`, and its site address, `https://<name>.convex.site`, which receives Clerk's webhook.
3. Create a deploy key for the deployment (Settings, Deploy Keys); it lets a Mac push the functions with `npx convex deploy` from `Backend/`.
   It is a secret: keep it in the Mac's environment as `CONVEX_DEPLOY_KEY`.
4. The functions are pushed in step 6, after the environment is set, because `auth.config.ts` reads `CLERK_JWT_ISSUER_DOMAIN` at push time.

## 3. Clerk: the application, its sign-in methods and the link to Convex

1. Create a Clerk account and an application for Immerse (https://clerk.com), on the free Hobby plan.
2. Under sign-in options, turn on **Email** with **Email verification code**, **Apple** and **Google**, and nothing else.
   Leave passwords off: the app signs in with codes only.
   Keep Clerk's automatic account linking on, so Apple and then Google with the same verified email reach the same Account (V2-FR-01).
3. Under Native applications, enable the Native API and register the iOS app with the Team ID and the bundle identifier `com.immerse.FilmJournal`, then add `com.immerse.FilmJournal://callback` to the allowlist for mobile SSO redirects, which Google's sign-in returns to ([Clerk's iOS quickstart](https://clerk.com/docs/ios/getting-started/quickstart)).
4. For Apple, follow [Clerk's Sign in with Apple guide for iOS](https://clerk.com/docs/ios/guides/configure/auth-strategies/sign-in-with-apple): the app sends Apple's identity token to Clerk, so the native flow needs the bundle identifier registered for Apple in Clerk.
5. For Google, create an OAuth client for the iOS app in Google Cloud and give its credentials to Clerk's Google connection, as Clerk's dashboard asks.
6. Under Sessions, leave the maximum session lifetime at the free plan's seven days ("Before you start", step 1); on Clerk Pro, this is where a longer native lifetime would be set.
7. Activate Clerk's **Convex integration** ([Convex's Clerk page](https://docs.convex.dev/auth/clerk)), which puts the `convex` audience on session tokens.
   It produces the issuer, the Frontend API URL such as `https://<instance>.clerk.accounts.dev`, which is `CLERK_JWT_ISSUER_DOMAIN`.
8. Copy the **publishable key** (`pk_test_...` or `pk_live_...`), which the app needs as `IMMERSE_CLERK_PUBLISHABLE_KEY`, and the **secret key** (`sk_...`), which is `CLERK_SECRET_KEY`.
   The secret key lets the server delete Clerk users during Delete Account; keep it only in the Convex environment.
9. Under Webhooks, add the endpoint `https://<name>.convex.site/clerk/webhook`, subscribed to `user.deleted` alone, and copy its signing secret (`whsec_...`), which is `CLERK_WEBHOOK_SECRET`.
10. Write the privacy policy's and the App Store age rating's 13-or-over rule before App Review (V2-FR-03); Clerk itself does not ask for an age.

## 4. Cloudflare: the private R2 bucket

1. Create a Cloudflare account, enable R2, and create a bucket, `immerse-pictures` (https://developers.cloudflare.com/r2/).
2. Leave public access off: no `r2.dev` address and no custom domain for the bucket.
   Pictures are read only through addresses Convex signs after a reveal (section 9.4).
3. No CORS rule is needed: the iPhone app is not a browser.
4. Create an R2 API token with **Object Read & Write** on this bucket alone.
   It produces `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY`; the account's S3 endpoint, `https://<account id>.r2.cloudflarestorage.com`, is `R2_ENDPOINT`.
   `R2_BUCKET` is `immerse-pictures` and `R2_REGION` is `auto`.
5. The join page and web album Worker are step 4a.
6. **The join host (Stage 2).** Choose the host a Group Film's link uses, a domain or subdomain the operator controls, such as `join.<the operator's domain>`; it is `IMMERSE_JOIN_HOST`.
   Until the Worker of step 4a serves the join page there, the host serves only Apple's association file, at `https://<join host>/.well-known/apple-app-site-association`, as JSON over HTTPS with no redirect:

   ```json
   { "applinks": { "details": [ { "appIDs": ["<team id>.com.immerse.FilmJournal"], "components": [ { "/": "/j/*" } ] } ] } }
   ```

   A Cloudflare Worker or Pages site on the operator's zone can serve it; Apple's CDN fetches it when the app is installed ([Apple: supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)).
   Until step 4a, the link opened on a device without Immerse finds no page there; Stage 2's guests install the full app first.

## 4a. Cloudflare: the join page and the web album (Stage 3)

The join host is served by one Worker, `Backend/worker` (V2-FR-15, V2-FR-18, V2-FR-47).
It shows what a link shows in a browser, the web album while the Host shares it, and Apple's association file, which it makes from its configuration and so replaces the hand-made file of step 4.
It holds no credential for the picture bucket: it asks the Convex deployment for every page and every picture, and Convex signs a one-minute read address for a picture only while its event is revealed and its web album is on.
The bucket of step 4 stays private, with no binding to the Worker.

1. Copy `Backend/worker/wrangler.example.jsonc` to `Backend/worker/wrangler.jsonc` (git ignores it) and fill it in: the join host as the route's custom domain, `CONVEX_SITE_URL` (the deployment's `https://<name>.convex.site` of step 2), `APPLE_TEAM_ID`, the two bundle identifiers, `SUPPORT_ADDRESS`, and `APP_STORE_ID` once the app has one (until then the page names no store and shows no App Clip card).
2. Generate the secret the Worker and the deployment share, set it on the deployment in step 5 as `WEB_GATEWAY_SECRET`, and give the same value to the Worker: `npx wrangler secret put WEB_GATEWAY_SECRET` from `Backend/worker`.
   Without it on both sides the Worker shows no event and no picture.
3. `ALBUM_PART_PICTURES` is how many pictures one part of the album's download holds.
   The Worker makes two requests of its own for each picture, so keep it under half of the plan's limit on subrequests: 20 on the free plan, up to 400 on a paid one.
4. The rate limit (`ratelimits` in the file) allows 60 link openings a minute from one address, which is where a Join Code could be guessed at (V2-FR-15, risk RK-V2-10); check its binding's current form against [Cloudflare's rate limiting binding page](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/).
5. Deploy from `Backend/worker` with `npx wrangler deploy`, logged in to the operator's Cloudflare account; `wrangler` is not a dependency of the repository.
6. Check `https://<join host>/.well-known/apple-app-site-association`: JSON, no redirect, naming `<team id>.com.immerse.FilmJournal` under `applinks` and `<team id>.com.immerse.FilmJournal.Clip` under `appclips`.
   Apple asks that the server allow the `AASA-Bot` and `CFNetwork` user agents; do not put a bot challenge on this path.
7. The page carries no preview image, because a link previews with the event's title only (V2-FR-15).
   Apple's page on [invocations from Messages](https://developer.apple.com/documentation/appclip/supporting-invocations-from-your-website-and-the-messages-app) asks for one before a link in Messages opens the App Clip directly; without it the link opens the join page, where the App Clip card shows.
   Adding a preview image would be the captain's choice, not a setting.

## 5. The Convex deployment's environment

From `Backend/`, with `CONVEX_DEPLOY_KEY` set, set every value from steps 1, 3 and 4:

```sh
npx convex env set CLERK_JWT_ISSUER_DOMAIN https://<instance>.clerk.accounts.dev
npx convex env set CLERK_SECRET_KEY <sk_...>
npx convex env set CLERK_WEBHOOK_SECRET <whsec_...>
npx convex env set R2_ENDPOINT https://<account id>.r2.cloudflarestorage.com
npx convex env set R2_BUCKET immerse-pictures
npx convex env set R2_ACCESS_KEY_ID <access key id>
npx convex env set R2_SECRET_ACCESS_KEY <secret access key>
npx convex env set R2_REGION auto
npx convex env set APNS_KEY_ID <key id>
npx convex env set APNS_TEAM_ID <team id>
npx convex env set APNS_TOPIC com.immerse.FilmJournal
npx convex env set -- APNS_PRIVATE_KEY "$(cat <path to the .p8 file>)"
```

Stage 2 adds the Join Code secret, the support relay of step 5a, and, if the captain sets them before the pricing decision, the free amounts:

```sh
npx convex env set JOIN_CODE_SECRET "$(openssl rand -base64 48)"
npx convex env set SUPPORT_REPORT_WEBHOOK_URL https://<the relay's address>
npx convex env set SUPPORT_REPORT_WEBHOOK_SECRET "$(openssl rand -hex 32)"
# Optional: everyone's once-ever free Rolls (default 3) and a subscriber's (Stage 4; default 0).
npx convex env set FREE_ROLLS_EVERYONE 3
```

Stage 3 adds the secret the join page's Worker proves itself with (step 4a); without it the deployment answers the Worker nothing:

```sh
npx convex env set WEB_GATEWAY_SECRET "$(openssl rand -base64 48)"
```

Stage 4 adds what the server needs to sell Rolls and confirm the subscription (step 10).
The packs and the subscriber's free Rolls are the pricing decision's (OC-5); never set them from the placeholders in `.env.example`, which the server refuses:

```sh
npx convex env set APPLE_BUNDLE_ID com.immerse.FilmJournal
npx convex env set APPLE_APP_APPLE_ID <the app's Apple ID, digits only>
npx convex env set APPLE_ENVIRONMENTS Sandbox              # the development deployment
npx convex env set APPLE_ENVIRONMENTS Production,Sandbox   # the production deployment, where App Review buys in the sandbox
npx convex env set APP_STORE_KEY_ID <the In-App Purchase key's id>
npx convex env set APP_STORE_ISSUER_ID <the issuer id>
npx convex env set -- APP_STORE_PRIVATE_KEY "$(cat <path to the In-App Purchase key's .p8 file>)"
npx convex env set ROLL_PACKS "<product id>:<Rolls>,<product id>:<Rolls>"   # one entry per pack, from OC-5
npx convex env set SUBSCRIPTION_PRODUCT_IDS "<monthly product id>,<yearly product id>"   # the v1 subscription (DEC-02)
npx convex env set FREE_ROLLS_SUBSCRIBER <a subscriber's free Rolls, from OC-5>
npx convex env set FREE_ROLLS_EVERYONE <everyone's free Rolls, from OC-5>
```

Until all of `APPLE_BUNDLE_ID`, `APPLE_ENVIRONMENTS`, the three `APP_STORE_*` values and `ROLL_PACKS` are set and well formed, the server sells nothing; until `SUBSCRIPTION_PRODUCT_IDS` and a `FREE_ROLLS_SUBSCRIBER` of 1 or more are set too, it links no subscription, so no subscriber's once-ever free Rolls are spent on a deployment that cannot give them.
`APPLE_APP_APPLE_ID` is needed before `APPLE_ENVIRONMENTS` names Production: a production notification must carry it.
`APPLE_ROOT_CA_PEM` and `APP_STORE_API_ORIGIN` stay unset: only the tests set them, to a certificate chain and an App Store Server API stand-in of their own; the server pins Apple Root CA - G3 itself (`convex/lib/appleSigned.ts`).
A pack's Rolls are fixed in each purchase's record when the server first sees it, so changing `ROLL_PACKS` later never changes what an earlier purchase credited or what its refund removes; a product taken out of `ROLL_PACKS` is no longer sold, and a purchase of it that the server has not yet seen waits, unfinished on the iPhone, until the product is named again.

`JOIN_CODE_SECRET` derives every event's Join Code (`convex/lib/joinCode.ts`); the database keeps only each code's verifier.
**Never change it once events exist**: every printed code and link would stop working.

`CLERK_API_URL`, `APNS_ORIGIN`, `APNS_CA_PEM`, `APPLE_ROOT_CA_PEM` and `APP_STORE_API_ORIGIN` stay unset: only the tests set them, to point at stand-ins.

## 5a. The support relay for reports (OQ-12)

A report reaches the Host in the app and Immerse's support address (V2-FR-54); the captain's answer to OQ-12 (2026-11-23) is that Immerse's operator answers support within 48 hours.
Convex posts each report, as JSON, to `SUPPORT_REPORT_WEBHOOK_URL`, signed with `SUPPORT_REPORT_WEBHOOK_SECRET` in the header `x-immerse-signature: sha256=<hex HMAC-SHA256 of the body>`, and retries until the relay answers 2xx.
The relay is any small endpoint the operator runs that checks the signature and forwards the report to the support address by email: for example a Cloudflare Worker with Email Routing's send binding, or an email provider's inbound webhook.
The body carries `type` (`picture.reported`), `reportId`, `eventId`, `eventTitle`, `hostLeft`, `pictureId`, `pictureState`, `reason`, `reportedAt` (milliseconds) and `reporter` (an opaque membership id, never a name).
The support address itself goes only into the relay and the app's `IMMERSE_SUPPORT_ADDRESS` (step 7), never into the repository.
Support answers from these commands, with the deployment's key:

```sh
npx convex run support:openReports           # open reports, oldest first, with "overdue" past 48 hours
npx convex run support:removePictureForSupport '{"pictureId": "<id>"}'
npx convex run support:keepPicture '{"pictureId": "<id>"}'
```

## 6. Push the functions

```sh
npm ci --prefix Backend
(cd Backend && npx convex deploy)
```

The push checks the schema and type-checks the functions.

## 7. The app's configuration on the Mac that builds for the iPhones

1. Copy `App/Immerse/Config/Server.local.xcconfig.example` to `App/Immerse/Config/Server.local.xcconfig` (git ignores it) and fill in `IMMERSE_CONVEX_URL` from step 2 (written `https:/$()/<name>.convex.cloud`, since xcconfig reads `//` as a comment), `IMMERSE_CLERK_PUBLISHABLE_KEY` from step 3, `IMMERSE_JOIN_HOST` from step 4, `IMMERSE_SUPPORT_ADDRESS` (the operator's support address), and `IMMERSE_V2_ENTITLEMENTS = Config/ImmerseV2.entitlements`.
2. For the mini-app (Stage 3), add `IMMERSE_APP_GROUP` from step 1a, `IMMERSE_CLIP_ENTITLEMENTS = Config/ImmerseClip.entitlements` and `IMMERSE_V2_WITH_CLIP_ENTITLEMENTS = Config/ImmerseV2WithClip.entitlements`, and build the **ImmerseWithClip** scheme.
   The App Clip reads the server's address, the join host, the support address and the App Group from the same file; it needs no Clerk key.
3. Build the Debug configuration from Xcode to each iPhone.
   With the file present, Start a Film offers **Host a Group Film**, Settings shows the Account section once signed in, and Settings > Debug testing shows **Server checks**.
   Without it, the app is exactly the v1 app.

## 8. The proof fixtures and the server's counts

Stage 1's proofs of the upload path and the push use internal fixtures that only the deployment's key can call; Stage 2's events are made in the app itself:

```sh
cd Backend
npx convex run proofs:createProofEvent '{"clerkUserId": "<the Host's Clerk user id>"}'
npx convex run proofs:accountIdForClerkUser '{"clerkUserId": "<the Host's Clerk user id>"}'
npx convex run proofs:revealProofEvent '{"eventId": "<the event id>"}'
npx convex run push:sendTestAlert '{"accountId": "<the account id>"}'
```

The Clerk user id is in Clerk's dashboard under Users once the Host has signed up.
Section V of `Evidence/NativeApp/manual-validation.md` says when to run each.

Stage 2's proofs read the server's own counts (PRD section 13), which name nobody:

```sh
npx convex run measures:eventMeasures '{"eventId": "<the event id>"}'   # reveal lateness (M-3), pictures and bytes (M-1, OC-2)
npx convex run measures:lateReveals '{"since": <milliseconds>}'
```

Section S of `Evidence/NativeApp/manual-validation.md` says when.

## 9. App Store Connect: the App Clip experience (Stage 3)

An App Clip opens from a link or a QR code only once a version of the app that holds it has passed App Review; until then, test iPhones open it through a local experience (manual plan, section J).

1. Upload a build of the **ImmerseWithClip** scheme; App Store Connect then shows the App Clip under the version.
2. Fill in the **default App Clip experience**: the card's title, subtitle, header image and call to action (Open).
3. Add one **advanced App Clip experience** with the invocation URL `https://<join host>/j/`.
   Apple matches invocation URLs by prefix, so this one experience covers every event's link, `https://<join host>/j/<code>`, and passes the whole link to the App Clip.
   The demo link cannot be used: it carries no parameters, so it could not say which event was scanned (the OC-1 record).
4. Read the domain's status in the build's App Clip section, which shows whether Apple could validate the association file of step 4a.
5. Set `APP_STORE_ID` in the Worker's configuration and deploy it again, so the join page shows the App Clip card and the App Store link.
6. In the review notes, say that the App Clip joins a photo event by its link with a name only, that everything it does the full app does, and that it has no purchase, no sign-in and no advertising (guideline 2.5.16).
7. App Clips are not offered to an Apple Account of a child under 13 or with Ask to Buy on; those guests install the full app, which the join page tells them.

## 10. App Store Connect: the Roll packs, the In-App Purchase key and the server notifications (Stage 4)

Rolls are consumable in-app purchases bought in the full app into the Host's balance on the server (V2-FR-60, V2-FR-61).
The app holds no product, size, price or free amount: it asks the server what is on sale (`purchases:catalog`) and the App Store for each pack's price (V2-FR-64).
**Start this step only after the pricing decision (OC-5).**

1. **The Roll packs.** Under the app's In-App Purchases, create one **Consumable** for each pack the pricing decision names: a product identifier such as `com.immerse.FilmJournal.rolls.<pack name>`, a reference name, the price the decision chose, and a display name and description that say how many Rolls it adds (for example "<n> Rolls", one Roll for each guest).
   Add the review screenshot App Store Connect asks for, from the Rolls sheet of a Debug build.
   Set the same identifiers and Roll counts on the deployment as `ROLL_PACKS` (step 5); the server sells only what both name, and a pack's display name must agree with its count there.
2. **The subscriber's free Rolls.** Set `FREE_ROLLS_SUBSCRIBER` from the pricing decision and `SUBSCRIPTION_PRODUCT_IDS` to the v1 subscription's monthly and yearly product identifiers (DEC-02).
   The app sends the subscription only where its own build knows those identifiers, as v1's subscription screens do (`SubscriptionController.bundleConfiguration`, the Info.plist keys `ImmerseMonthlyProductID` and `ImmerseYearlyProductID`), so a build without them sends nothing.
   The server confirms the subscription with Apple's App Store Server API before it credits anything, and a subscription's free Rolls go to one Account, once ever; moving them to another Account is support's (V2-FR-63): after checking with the person, support moves the row of `subscriptionLinks` from the dashboard, which no app or public function can do.
3. **The In-App Purchase key.** Under Users and Access, Integrations, In-App Purchase, generate a key and download its `.p8` file once.
   It produces `APP_STORE_KEY_ID`, `APP_STORE_PRIVATE_KEY` (the file's text) and, from the same page, `APP_STORE_ISSUER_ID`.
   The server signs a five-minute token with it for each question it asks Apple: Get Transaction Info before crediting a purchase, and Get All Subscription Statuses before giving a subscriber's free Rolls.
   Keep the `.p8` file out of the repository and every shared folder.
4. **The app's Apple ID.** Under App Information, copy the Apple ID (digits only); it is `APPLE_APP_APPLE_ID`.
5. **App Store Server Notifications.** Under App Information, App Store Server Notifications, set **Version 2** and the URLs:
   - Production Server URL: `https://<the production deployment>.convex.site/apple/notifications`
   - Sandbox Server URL: `https://<the development deployment>.convex.site/apple/notifications` while Stage 4 is proved there, or the production deployment's while App Review buys against it
   Apple posts a signed payload there for each Roll purchase (`ONE_TIME_CHARGE`, which credits an Ask to Buy approved later or a purchase whose app never reported it), each refund (`REFUND`) and each reversal (`REFUND_REVERSED`) (V2-FR-65); the server applies only what Apple signed, and answers anything else with an error, which changes nothing.
   Use App Store Connect's or the App Store Server API's request for a test notification once the URL is set: the deployment's logs show it answered 200 (`handled: "test"`).
6. **Sandbox testers.** Under Users and Access, Sandbox, create the sandbox Apple Accounts section K of the manual plan needs.
   A purchase in the sandbox credits real Rolls on whichever deployment accepts `Sandbox`; on the production deployment that is what lets App Review and TestFlight buy, at no charge to them.
7. **App Review notes**, with the build: Group Films need an Account only to host; Rolls are consumables held on the server against the Account and restored by signing in, not by StoreKit's restore (guideline 3.1.1), and they never expire; every Account gets a small number of free Rolls once, and an Account linked to the v1 subscription a larger number once, after the server confirms the subscription with Apple; hosting needs no subscription; the App Clip sells nothing (guideline 2.5.16); Delete Account is in Settings, two taps from the Journal (guideline 5.1.1(v)); and the user-generated content answers of PRD section 11.4.
   Give App Review a sandbox account and the steps to reach the Rolls sheet (Settings, Rolls) and to buy a pack.

## What each value is

| Value | Where it goes | Secret | Comes from |
| --- | --- | --- | --- |
| `IMMERSE_CONVEX_URL` | `Server.local.xcconfig` | No | Convex, step 2 |
| `IMMERSE_CLERK_PUBLISHABLE_KEY` | `Server.local.xcconfig` | No (public by design, still kept out of the repository) | Clerk, step 3 |
| `IMMERSE_V2_ENTITLEMENTS` | `Server.local.xcconfig` | No | `Config/ImmerseV2.entitlements` |
| `IMMERSE_JOIN_HOST` | `Server.local.xcconfig` | No | The operator's domain, step 4 |
| `IMMERSE_SUPPORT_ADDRESS` | `Server.local.xcconfig` | No (published, still kept out of the repository) | The operator |
| `IMMERSE_APP_GROUP` | `Server.local.xcconfig` | No | Apple, step 1a |
| `IMMERSE_CLIP_ENTITLEMENTS`, `IMMERSE_V2_WITH_CLIP_ENTITLEMENTS` | `Server.local.xcconfig` | No | `Config/ImmerseClip.entitlements`, `Config/ImmerseV2WithClip.entitlements` |
| `WEB_GATEWAY_SECRET` | Convex environment and the Worker's secret | Yes | Generated, steps 4a and 5 |
| `CONVEX_SITE_URL`, `APPLE_TEAM_ID`, `APP_BUNDLE_ID`, `APP_CLIP_BUNDLE_ID`, `APP_STORE_ID`, `SUPPORT_ADDRESS`, `ALBUM_PART_PICTURES` | `Backend/worker/wrangler.jsonc` | No | Convex, Apple and the operator, step 4a |
| `JOIN_CODE_SECRET` | Convex environment | Yes | Generated, step 5 |
| `SUPPORT_REPORT_WEBHOOK_URL` | Convex environment | No | The relay, step 5a |
| `SUPPORT_REPORT_WEBHOOK_SECRET` | Convex environment and the relay | Yes | Generated, step 5 |
| `FREE_ROLLS_EVERYONE`, `FREE_ROLLS_SUBSCRIBER` | Convex environment (`FREE_ROLLS_SUBSCRIBER` needed for the subscriber's free Rolls) | No | The pricing decision (OC-5) |
| `ROLL_PACKS` | Convex environment | No | The pricing decision (OC-5) and the products of step 10 |
| `SUBSCRIPTION_PRODUCT_IDS` | Convex environment | No | The v1 subscription's products (DEC-02), step 10 |
| `APPLE_BUNDLE_ID`, `APPLE_APP_APPLE_ID`, `APPLE_ENVIRONMENTS` | Convex environment | No | App Store Connect, step 10 |
| `APP_STORE_KEY_ID`, `APP_STORE_ISSUER_ID` | Convex environment | No | App Store Connect's In-App Purchase key, step 10 |
| `APP_STORE_PRIVATE_KEY` | Convex environment | Yes | App Store Connect's In-App Purchase key, step 10 |
| `CONVEX_DEPLOY_KEY` | The Mac's environment | Yes | Convex, step 2 |
| `CLERK_JWT_ISSUER_DOMAIN` | Convex environment | No | Clerk, step 3 |
| `CLERK_SECRET_KEY` | Convex environment | Yes | Clerk, step 3 |
| `CLERK_WEBHOOK_SECRET` | Convex environment | Yes | Clerk, step 3 |
| `R2_ENDPOINT`, `R2_BUCKET`, `R2_REGION` | Convex environment | No | Cloudflare, step 4 |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | Convex environment | Yes | Cloudflare, step 4 |
| `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_TOPIC` | Convex environment | No | Apple, step 1 |
| `APNS_PRIVATE_KEY` | Convex environment | Yes | Apple, step 1 |
