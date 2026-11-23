# Setting up the real services for v2 Stage 1

This is the list of what the captain creates, in the order to create it, before Stage 1 can be proved on iPhones and the real services ([the v2 PRD](../2026-09-29-film-camera-experience-v1/2026-11-22-film-camera-experience-v2-prd.md), section 12).
Nothing in it has been created: no account, project, deployment, bucket, application, key or certificate exists for Immerse's server yet.
Every value below goes into the Convex deployment's environment or the untracked `App/Immerse/Config/Server.local.xcconfig`, never into the repository.
`Backend/.env.example` and `App/Immerse/Config/Server.local.xcconfig.example` hold placeholders only.

Each step names the values it produces and where they go.
Where a vendor's dashboard has moved since 2026-11-22, the vendor's own page linked in the step is the authority.

## Before you start: two decisions

1. **Clerk's plan (open check OC-8).**
   Clerk's free Hobby plan fixes a session's maximum lifetime at seven days "regardless of activity", and its iOS SDK cannot extend that by refreshing; an event of seven days plus a 24-hour reveal delay outlasts it (V2-FR-08).
   Only a paid plan sets a longer maximum lifetime for native sessions ("between 5 minutes and 10 years in production").
   The recommendation is Clerk Pro ($25 a month, or $20 billed yearly, as read on 2026-11-22) with a native session lifetime of 30 days, so a Host who signs in when making an event is never asked again before its reveal.
   Development instances get every option free, so Stage 1 can be proved on a development instance before paying.
   The app works with either: it never assumes the lifetime, and the eight-day check (manual check V03) shows which one holds.
2. **The App ID's capabilities.**
   The v2 build adds three capabilities to the existing App ID `com.immerse.FilmJournal`: Sign in with Apple, Push Notifications and Declared Age Range.
   A build without the local configuration file signs with none of them, so v1 builds are unaffected until the configuration file is added on a Mac.

## 1. Apple Developer: capabilities and the push key

1. In Certificates, Identifiers & Profiles, open the App ID `com.immerse.FilmJournal` and enable **Sign in with Apple** (as a primary App ID), **Push Notifications** and **Declared Age Range**.
   The app's v2 entitlements are in `App/Immerse/Config/ImmerseV2.entitlements`.
2. Under Keys, create one key with **Apple Push Notifications service (APNs)** enabled and download its `.p8` file once.
   It produces `APNS_KEY_ID` (the key's id), `APNS_PRIVATE_KEY` (the `.p8` file's text) and, from the membership page, `APNS_TEAM_ID`.
   `APNS_TOPIC` is the bundle identifier, `com.immerse.FilmJournal`.
   Keep the `.p8` file out of the repository and every shared folder.
3. Associated Domains are not needed in Stage 1.
   They come with Stage 2's links that open the full app and Stage 3's App Clip, on the join page's own domain.

## 2. Convex: the project and its deployment

1. Create a Convex account and a project for Immerse (https://www.convex.dev).
2. Note the development deployment's address, `https://<name>.convex.cloud`, which the app needs as `IMMERSE_CONVEX_URL`, and its site address, `https://<name>.convex.site`, which receives Clerk's webhook.
3. Create a deploy key for the deployment (Settings, Deploy Keys); it lets a Mac push the functions with `npx convex deploy` from `Backend/`.
   It is a secret: keep it in the Mac's environment as `CONVEX_DEPLOY_KEY`.
4. The functions are pushed in step 6, after the environment is set, because `auth.config.ts` reads `CLERK_JWT_ISSUER_DOMAIN` at push time.

## 3. Clerk: the application, its sign-in methods and the link to Convex

1. Create a Clerk account and an application for Immerse (https://clerk.com), on the plan chosen above.
2. Under sign-in options, turn on **Email** with **Email verification code**, **Apple** and **Google**, and nothing else.
   Leave passwords off: the app signs in with codes only.
   Keep Clerk's automatic account linking on, so Apple and then Google with the same verified email reach the same Account (V2-FR-01).
3. Under Native applications, enable the Native API and register the iOS app with the Team ID and the bundle identifier `com.immerse.FilmJournal`, then add `com.immerse.FilmJournal://callback` to the allowlist for mobile SSO redirects, which Google's sign-in returns to ([Clerk's iOS quickstart](https://clerk.com/docs/ios/getting-started/quickstart)).
4. For Apple, follow [Clerk's Sign in with Apple guide for iOS](https://clerk.com/docs/ios/guides/configure/auth-strategies/sign-in-with-apple): the app sends Apple's identity token to Clerk, so the native flow needs the bundle identifier registered for Apple in Clerk.
5. For Google, create an OAuth client for the iOS app in Google Cloud and give its credentials to Clerk's Google connection, as Clerk's dashboard asks.
6. Under Sessions, set the native maximum session lifetime (step 1 of "Before you start").
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
5. The join page and web album Worker are Stage 3; nothing else on Cloudflare is needed now.

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

`CLERK_API_URL`, `APNS_ORIGIN` and `APNS_CA_PEM` stay unset: only the tests set them, to point at stand-ins.

## 6. Push the functions

```sh
npm ci --prefix Backend
(cd Backend && npx convex deploy)
```

The push checks the schema and type-checks the functions.

## 7. The app's configuration on the Mac that builds for the iPhones

1. Copy `App/Immerse/Config/Server.local.xcconfig.example` to `App/Immerse/Config/Server.local.xcconfig` (git ignores it) and fill in `IMMERSE_CONVEX_URL` from step 2 (written `https:/$()/<name>.convex.cloud`, since xcconfig reads `//` as a comment), `IMMERSE_CLERK_PUBLISHABLE_KEY` from step 3, and `IMMERSE_V2_ENTITLEMENTS = Config/ImmerseV2.entitlements`.
2. Build the Debug configuration from Xcode to each iPhone.
   With the file present, Start a Film offers **Host a Group Film**, Settings shows the Account section once signed in, and Settings > Debug testing shows **Server checks**.
   Without it, the app is exactly the v1 app.

## 8. The proof fixtures

Stage 1 proves the upload path and the push before Stage 2 builds events, so the proofs use internal fixtures that only the deployment's key can call:

```sh
cd Backend
npx convex run proofs:createProofEvent '{"clerkUserId": "<the Host's Clerk user id>"}'
npx convex run proofs:accountIdForClerkUser '{"clerkUserId": "<the Host's Clerk user id>"}'
npx convex run proofs:revealProofEvent '{"eventId": "<the event id>"}'
npx convex run push:sendTestAlert '{"accountId": "<the account id>"}'
```

The Clerk user id is in Clerk's dashboard under Users once the Host has signed up.
Section V of `Evidence/NativeApp/manual-validation.md` says when to run each.

## What each value is

| Value | Where it goes | Secret | Comes from |
| --- | --- | --- | --- |
| `IMMERSE_CONVEX_URL` | `Server.local.xcconfig` | No | Convex, step 2 |
| `IMMERSE_CLERK_PUBLISHABLE_KEY` | `Server.local.xcconfig` | No (public by design, still kept out of the repository) | Clerk, step 3 |
| `IMMERSE_V2_ENTITLEMENTS` | `Server.local.xcconfig` | No | `Config/ImmerseV2.entitlements` |
| `CONVEX_DEPLOY_KEY` | The Mac's environment | Yes | Convex, step 2 |
| `CLERK_JWT_ISSUER_DOMAIN` | Convex environment | No | Clerk, step 3 |
| `CLERK_SECRET_KEY` | Convex environment | Yes | Clerk, step 3 |
| `CLERK_WEBHOOK_SECRET` | Convex environment | Yes | Clerk, step 3 |
| `R2_ENDPOINT`, `R2_BUCKET`, `R2_REGION` | Convex environment | No | Cloudflare, step 4 |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | Convex environment | Yes | Cloudflare, step 4 |
| `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_TOPIC` | Convex environment | No | Apple, step 1 |
| `APNS_PRIVATE_KEY` | Convex environment | Yes | Apple, step 1 |
