# Setting up the real services for v2 Stages 1 and 2

This is the list of what the captain creates, in the order to create it, before Stages 1 and 2 can be proved on iPhones and the real services ([the v2 PRD](../2026-09-29-film-camera-experience-v1/2026-11-22-film-camera-experience-v2-prd.md), section 12).
Nothing in it has been created: no account, project, deployment, bucket, application, key or certificate exists for Immerse's server yet.
Every value below goes into the Convex deployment's environment or the untracked `App/Immerse/Config/Server.local.xcconfig`, never into the repository.
`Backend/.env.example` and `App/Immerse/Config/Server.local.xcconfig.example` hold placeholders only.

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
2. **The App ID's capabilities.**
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
5. The join page and web album Worker are Stage 3.
6. **The join host (Stage 2).** Choose the host a Group Film's link uses, a domain or subdomain the operator controls, such as `join.<the operator's domain>`; it is `IMMERSE_JOIN_HOST`.
   Until Stage 3's Worker serves the join page there, the host serves only Apple's association file, at `https://<join host>/.well-known/apple-app-site-association`, as JSON over HTTPS with no redirect:

   ```json
   { "applinks": { "details": [ { "appIDs": ["<team id>.com.immerse.FilmJournal"], "components": [ { "/": "/j/*" } ] } ] } }
   ```

   A Cloudflare Worker or Pages site on the operator's zone can serve it; Apple's CDN fetches it when the app is installed ([Apple: supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)).
   Until Stage 3, the link opened on a device without Immerse finds no page there; Stage 2's guests install the full app first.

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

`JOIN_CODE_SECRET` derives every event's Join Code (`convex/lib/joinCode.ts`); the database keeps only each code's verifier.
**Never change it once events exist**: every printed code and link would stop working.

`CLERK_API_URL`, `APNS_ORIGIN` and `APNS_CA_PEM` stay unset: only the tests set them, to point at stand-ins.

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
2. Build the Debug configuration from Xcode to each iPhone.
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

## What each value is

| Value | Where it goes | Secret | Comes from |
| --- | --- | --- | --- |
| `IMMERSE_CONVEX_URL` | `Server.local.xcconfig` | No | Convex, step 2 |
| `IMMERSE_CLERK_PUBLISHABLE_KEY` | `Server.local.xcconfig` | No (public by design, still kept out of the repository) | Clerk, step 3 |
| `IMMERSE_V2_ENTITLEMENTS` | `Server.local.xcconfig` | No | `Config/ImmerseV2.entitlements` |
| `IMMERSE_JOIN_HOST` | `Server.local.xcconfig` | No | The operator's domain, step 4 |
| `IMMERSE_SUPPORT_ADDRESS` | `Server.local.xcconfig` | No (published, still kept out of the repository) | The operator |
| `JOIN_CODE_SECRET` | Convex environment | Yes | Generated, step 5 |
| `SUPPORT_REPORT_WEBHOOK_URL` | Convex environment | No | The relay, step 5a |
| `SUPPORT_REPORT_WEBHOOK_SECRET` | Convex environment and the relay | Yes | Generated, step 5 |
| `FREE_ROLLS_EVERYONE`, `FREE_ROLLS_SUBSCRIBER` | Convex environment (optional) | No | The pricing decision (OC-5) |
| `CONVEX_DEPLOY_KEY` | The Mac's environment | Yes | Convex, step 2 |
| `CLERK_JWT_ISSUER_DOMAIN` | Convex environment | No | Clerk, step 3 |
| `CLERK_SECRET_KEY` | Convex environment | Yes | Clerk, step 3 |
| `CLERK_WEBHOOK_SECRET` | Convex environment | Yes | Clerk, step 3 |
| `R2_ENDPOINT`, `R2_BUCKET`, `R2_REGION` | Convex environment | No | Cloudflare, step 4 |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | Convex environment | Yes | Cloudflare, step 4 |
| `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_TOPIC` | Convex environment | No | Apple, step 1 |
| `APNS_PRIVATE_KEY` | Convex environment | Yes | Apple, step 1 |
