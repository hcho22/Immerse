# Film Camera Experience - v2 Product Requirements Document: Group Films, Accounts and the backend

**Document date:** November 22, 2026 · **Version:** 1.1, a draft for the captain's approval (version 1.0 with the captain's answers to its open questions) · **Release:** v2\
**Platform:** iOS 26, iPhone only, for shooting; a web join page and a view-only web album for viewing\
**Status:** Planning document; nothing in it is built until the captain approves it.\
**Scope:** photo events modeled on the Once app, sign-in for Hosts, and the backend those need.\
**Builds on:** the v1 requirements, which stay as they are: [PRD version 2.1](2026-10-06-film-camera-experience-v1-prd-version-2.0.md) and its amendments of [2026-10-26](2026-10-26-film-camera-experience-v1-prd-phone-feedback.md) and [2026-10-29](2026-10-29-film-camera-experience-v1-prd-phone-feedback.md).\
**Overtakes:** the parked Group and Account design in PRD 2.1 sections 8 and 8.13 and in the tracker's Deferred to v2 section, which stay unchanged as history.

## Document guide and authority

This PRD states the v2 plan the captain settled question by question on 2026-11-21 and 2026-11-22.
It starts from the parked v2 design in PRD 2.1 section 8, challenges each rule against Once, and keeps a parked rule only where the plan does not overturn it.
Version 1.1 adds the captain's answers, given on 2026-11-22 after he read version 1.0, to its open questions: section 1's last rows list them, the requirements state them as decided, and section 16 keeps the one question still open and records each answer.
"v2" here is the product release after v1, with Group Films and Accounts.
"Version 1.0" is the version of this document.
v1 documents call their own release "v1" and their document set "version 2.1"; neither changes.

Each requirement carries one of these labels:

- **Decided** - the captain's answer, stated as a requirement.
  Unlabeled requirements are decided.
- **Carried from the parked design** - a rule of PRD 2.1 section 8 that the plan does not overturn and this PRD keeps.
  The captain can still change it; it is not new.
- **Reading** - how this PRD reads a plan answer where the words leave a small gap.
  Each reading is repeated in section 16 so the captain can correct it.
- **Proposed engineering approach** - a way to build a requirement, open to change without a product decision.
- **Open check** - a fact that must be measured or verified before the work it affects is promised (section 15).
- **Open question** - a product question the plan is silent on or answers two ways (section 16).
  Nothing here decides one.

Requirement IDs start with `V2-FR-` so they never collide with v1's FR-01 to FR-41.
Sections, requirement IDs and open item IDs stay stable once this document is approved.

Related documents:

- [Domain model](sources/CONTEXT.md): the glossary, updated with this PRD for Group Film, Host, guest, Roll, reveal and the other v2 terms.
- [Collected ADRs](2026-09-29-film-camera-experience-v1-adrs.md): ADRs 0025 to 0034 record the decisions this PRD states, and the collection says which earlier records they supersede.
- [Task tracker](2026-09-29-film-camera-experience-v1-task-tracker.md): its Deferred to v2 section keeps the parked tasks as history; v2 work is broken into tasks only after this PRD is approved, by the four stages in section 12.
- [Architecture baseline](2026-09-29-film-camera-experience-v1-architecture.md): the approved v1 shape, an on-phone app with no server; section 9 below is v2's proposed shape and does not change v1's.

## 1. The accepted plan and where this PRD states it

The table lists every item of the accepted plan and the requirements that state it.
Section 2 onward is the detail.

| Area | Accepted plan item | Stated in |
| --- | --- | --- |
| Scope | v2 is photo events modeled on Once, sign-in, and the backend. | 2.1, 2.2 |
| Scope | Group photo only: shared video is out of v2 entirely, neither built nor specified. "Group Film" means a shared photo roll. | 2.2, V2-FR-10 |
| Scope | Dodge and Burn stays parked. No Android app. Shooting is iPhone only. | 2.2, V2-FR-20 |
| Scope | Start from the parked v2 design and challenge it against Once. | Document guide, 3 |
| Scope | A new, separate v2 PRD, with the glossary and decision records updated in the same change; nothing built until approval. | Header, Document guide |
| People | Anyone can host. Only the Host signs in, with Apple, Google or email through Clerk. Guests give a name and may sign in later. | V2-FR-01, V2-FR-02, V2-FR-04, V2-FR-21 |
| People | Exactly one Host per event. No co-host and no handover. | V2-FR-11 |
| People | Hosting and signing in require age 13 or over. | V2-FR-03 |
| People | Personal Films stay sign-in free. The Trial stays one personal Film per iPhone, and joining an event never uses it. | V2-FR-02, V2-FR-07 |
| People | Each picture carries the guest's chosen name, shown only in its details and never printed on the image. A guest who loses or replaces their phone without having signed in loses their place, with no recovery. | V2-FR-22, V2-FR-46, V2-FR-04 |
| Joining | Guests join by QR code or link into a no-install mini-app (App Clip), or the full app when installed. No shooting in a browser. | V2-FR-15, V2-FR-19, V2-FR-20 |
| Joining | Whether the mini-app fits Apple's size cap with the cameras inside must be checked; if not, guests install the full app. | V2-FR-19, OC-1 |
| Joining | One code and link last the event's whole life. The Host can pause joining, and can replace the code only behind a warning that printed copies stop working. | V2-FR-15, V2-FR-16, V2-FR-17 |
| Joining | The iOS 26 floor stays. Guests who cannot join see a clear message. The cameras are not reworked for older systems. | V2-FR-18 |
| Shooting | The Host picks one Camera per event from Disposable, 6×6 and Instant. Each guest's set is that Camera's normal roll. On the 6×6 the Host picks the Film Stock for everyone. | V2-FR-10, V2-FR-25 |
| Shooting | Capture only, no camera-roll imports. | V2-FR-30 |
| Shooting | Guests can shoot offline after joining. Uploads follow later, and late arrivals appear after the reveal. | V2-FR-31, V2-FR-35, V2-FR-41 |
| Shooting | Pictures are developed on the phone that took them. Only the finished picture is uploaded and kept sealed until the reveal. Originals never leave the phone. The render worker leaves v2. | V2-FR-33, V2-FR-34, V2-FR-36, 9.1 |
| Shooting | An Instant picture develops for its shooter at once; others see it at the reveal. | V2-FR-32 |
| Reveal and album | The Host sets an end time. Development and reveal are automatic then, or after a delay the Host chose, up to 24 hours. The Host may end early. No Private Review and no release by hand. | V2-FR-12, V2-FR-38, V2-FR-39, V2-FR-40 |
| Reveal and album | Limits: 200 rolls per event, 7 days long. | V2-FR-12, V2-FR-26 |
| Reveal and album | After the reveal everyone who joined sees every picture. | V2-FR-43 |
| Reveal and album | Any member can save any picture or the whole album to Photos with no account. Private Prints and the seven-day originals window are left out. | V2-FR-44, V2-FR-36, 2.2 |
| Reveal and album | The Host can switch on a view-only web album after the reveal, on the join page, so Android guests and people who did not shoot can see and save the pictures; off unless the Host turns it on, and the Host can switch it off. | V2-FR-47 |
| Reveal and album | The album is kept 12 months after the reveal, with a warning before it ends. | V2-FR-48 |
| Control | A guest can pull all their own pictures before the reveal in one step, and remove any of their own after it. No shots are returned. | V2-FR-50, V2-FR-51 |
| Control | The Host can remove any picture or guest, but never edit or reorder other people's pictures. Guests can report a picture to the Host and to a support address. | V2-FR-52, V2-FR-53, V2-FR-54 |
| Control | The Host can delete the whole event early after a warning. | V2-FR-55 |
| Control | Deleting an account removes that person's own pictures everywhere. A deleted Host's events still run to their reveal and stay available to guests for the 12 months. | V2-FR-05, V2-FR-06 |
| Paying | Pay once per event, by exposure count, sold in rolls: one roll per guest. Rolls can be added while the event is open. | V2-FR-25, V2-FR-27, V2-FR-60 |
| Paying | A roll is used only when a guest takes it. Unclaimed rolls return to the Host's balance. | V2-FR-28 |
| Paying | Everyone gets a very small free event (about 3 rolls). Subscribers get a clearly larger free size. | V2-FR-62 |
| Paying | Rolls are bought through Apple's in-app purchase into the Host's signed-in balance. A subscriber's free rolls are credited once the server has confirmed the subscription with Apple. One subscription feeds one account. | V2-FR-60, V2-FR-61, V2-FR-63 |
| Paying | The PRD fixes the structure and leaves the actual numbers to the pricing decision still open for the v1 subscription. | V2-FR-64, OC-5 |
| Alerts and privacy | One alert only: "Your Film is ready" at the reveal, for people with the full app. Mini-app guests come back through the same link and are invited to install. | V2-FR-70, V2-FR-71 |
| Alerts and privacy | Personal Films never leave the iPhone. Event pictures are stored on Immerse's server. No advertising or tracking. | V2-FR-72, V2-FR-73 |
| Backend | Convex for the data, server logic and the timed reveal. Cloudflare for picture storage, the join page and the web album. Clerk for sign-in, linked to Convex. Apple's service for the alert, sent from Convex. | V2-FR-80, section 9 |
| Order of building | Four stages: the backend and sign-in; events in the full app with free rolls only; the no-install mini-app and join page; then buying rolls and the subscriber benefit. | Section 12 |
| Order of building | v2 work starts only after v1 is on the App Store. | Section 12 |
| Answers to version 1.0's open questions | The Host can shoot in their own event, taking one roll from the event like any guest. | V2-FR-25, V2-FR-26, 4.2 |
| Answers to version 1.0's open questions | Free rolls are once-ever for everyone: the small free event is given once per account, and a subscriber's larger free amount is also given once, not monthly. | V2-FR-62 |
| Answers to version 1.0's open questions | The Host can set a later start time, so the code can be printed weeks ahead, while shooting still lasts at most 7 days from the start. | V2-FR-12, V2-FR-13, V2-FR-18, 6.1 |
| Answers to version 1.0's open questions | When the Host removes a guest, that guest's pictures go with them. | V2-FR-53 |
| Answers to version 1.0's open questions | A guest who leaves on their own still sees the album after the reveal and may rejoin while the event is open. Only guests the Host removed lose access. | V2-FR-43, V2-FR-56 |
| Answers to version 1.0's open questions | When the Host ends early, the album reveals at once; the chosen reveal delay does not apply. | V2-FR-40 |
| Answers to version 1.0's open questions | The PRD's other readings stand as written: late pictures are accepted until the album ends; no email before the album ends, only notices in the app and on the page; the web album shows guest names in picture details; subscriber rolls already credited stay if the subscription lapses; a guest who signs in to an account already in the same event keeps both places; moving a subscription to another account goes through support; a refund after rolls were used can take the balance below zero. | V2-FR-41, V2-FR-48, V2-FR-47, V2-FR-63, V2-FR-04, V2-FR-65, 16.2 |
| Answers to version 1.0's open questions | Who answers the support address, and how fast, is decided before stage 2 and stays open. | V2-FR-54, OQ-12 |

## 2. Problem, goals and non-goals

### 2.1 Problem and goals

v1 is a personal camera: one person loads a Film, shoots it, and develops it on their own iPhone.
The parked v2 design made shared Films possible for small groups of up to ten people who had installed the app and pooled their subscribers' loads.
Event camera apps such as Once show what people actually reach for: a host prints a QR code, guests scan it at a wedding or a party, shoot a set number of pictures each without installing anything, and the album appears for everyone afterwards.
Their reviews also show where they fail: photos that go missing, an app that opens slowly or signs people out, and hosts paying for shots nobody took (section 3).

v2's goals:

1. **A shared roll for an event.** A Host makes a Group Film for one event, guests join by scanning or tapping, each takes one roll of the Host's chosen Camera, and every picture stays sealed until one automatic reveal.
2. **Guests with nothing to set up.** A guest gives a name and starts shooting, in a no-install mini-app or the full app, and never has to sign in.
3. **No lost pictures.** A picture taken is a picture that reaches the album, even when the guest shot offline or came back days later.
4. **Fair paying.** The Host pays once per event, in rolls, and pays only for rolls guests actually take.
5. **Immerse's look on every picture.** Event pictures are developed with the same Cameras and Developed Treatments as personal Films, on the phone that took them.
6. **Privacy kept.** Personal Films never leave the iPhone, event pictures are seen only by the event's members until the Host chooses a web album, and nothing is used for advertising or tracking.

### 2.2 Non-goals

None of these is in v2, and none is specified here:

- Shared video of any kind: no Group Movies, no Recording Turns, no shared Super 8 or 16mm Film.
- Dodge and Burn in the Darkroom (ADR 0023): it stays parked, beyond this release.
- An Android app, Android or web shooting, and shooting in any browser.
- Importing pictures from the camera roll, Files or another app.
- Private Review, release by hand, and any step where the Host sees pictures before the guests.
- Private Prints, the Darkroom on event pictures, and any edit of an event picture inside Immerse.
- Saving originals: the seven-day originals window is left out, and originals never leave the phone that took them.
- Co-hosts, Host handover, or a replacement Host.
- A render worker or any server-side Development.
- Advertising, tracking, analytics SDKs, or selling or sharing data.
- Reworking the Cameras for iOS versions before 26.
- Changes to personal Films, the per-iPhone Trial, or the v1 subscription's entitlement for personal Films.
- Guest books, audio messages, branding, location stickers and the other extras Once has added since launch.

## 3. What Once teaches, and the requirements it sharpens

Facts about Once are from its App Store record, its website and its join page, read on 2026-11-21; its reviewers' complaints are quoted from the US and Canadian App Store reviews of July to October 2026.
Immerse's v2 is not a copy of Once: it keeps Immerse's own Cameras, Developed Treatments and reveal ritual, and its own rules on privacy.

| Once | v2 choice | Sharpened requirement |
| --- | --- | --- |
| A host creates a "film", sets shots per guest and an end time, and gets a QR code and link that "stays the same for the life of the film, so it is safe to print weeks ahead". | One Join Code with its link and QR for the event's whole life; the Host can set a later Start Time so the code can be printed ahead, and can pause joining or replace the code behind a warning. | V2-FR-12, V2-FR-15 to V2-FR-17 |
| Guests join by QR or link into an App Clip, the app or the browser, give a name, and shoot with no account. | Guests join in the mini-app or the full app with a name only; no browser shooting. | V2-FR-19 to V2-FR-22 |
| Android guests shoot in the browser. | No Android shooting; Android guests and others see the pictures in a web album the Host switches on. | V2-FR-18, V2-FR-47 |
| The host pays by guest count; "the host uses one of those places if they take photos too"; an "Unlimited Shots" add-on. | The Host pays by rolls, one per guest, each the Camera's normal roll; no unlimited shots; a Host who shoots takes one roll from the event, as Once's host uses one place. | V2-FR-25 to V2-FR-28 |
| Complaint: "As a host you pay for a camera roll and photos upfront- but that moneys wasted if your guests don't use all the photos" (4 stars, 2026-09-14). | A roll is used only when a guest takes it, and unclaimed rolls return to the Host's balance. A roll a guest takes but does not finish is still used, as a disposable handed out is. | V2-FR-28 |
| Complaint: "it lost over half the photos from bachelorette" (1 star, 2026-08-20); Once's release notes fixed upload reliability and "photo recoverability" repeatedly. | Every picture is kept on the phone until the server confirms it, uploads retry for the album's whole life, late arrivals join the album after the reveal, and the guest sees what is still waiting to upload. | V2-FR-34, V2-FR-35, V2-FR-41, success measure M-1 |
| Complaint: "Good luck opening it in less than 15 seconds, good luck staying logged in" (1 star, 2026-07-30); "it kept making me resign up when I wanted to just snap a pic" (2 stars, 2026-07-27). | Guests never sign in to shoot; a Host stays signed in through any event they host; the mini-app and the shooting screen open within a set time. | V2-FR-08, V2-FR-21, success measure M-2, open check OC-8 |
| Complaint: "I wish there was no time frame to which guests can upload their pictures" (4 stars, 2026-10-05). | Shooting ends at the End Time, but uploads do not: a picture taken before the end arrives whenever its phone is back online, until the album ends. | V2-FR-41 |
| Once added camera-roll uploads in version 1.8.5 (2026-11-21), each using a shot. | Capture only. | V2-FR-30 |
| Until the reveal every photo stays blurred, including a guest's own; the reveal is automatic at a host-chosen time, from the end to 24 hours after. | Every picture stays sealed, a Disposable or 6×6 guest's own included; the reveal is automatic at the End Time or up to 24 hours after; an Instant print shows to its shooter at once, as an Instant camera does. | V2-FR-32, V2-FR-38, V2-FR-39 |
| The host chooses who sees the album: host only, everyone, or each guest their own. | One rule: after the reveal everyone who joined sees every picture. | V2-FR-43 |
| Guests download photos after creating an account. | Any member saves any picture or the whole album with no account. | V2-FR-44 |
| "All your photos are safely stored and never expire." | The album is kept 12 months after the reveal, with a warning before it ends. | V2-FR-48 |
| Account deletion leaves a person's photos in others' films with attribution anonymized. | Deleting an account removes that person's own pictures everywhere. | V2-FR-05 |
| Once's App Store privacy label lists a Device ID and Advertising Data used to track, while its privacy policy says none. | No advertising or tracking, and the privacy label says so truthfully. | V2-FR-73, section 11 |
| Once's App Store record requires iOS 16.4. | v2 keeps iOS 26, and anyone who cannot join is told why. | V2-FR-18 |
| Whether a host can revoke or replace a Once link was not found on any page. | The Host can pause joining and replace the code behind a warning. | V2-FR-16, V2-FR-17 |

## 4. People and their journeys

### 4.1 Roles

| Role | Who | Needs an Account | Device |
| --- | --- | --- | --- |
| **Host** | The one person who creates a Group Film, sets it up, pays for its rolls and moderates it. Anyone 13 or over can host. | Yes, through Clerk: Apple, Google or email. | iPhone with the full app. |
| **Guest in the mini-app** | Someone who joins by scanning the QR code or tapping the link without the app installed. | No. May sign in later, in the full app. | iPhone on iOS 26, through the App Clip. |
| **Guest in the full app** | Someone who joins with Immerse installed, or who installs it after joining in the mini-app. | No. May sign in to keep their place across phones. | iPhone on iOS 26. |
| **Web-album viewer** | Anyone with the event's link once the Host has switched the web album on: Android guests, people who did not shoot, guests on a computer. | No. | Any current web browser. |
| **Support** | Immerse's operator, who receives reports at the support address and handles requests the app cannot. | Not applicable. | Not applicable. |

**Member** means the Host and every guest who has joined and not been removed, a guest who left on their own included (V2-FR-56).
A web-album viewer is not a member.

### 4.2 Permission summary

| Action | Host | Guest (mini-app or full app) | Web-album viewer |
| --- | --- | --- | --- |
| Create a Group Film, choose its Camera, Film Stock, Start Time, End Time, Reveal Delay and rolls | Yes | No | No |
| Add rolls while the event is open | Yes | No | No |
| Pause or resume joining, replace the Join Code | Yes | No | No |
| End early | Yes | No | No |
| Join and take a roll | Yes, one roll from the event, like any guest | Yes, one roll | No |
| Shoot | If they take a roll, until the End Time, within it | Yes, until the End Time, within their roll | No |
| See their own Instant prints before the reveal | If they shoot | Yes | No |
| See any other picture before the reveal | No | No | No |
| See every picture after the reveal | Yes | Yes, a guest who left included; not a removed guest | Yes, while the web album is on |
| Save any picture or the whole album to Photos | Yes | Yes | Yes, while the web album is on |
| Pull all their own pictures before the reveal | If they shoot | Yes | No |
| Remove one of their own pictures after the reveal | If they shoot | Yes | No |
| Remove any picture after the reveal | Yes | No | No |
| Remove a guest | Yes | No | No |
| Edit, reorder or caption another person's picture | No | No | No |
| Report a picture to the Host and support | Not needed | Yes | No (support address on the page) |
| Switch the web album on or off | Yes | No | No |
| Delete the whole event | Yes, after a warning | No | No |
| Leave the event, and rejoin while it is open | No | Yes | No |

### 4.3 Journeys

Each journey cites the requirements it relies on.

#### Journey H - A Host runs a wedding's Group Film

1. Maya opens Immerse, taps Start a Film and chooses **Group Film**.
   The app asks her to sign in; she chooses Sign in with Apple and confirms she is 13 or over (V2-FR-01, V2-FR-03).
2. She names it "Ana & Leo", picks the Disposable, sets the End Time to midnight on the wedding day and the Reveal Delay to the next morning, 10 hours later (V2-FR-10, V2-FR-12).
3. She sets the event's rolls to 60.
   Her balance holds her free rolls and none bought, so the app offers to buy the rest through Apple's in-app purchase; she buys them and confirms (V2-FR-25, V2-FR-60).
4. Load Film fixes the Camera, and the app shows the event's QR code and link at once.
   She prints the code on the table cards and sends the link in the family chat (V2-FR-13, V2-FR-15).
5. Two days before the wedding a printed card goes missing at the venue.
   She pauses joining overnight and resumes it in the morning rather than replacing the code, because the cards are already printed (V2-FR-16, V2-FR-17).
6. During the reception she sees how many rolls are taken and how many pictures have arrived, but never a picture (V2-FR-29, V2-FR-37).
   When 58 rolls are taken she adds ten (V2-FR-27).
7. At midnight shooting stops on every phone.
   At 10:00 the next morning the album reveals itself; she gets "Your Film is ready" (V2-FR-38, V2-FR-70).
   The 2 rolls nobody took return to her balance (V2-FR-28).
8. She removes one picture a guest's child took of the floor, saves the whole album to Photos, and switches on the web album so her grandmother, who has an Android phone, can see it (V2-FR-52, V2-FR-44, V2-FR-47).
9. Eleven months later the app and the web album tell every member the album ends in a month (V2-FR-48).

#### Journey M - A guest joins in the mini-app

1. Jo scans the table card with the iPhone's Camera.
   iOS shows the App Clip card; Jo taps Open and the mini-app starts without installing anything (V2-FR-19).
2. The Join Confirmation shows "Ana & Leo", "Hosted by Maya", the Disposable, 27 exposures, when shooting ends, when the album reveals, and who will see the pictures (V2-FR-21).
3. Jo types "Jo" as the name shown with each picture and taps Take a Roll; the event now has one roll fewer to give (V2-FR-22, V2-FR-28).
4. The Disposable's shooting screen opens, the same as in a personal Film, with its count at 27 (V2-FR-31).
5. The reception hall has no signal.
   Jo shoots 20 pictures; each is saved and developed on the phone, sealed even from Jo, and waits to upload (V2-FR-31, V2-FR-33, V2-FR-34).
6. Outside, with signal, the mini-app uploads them while it is open and shows "20 waiting, 12 sent" until all are sent; the App Clip cannot upload in the background, so the mini-app asks Jo to keep it open or come back (V2-FR-35).
7. The next morning Jo opens the same link.
   The mini-app shows the revealed album, invites Jo to install the full app, and offers to save pictures (V2-FR-71, V2-FR-44; open check OC-6).

#### Journey F - A guest in the full app, who signs in later

1. Sam already has Immerse for personal Films and taps the link in the family chat; the full app opens at the Join Confirmation (V2-FR-19).
2. Sam takes a roll as "Uncle Sam".
   Joining does not use the Trial and asks for no sign-in (V2-FR-07, V2-FR-21).
3. Sam shoots the whole roll; the app develops each picture and uploads it sealed in the background where iOS allows (V2-FR-33, V2-FR-35).
4. Worried about changing phones next month, Sam signs in with email; the place and pictures move to the Account (V2-FR-04).
5. At the reveal Sam gets "Your Film is ready", opens the album and saves 40 pictures to Photos (V2-FR-70, V2-FR-44).
6. On the new phone Sam signs in and finds the event in the Film Library (V2-FR-04).

#### Journey W - A web-album viewer

1. Maya has switched on the web album.
   Her grandmother taps the link on an Android phone.
2. The join page shows the event's title, the revealed pictures and a way to save each one, with a note that shooting needs an iPhone (V2-FR-47, V2-FR-18).
3. She can look and save; she cannot shoot, report through the app, remove anything, or see guests' names other than in a picture's details (V2-FR-47, V2-FR-22).
4. When Maya switches the web album off, the same link shows only the event's title and a message that its pictures are not shared on the web (V2-FR-47).

#### Journey P - A guest takes their pictures back

1. Before the reveal, Jo regrets joining.
   On the event's page in the mini-app Jo chooses **Withdraw Before Reveal**, reads that all Jo's pictures in this event will be removed for good, unseen, and that no exposures come back, and confirms (V2-FR-50).
2. Pictures still waiting on the phone are deleted there and never upload; pictures already on the server are deleted there.
   The album reveals without them, leaving numbered gaps (V2-FR-50).
3. After the reveal Sam removes one of Sam's own pictures for everyone (V2-FR-51), and reports another guest's picture; the report reaches Maya and the support address (V2-FR-54).

#### Journey D - A Host deletes their account

1. Maya chooses Delete Account in Settings and reads what will happen (V2-FR-05).
2. Every picture Maya took, in any event, is removed everywhere.
3. Her event still running keeps running: guests can still join and shoot until its End Time, it reveals on schedule, and its album stays for 12 months after the reveal, with no one able to change its settings (V2-FR-06).
4. Her personal Films stay on her iPhone, untouched (V2-FR-02).

## 5. Functional requirements

Each requirement is followed by acceptance criteria a tester can check.
"The server" means Immerse's backend (section 9): Convex for data and logic, Cloudflare for picture storage and web pages.

### 5.1 Accounts and sign-in

#### V2-FR-01 - Sign-in with Apple, Google or email, through Clerk

A person signs in with Sign in with Apple, Google, or an email address, all through Clerk, and Clerk's sign-in is linked to Convex so the server knows who is signed in.
The three methods lead to one Account per person where Clerk can link them.

Acceptance criteria:

- Each of the three methods signs a new person up and signs a returning person in, on iOS 26.
- Signing in with Apple and then with Google using the same verified email reaches the same Account, as Clerk's automatic account linking provides.
- Every server operation that needs an Account rejects a request without a valid Clerk session, whatever the app shows.
- Sign in with Apple is offered wherever Google is, which also meets App Store guideline 4.8 (section 11).

#### V2-FR-02 - Only hosting needs an Account

Only hosting a Group Film needs an Account.
Joining, shooting, saving and every personal Film action never ask anyone to sign in.
A person who never hosts never sees a sign-in prompt, except where they choose to sign in (V2-FR-04).
Personal Films, the v1 subscription for personal Films, the Trial, Development, the Darkroom and export work as in v1, with or without an Account, and none of them sends anything to the server.

Acceptance criteria:

- A new install can shoot, develop and export a personal Film, and join and shoot in a Group Film, without signing in.
- Choosing Group Film under Start a Film asks a signed-out person to sign in before anything else, and nothing else does.
- With the network off, every personal Film action works as in v1.
- Signing out or deleting an Account leaves every personal Film on the iPhone unchanged.

#### V2-FR-03 - Hosting and signing in require age 13 or over

Signing in and hosting are only for people 13 or over.
Before an Account is created the person confirms they are 13 or over; a person who says they are not is told they cannot sign in and is not signed up.
Joining as a guest without signing in does not ask for an age.
How age is confirmed, whether by a statement or a system age signal, is open check OC-9.

Acceptance criteria:

- No Account can be created without the age confirmation.
- A person who declines is returned to where they started, signed out, and can still join events as a guest and use personal Films.
- The App Store age rating and the privacy policy state the 13-or-over rule for Accounts.

#### V2-FR-04 - Guests may sign in later; an unsigned guest's place is bound to the phone

A guest joins with no Account.
Their place, their roll and their pictures belong to a guest identity kept on that phone (V2-FR-23).
At any time a guest may sign in in the full app; their guest identity, place and pictures then belong to their Account, and signing in on another iPhone brings them back there (**Claim Guest Identity**).
A guest who loses or replaces their phone without having signed in loses their place, with no recovery: their pictures already uploaded stay in the event as theirs, but nobody can act for them again, take their unused exposures, or withdraw those pictures through the app.
The mini-app offers sign-in only by way of the full app (open check OC-6 covers what the mini-app can do).

Acceptance criteria:

- A guest who signs in keeps every picture, their remaining exposures and their name; nothing is uploaded twice.
- After signing in on a second iPhone, the guest sees the event, their remaining exposures and, after the reveal, the album.
- A guest who deletes the mini-app and the full app without signing in cannot get their place back on any phone, and the app says so before they leave an event unsigned (V2-FR-23).
- Claiming never moves a guest from one event to another or merges two guests in one event; if the Account already has a place in that event, the app explains and keeps both as they were, each with its own Roll and pictures.

#### V2-FR-05 - Delete Account

A signed-in person can delete their Account in the app.
Deleting it removes that person's own pictures everywhere, in every event, before and after the reveal, sealed or revealed, and their name from those pictures' details.
It removes the Account, its sign-in, its roll balance, its link to any subscription, its push token, and its data on the server, as section 8 lists.
Personal Films stay on the iPhone untouched.
Before confirming, the app says what will be removed, that rolls in the balance are lost, that copies others already saved to Photos cannot be recalled, and that an Apple subscription continues to bill until cancelled in Apple's settings.

Acceptance criteria:

- Delete Account is reachable from Settings in two taps or fewer for a signed-in person, as App Store guideline 5.1.1(v) requires.
- Within one minute of confirming, none of the person's pictures can be seen or downloaded by anyone, in the app or the web album, and each leaves a numbered gap.
- The person's pictures still waiting on their phone are deleted there and never upload, and the phone also deletes the Instant prints it keeps (V2-FR-32).
- Clerk's user and every server record that names the person are deleted, apart from the purchase records section 8 says are kept for accounting, which no longer name them.
- Signing in again with the same method creates a new, empty Account.

#### V2-FR-06 - A deleted Host's events run on to their reveal

When a Host deletes their Account, each event they host carries on without them.
It keeps its settings as they were: its Camera, its rolls already set aside, its Start Time, its End Time, its Reveal Delay, its joining state and its web album setting.
Guests can still join and shoot until the End Time, because "still run to their reveal" includes joining and shooting; an event not yet open still opens at its Start Time; it reveals automatically, and its album stays available to its guests for 12 months after the reveal.
Nobody can change its settings, end it early, add rolls, remove pictures or guests, or delete it; reports about it go to support alone, and support can remove a picture (V2-FR-54).
Unclaimed rolls have no balance to return to and lapse at the End Time.
The Host's own pictures are removed, as V2-FR-05 says.

Acceptance criteria:

- An event whose Host deleted their Account before its End Time accepts joins and pictures until the End Time and reveals at the scheduled time.
- Its album is reachable by its members for 12 months after the reveal, then removed as V2-FR-48 says.
- Every Host control is gone for everyone, and the event page says the Host has left Immerse.
- A report about it reaches the support address.

#### V2-FR-07 - The Trial stays one personal Film per iPhone

The v1 Trial is unchanged: one personal Trial Film per iPhone, remembered in the Keychain, with no Account (ADR 0012).
Joining or shooting in a Group Film never starts, uses or blocks the Trial, and hosting never uses it.
Signing in neither grants nor uses a Trial.

Acceptance criteria:

- An iPhone that has used its Trial can still join and shoot in any Group Film.
- An iPhone that has not used its Trial still has it after joining, shooting in and leaving a Group Film.
- Signing in or out changes nothing about the Trial record.

#### V2-FR-08 - A Host stays signed in

A Host is never asked to sign in again while an event they host is open or awaiting its reveal, short of signing out or deleting the Account themselves.
Guests never sign in to shoot (V2-FR-21).
Clerk's free plan fixes a session at seven days, which an event of seven days plus a 24-hour delay outlasts, so how the session is kept is open check OC-8.

Acceptance criteria:

- A Host who signs in, creates an event lasting seven days with a 24-hour delay, and does not open the app for eight days, can open it and manage the event with no sign-in prompt.
- Losing the network never signs anyone out.

### 5.2 Creating a Group Film

#### V2-FR-10 - A Group Film is a shared photo roll with one Camera

A Host creates a Group Film from Start a Film by choosing Group Film; Personal stays the default.
The Host picks exactly one Camera for the event from the Disposable, the 6×6 and the Instant, the three photo Cameras.
On the 6×6 the Host also picks the Film Stock, color or black-and-white, for everyone.
The Super 8 and the 16mm are not offered, and no Group Film records video.
Each Camera behaves, looks and develops as it does in a personal Film, with the Camera package and Developed Treatment version current when the Host loads it (ADR 0013 to ADR 0016, ADR 0014 for the Film Stock).
Before choosing, the Host can see each Camera's Camera Preview.

Acceptance criteria:

- The Camera choice for a Group Film lists exactly the Disposable, the 6×6 and the Instant.
- A 6×6 Group Film cannot be created without a Film Stock, and every guest's pictures develop on that Film Stock.
- A guest cannot choose or change the Camera or the Film Stock.
- A picture from a Group Film and one from a personal Film of the same Camera, package version and Film Stock develop the same from the same original.

#### V2-FR-11 - Exactly one Host, for the event's life

Every Group Film has exactly one Host, the Account that created it, for its whole life.
There are no co-hosts, no handover, no transfer and no replacement Host, even when the Host deletes their Account (V2-FR-06).
**Carried from the parked design:** a guest cannot see the Host's other Films, personal Films or settings.

Acceptance criteria:

- No operation on the server can add a second Host or move the Host role.
- A guest's app shows nothing of the Host's beyond the event's title and the Host's display name.

#### V2-FR-12 - Start Time, End Time, Reveal Delay and the seven-day limit

The Host sets the event's **End Time**, when shooting stops, and its **Reveal Delay**, from none up to 24 hours after the End Time.
The event opens at Load Film, or at a later **Start Time** the Host sets, so its code can be printed and shared weeks ahead.
The plan sets no limit on how far ahead the Start Time can be.
Shooting lasts at most 7 days: the End Time is at most 7 days after the event opens, at Load Film or at the Start Time.
Before the Start Time the link and the QR code work and show the event and when it opens, but nobody can join or shoot, the Host included (**Reading**).
The Host can move the Start Time until the event opens (**Reading**), and can move the End Time and change the Reveal Delay until the End Time, within the same limits; moving the End Time to now while the event is open is ending early (V2-FR-40).
Times are kept on the server and shown in each person's own time zone.

Acceptance criteria:

- The app refuses a Start Time in the past, an End Time in the past or more than 7 days after the event opens, and a Reveal Delay above 24 hours.
- An event with a Start Time admits nobody before it, and opens at it without anyone doing anything.
- A QR code printed weeks before the Start Time opens the event's page at once and lets guests join from the Start Time.
- The reveal happens at End Time plus Reveal Delay, to the minute, without anyone opening the app (V2-FR-38).
- A guest's phone with a wrong clock still stops shooting at the server's End Time once it has been online after joining (V2-FR-31).

#### V2-FR-13 - Load Film fixes the event and issues its Join Code

The Host's Load Film confirmation shows the title, Camera, Film Stock where there is one, rolls, End Time, Reveal Delay, and the sharing rule (sealed until the reveal, then seen by every member), and fixes the Camera and Film Stock for good (**Camera Lock**).
Load Film issues the event's Join Code, link and QR code at once, also for an event that opens later at its Start Time (V2-FR-12).
Load Film needs a connection, because the event exists on the server.

Acceptance criteria:

- No guest can join before Load Film, or before the Start Time when the Host set one.
- The Camera and Film Stock cannot change after Load Film.
- Load Film offline says a connection is needed and keeps the Host's choices.

#### V2-FR-14 - The Film Title

The Host must give the event a Film Title before Load Film and may change it until the album ends.
**Carried from the parked design:** a Group Film is the event itself; there is no event container above it.

Acceptance criteria:

- A changed title shows to every member and on the join page within a minute.

### 5.3 The Join Code, its link and the join page

#### V2-FR-15 - One Join Code for the event's whole life

Each Group Film has one **Join Code**, carried by one link and one QR code, which last from Load Film until the album ends or the event is deleted, unless the Host replaces the code (V2-FR-17).
The code is long and random enough that it cannot be guessed, and it reveals nothing about the event or the Host.
There is no short code to type: guests join by the QR code or the link.
The link opens the join page on any device (V2-FR-18), and on an iPhone it opens the mini-app or the full app (V2-FR-19).
After the End Time the same link leads members to the album, and anyone else to a page saying shooting has ended (and to the web album when the Host has switched it on).
The app offers the QR code as an image the Host can print or share, and the link to copy or share.

Acceptance criteria:

- A QR code printed at Load Film still opens the same event at its reveal and while the album is kept, unless the code was replaced.
- Guessing codes at random finds no event in practice: the code space and the server's rate limits make it so (proposed engineering approach: at least 128 bits of randomness and per-address limits).
- The link previews in Messages with the event's title only, never a picture.

#### V2-FR-16 - The Host can pause and resume joining

The Host can pause joining at any time while the event is open, and resume it.
While joining is paused, the link and QR code still work but admit nobody new; a person who opens them is told joining is paused for now.
Pausing changes nothing for guests who have joined: they keep shooting.

Acceptance criteria:

- A join attempt during a pause is refused on the server, whatever the app shows.
- Resuming admits the next person with the same printed code.

#### V2-FR-17 - The Host can replace the code, behind a warning

The Host can replace the Join Code while the event is open.
Before it is replaced the app warns that the old link and QR code, including every printed copy, stop working at once and for good, and the Host confirms.
Replacing the code removes nobody and changes nothing for guests who have joined.
Members keep reaching the event through the app; the old link shows a page saying it no longer works.
**Carried from the parked design:** replacing the code does not identify the person behind any new guest.

Acceptance criteria:

- Within a minute of replacing, the old link and QR code admit nobody and show the "no longer works" page.
- Every joined guest keeps shooting and reaches the album after the reveal.

#### V2-FR-18 - The iOS 26 floor, and a clear message for anyone who cannot join

Shooting needs an iPhone on iOS 26 or later, the same floor as v1.
The Cameras are not reworked for older systems.
Anyone who opens the link where they cannot join sees why on the join page, in plain words, and what they can do instead:

| Who opens the link | What they see |
| --- | --- |
| An iPhone on an iOS version before 26 | Shooting needs iOS 26 or later; update the iPhone to join. |
| An Android phone, a computer or another device | Shooting needs an iPhone on iOS 26; the pictures will be on this page after the reveal if the Host shares them. |
| Anyone before the Start Time | This event opens at its Start Time, shown in their own time zone; come back then. |
| Anyone while joining is paused | Joining is paused for now. |
| Anyone when every roll is taken | Every roll has been taken; the Host can add more. |
| Anyone after the End Time | Shooting has ended, with the reveal time, or the album or web album when they can see it. |
| Anyone after the event is deleted or the album has ended | This event is no longer available. |
| Anyone with a replaced code | This link no longer works; ask the Host for the new one. |
| A guest the Host removed, in the app | You can no longer take part in this event. |

Acceptance criteria:

- Each row's message appears for its case, on the join page and, where the person reaches the app, in the app.
- No case shows an empty page, a spinner that never ends, or an error code.

### 5.4 Joining

#### V2-FR-19 - Guests join in the mini-app, or the full app when installed

On an iPhone, the link and QR code open Immerse's **mini-app**, an App Clip, without installing anything, or the full app when it is installed.
The mini-app holds what a guest needs: the Join Confirmation, the shooting screen of the event's Camera, Development of their pictures, the upload queue, and the album after the reveal.
Whether the mini-app fits Apple's size cap with the three Cameras' Developed Treatments inside is open check OC-1.
If it does not fit, the mini-app is dropped and guests install the full app from the join page, which then opens the event (**Decided** fallback).
A guest who installs the full app after joining in the mini-app keeps their place, roll and pictures, because the mini-app hands its data to its full app (Apple allows an App Clip to share data with its full app; section 11).

Acceptance criteria:

- Scanning the QR code with the iPhone's Camera on iOS 26 without Immerse installed opens the mini-app at the Join Confirmation.
- With Immerse installed, the same scan opens the full app at the same place.
- Installing the full app after joining in the mini-app shows the same event, roll, remaining exposures and pictures, with nothing uploaded twice.
- Every feature of the mini-app is also in the full app, as Apple requires.

#### V2-FR-20 - No browser, Android or other shooting

No one shoots in a browser, on Android, on an iPad app, or anywhere but the mini-app or the full app on an iPhone.

Acceptance criteria:

- The join page offers no camera, no upload and no file picker.

#### V2-FR-21 - The Join Confirmation, with no sign-in

Opening a valid link shows a **Join Confirmation** before anyone joins: the Film Title, the Host's display name, the Camera and its exposures per roll, the Film Stock where there is one, when shooting ends, when the album reveals, and the sharing rule: every picture stays sealed until the reveal, a guest's own included (an Instant guest sees their own prints at once), and after the reveal everyone who joined sees every picture.
Joining needs only a name (V2-FR-22) and the tap that takes a roll.
No guest is asked to sign in, give an email or create anything.
**Carried from the parked design:** opening the link alone joins nobody, the Host does not approve each guest, and the confirmation never shows a picture.

Acceptance criteria:

- From opening the link in the mini-app to the shooting screen takes no more than the name and one tap, with no sign-in screen.
- The confirmation shows every item listed above.

#### V2-FR-22 - The guest's chosen name

On joining, the guest chooses the name shown with their pictures, the **Guest Name**.
It is shown only in each picture's details and in the Host's list of guests, never printed or drawn on the picture, and never in a saved file's pixels (**Contributor Attribution**).
The guest can change their name until the album ends; the change shows on all their pictures.
The app limits a name's length and refuses an empty one.

Acceptance criteria:

- A saved picture's pixels carry no name.
- A picture's details show its shooter's current Guest Name.
- The Host's guest list shows each guest's name and how many exposures they have used, never their pictures before the reveal.

#### V2-FR-23 - The guest identity on the phone

Joining creates a guest identity for that phone, kept in the full app's Keychain or, in the mini-app, in data the full app can take over.
It is what lets the guest shoot, upload, withdraw and see the album without an Account.
The app tells an unsigned guest, before they leave an event or delete the app, that their place lives on this phone only and that signing in keeps it.
How a guest identity is shown to Convex and Cloudflare is open check OC-4.

Acceptance criteria:

- A guest identity cannot act for another guest, in any event, on the server.
- Reinstalling the full app on the same iPhone keeps an unsigned guest's place where the Keychain survives (as v1's Trial record does).

#### V2-FR-24 - When joining is refused

Joining is refused, with V2-FR-18's message, before the Start Time, when joining is paused, every roll is taken, the End Time has passed, the event is deleted, the code was replaced, or the person was removed from this event.
**Carried from the parked design:** a removed guest's identity cannot rejoin the same event, even with a current or replaced code; the same person on another phone with a new, unlinked identity may not be recognized.
A guest who has already joined cannot take a second roll in the same event; a guest who left on their own rejoins to their own Roll (V2-FR-56).

Acceptance criteria:

- Two people taking the last roll at the same moment: exactly one gets it, and the other sees "Every roll has been taken".
- A removed guest's identity, or the Account it was claimed into, is refused at join.

### 5.5 Rolls

#### V2-FR-25 - A Roll is one guest's set of exposures

A **Roll** is one guest's set of exposures in a Group Film: the normal roll of the event's Camera, 27 exposures on the Disposable, 12 on the 6×6 and 10 on the Instant.
Each guest who joins takes exactly one Roll.
The Host can shoot in their own event: they take one Roll from the event, like any guest, and shoot it under the same rules.
Rolls are what a Host pays for, one per guest, and how many there are sets how many guests can join.
A guest's exposures are theirs alone: no pool, no sharing, no adding exposures to a Roll.

Acceptance criteria:

- A guest's count starts at the Camera's normal roll and goes down by one for each saved picture.
- When a guest's count reaches zero, their shooting screen says their roll is finished.
- No guest can use another guest's exposures.
- A Host who shoots in their own event takes one of its Rolls, and the event has one Roll fewer to give.

#### V2-FR-26 - At most 200 Rolls per event

An event has at most 200 Rolls in its whole life.
Rolls returned at the end (V2-FR-28) count within the 200 while they are set aside, and the Host's own Roll, if they take one (V2-FR-25), counts within the 200 like any guest's.

Acceptance criteria:

- Setting aside or adding Rolls beyond 200 is refused, with a message that names the limit.

#### V2-FR-27 - The Host can add Rolls while the event is open

While the event is open, the Host can add Rolls from their balance, up to the limit of 200.
Adding Rolls admits new guests at once, including when every Roll had been taken.
Rolls cannot be added after the End Time.

Acceptance criteria:

- An event with every Roll taken admits a new guest within a minute of the Host adding Rolls.
- Adding Rolls offline says a connection is needed.

#### V2-FR-28 - A Roll is used only when a guest takes it; unclaimed Rolls return

Setting Rolls aside for an event takes them from the Host's balance, but a Roll is used only when a guest takes it at joining.
At the End Time, every Roll no guest took returns to the Host's balance, for any future event.
A Roll a guest took is used, however many of its exposures they shoot, and no shot is returned, whether the guest left, was removed, or withdrew their pictures (as a disposable handed out is used).
When the Host deletes the event before its End Time (V2-FR-55), its unclaimed Rolls return to the balance.

Acceptance criteria:

- An event with 60 Rolls set aside and 52 taken returns 8 to the Host's balance at the End Time, without the Host doing anything.
- A guest who withdraws their pictures or is removed does not give back their Roll.
- The Host's balance history shows each set-aside, return, purchase and credit.

#### V2-FR-29 - The Host sees counts, never pictures, before the reveal

While the event is open and awaiting its reveal, the Host sees how many Rolls are taken and free, each guest's name and exposures used, and how many pictures have arrived on the server.
The Host sees no picture before the reveal.

Acceptance criteria:

- No screen, notification or server response gives the Host a sealed picture or its thumbnail.

### 5.6 Shooting, Development and upload

#### V2-FR-30 - Capture only

Every picture in a Group Film is taken in the mini-app or the full app with the event's Camera.
Nothing can be imported from Photos, Files or another app, and no picture from a personal Film can be moved into an event.

Acceptance criteria:

- The shooting screen and the event's page offer no import.

#### V2-FR-31 - Guests can shoot offline after joining

Joining needs a connection.
After joining, a guest can shoot with no connection: the phone knows the event's Camera, Film Stock, Roll and End Time from joining and keeps each picture safe on the phone.
Shooting stops at the End Time; a phone that has been online since joining learns any change to the End Time and stops then.
A phone that has not been online since an End Time was moved earlier keeps the End Time it knew; a picture whose capture time is after the server's End Time is refused when it arrives, and the guest is told (**Proposed engineering approach**; the phone's clock is accepted, as section 14 notes).
The shooting screen, its controls, the Viewfinder, Selfie Capture, flash and zoom are the Camera's own, as in a personal Film.

Acceptance criteria:

- With the network off after joining, a guest shoots their whole Roll and every picture is kept.
- At the End Time the shooting screen on a phone that knows it says shooting has ended and takes no more pictures.
- Moving the End Time while a guest is online stops their shooting at the new time.

#### V2-FR-32 - An Instant print develops for its shooter at once

On the Instant, each print develops on the shooter's phone right after capture and the shooter sees it at once, as in a personal Instant Film.
Nobody else, the Host included, sees it until the reveal.
The developed print stays on the shooter's phone after the server confirms it, so the shooter can keep viewing it there until the reveal; at the reveal the phone deletes its copy and the shooter sees the print in the album like everyone else (V2-FR-34, V2-FR-37).

Acceptance criteria:

- An Instant guest sees each print a moment after taking it, offline included.
- An Instant guest still sees each of their prints on their own phone after it has uploaded, until the reveal.
- No other member sees it before the reveal.

#### V2-FR-33 - Pictures are developed on the phone that took them

Each picture is developed on the phone that took it, by the same Development as a personal Film, with that phone's own Camera package and Developed Treatment.
A Disposable or 6×6 picture is developed soon after it is saved, without being shown to anyone, its shooter included, until the reveal (**Proposed engineering approach**: developing each picture early lets it upload before the End Time and keeps the reveal on time; the reveal ritual is the same for everyone at the reveal).
There is no server-side Development and no render worker.

Acceptance criteria:

- A developed event picture matches, byte for byte, the developed result the same phone gives the same original in a personal Film of the same Camera, package version and Film Stock.
- Development of event pictures pauses while the app is in the background and resumes when it comes back, as v1's does.
- No server code develops, re-renders or resizes a picture for display other than the smaller viewing copies the phone itself makes (section 9.4).

#### V2-FR-34 - A picture stays on the phone until the server has it

A picture is never lost between the phone and the album.
Its original stays on the phone until its developed picture is developed, and its developed picture stays on the phone until the server confirms it has received and stored it whole.
Only then does the phone delete its copy (V2-FR-36).
The one exception is an Instant print, whose developed copy stays on its shooter's phone until the reveal (V2-FR-32); its original is deleted on confirmation like any other.
A crash, a closed app, a restart, a full phone or a lost connection never loses a saved picture.

Acceptance criteria:

- Killing the app at any moment during capture, Development or upload loses no saved picture; each finishes on the next launch.
- A picture the server has not confirmed is never deleted from the phone, except by Withdraw Before Reveal, Delete Account, Delete Guest Identity, the Host's Delete Event, or its refusal by the server (a capture time after the server's End Time, or the event gone; V2-FR-31).
- The server confirms a picture only after checking its size and checksum against what the phone sent.

#### V2-FR-35 - The upload queue

Each developed picture waits in the phone's upload queue until it is sent.
The full app uploads in the background where iOS allows it.
The mini-app cannot upload in the background (Apple's rule for App Clips; section 11), so it uploads while it is open, shows how many pictures are waiting and sent, and asks the guest to keep it open or come back through the link until all are sent.
Uploads retry on their own, without the guest doing anything, until the album ends.
The event's page shows each guest how many of their pictures are waiting, without showing the pictures.

Acceptance criteria:

- A guest who shoots offline and opens the app with a connection sees "waiting" fall to zero without doing anything else.
- A picture sent twice, after a lost connection, is stored once.
- The mini-app never says all pictures are sent while one is waiting.

#### V2-FR-36 - Originals never leave the phone

Only the finished, developed picture is uploaded.
The original capture never leaves the phone that took it: not to the server, not to Photos, not to anyone.
Once a picture's developed version is confirmed on the server, its original is deleted from the phone.
There is no Save Originals to Photos for event pictures (the seven-day originals window is left out).

Acceptance criteria:

- No network request ever carries an original capture.
- After the server confirms a picture, its original is gone from the phone's storage, on the Instant too.

#### V2-FR-37 - Pictures are sealed on the server until the reveal

Every uploaded picture is sealed until the event's reveal: nobody can see or download it, not the Host, not the guest who took it, not a web-album viewer, through the app, the join page or any server address.
The one exception is on the phone, not the server: an Instant guest sees their own prints from the developed copies their phone keeps until the reveal (V2-FR-32, V2-FR-34); the server returns nothing to anyone, that guest included.
How sealing is enforced is open check OC-4.

Acceptance criteria:

- Before the reveal, no server operation returns a sealed picture, a thumbnail of it or an address to download it, to anyone.
- Testing the storage directly with a picture's address, without a valid grant issued after the reveal, returns nothing.

### 5.7 The end and the reveal

#### V2-FR-38 - Development and reveal are automatic

At the End Time shooting stops, and at the End Time plus the Reveal Delay, or at once when the Host ends early (V2-FR-40), the event reveals itself: every picture on the server becomes visible to every member at once.
Nobody acts to start it: there is no Private Review, no release by hand, and no step where the Host sees pictures first.
The reveal is timed on the server and happens whether or not anyone has the app open.
Each member's app shows the reveal ritual the first time they open the revealed album.

Acceptance criteria:

- With every phone switched off, the event reveals at End Time plus Reveal Delay, within a minute.
- The Host has no control that holds back or releases the reveal.
- Before the reveal, the event's page counts down to it.

#### V2-FR-39 - The Reveal Delay

The Host chooses the Reveal Delay at creation, from none to 24 hours after the End Time, and may change it while the event is open.
A delay gives late uploads time to arrive before the reveal.
Ending early skips it (V2-FR-40).

Acceptance criteria:

- A delay of 0 reveals at the End Time; a delay of 24 hours reveals 24 hours after it.

#### V2-FR-40 - The Host can end early

While the event is open, the Host can end it early, after a confirmation that says shooting stops for everyone at once, that the album reveals at once, and that unclaimed Rolls return to the balance.
Ending early makes now the End Time and reveals the album at once: the chosen Reveal Delay does not apply.
Pictures still waiting on guests' phones join the album when they arrive (V2-FR-41).

Acceptance criteria:

- Ending early stops shooting on every online phone within a minute and refuses later pictures as V2-FR-31 says.
- The album reveals within a minute of ending early, whatever Reveal Delay was chosen.

#### V2-FR-41 - Late arrivals appear after the reveal

A picture taken before the End Time that reaches the server after the reveal joins the revealed album when it arrives, in its place by capture time.
Late pictures are accepted until the album ends.
The album does not announce each late arrival; members see the new pictures the next time they look.

Acceptance criteria:

- A guest who shot offline and first comes online two days after the reveal sees their pictures appear in the album, and so do the other members.
- A late picture is placed among the others by capture time, not arrival time.

#### V2-FR-42 - What the reveal does not do

**Carried from the parked design:** running out of Rolls, every guest finishing, or pausing joining never reveals anything; only the scheduled reveal does.
The reveal never shows a picture a guest withdrew, a picture the Host or support removed, or a picture of a deleted Account.

Acceptance criteria:

- An event in which every Roll is finished still reveals only at its scheduled time.

### 5.8 The album

#### V2-FR-43 - After the reveal everyone who joined sees every picture

After the reveal, every member sees every picture in the event, in the app and, for a mini-app guest, in the mini-app.
This is one fixed rule; the Host cannot narrow it.
A guest the Host removed does not see the album; a guest who left on their own still does, because everyone who joined sees every picture (V2-FR-56).

Acceptance criteria:

- After the reveal, every member sees the same set of pictures.
- A removed guest's app shows that they can no longer take part, and no picture.
- A guest who left before the reveal sees every picture after it.

#### V2-FR-44 - Saving to Photos, with no account

Any member can save any picture, or the whole album, to Photos, with no Account.
Saving makes an independent copy outside Immerse's control, which removing the picture later cannot recall, and the app says so once before the first save.
Saving the whole album saves every picture visible at that moment, reports how many were saved, and can be resumed if interrupted.
Whether the mini-app can save to Photos itself, since Photos access in an App Clip is limited, is open check OC-6.

Acceptance criteria:

- A guest who never signed in saves the whole album of an event with 1,000 pictures, and Photos holds every picture, each the developed file as uploaded.
- An interrupted whole-album save resumes without saving duplicates.

#### V2-FR-45 - How the album is shown

The album shows every picture in capture order, with numbered gaps where a picture was withdrawn or removed, as a personal Film shows Discarded Frames.
Each picture opens full screen, with its details: Guest Name, capture time, and the Camera.
Members see no editing, captions, likes, comments or reordering.

Acceptance criteria:

- The album's order is capture time across all guests, and removing a picture leaves a numbered gap.

#### V2-FR-46 - The name is never printed on a picture

Contributor Attribution is the picture's details only.
The saved file carries no name in its pixels; whether it carries the name in its metadata is decided with the export format before building (**Proposed engineering approach**: carry none, so a saved copy shared on carries no name).

Acceptance criteria:

- A picture saved to Photos shows no name anywhere in the image.

#### V2-FR-47 - The view-only web album

After the reveal, the Host can switch on a view-only **web album** for the event, on its join page, so Android guests, people who did not shoot and anyone with the link can see and save the pictures.
It is off unless the Host turns it on, and the Host can switch it off at any time; switching it off takes it off the web at once.
The web album shows the pictures in capture order with their Guest Names in each picture's details, lets a viewer save one picture at a time or download the album, and lets nobody shoot, upload, remove, report through it or comment; it shows the support address for reports.
Anyone with the link can see it while it is on; the Host's switch says so.

Acceptance criteria:

- Before the reveal, and whenever the switch is off, the join page shows no picture.
- Within a minute of switching off, no picture loads from the web album, including from an address a viewer copied earlier.
- The web album works in current Safari, Chrome and Firefox on iPhone, Android and a computer.

#### V2-FR-48 - The album is kept 12 months after the reveal

The album, every picture in it and the web album are kept for 12 months after the reveal, then removed from the server for good.
One month before the end, and again one week before, every member sees a notice in the app and on the event's page that the album ends on a date, with a prompt to save what they want; the web album shows the same notice.
These notices are not push alerts: "Your Film is ready" stays the one alert (V2-FR-70), and nobody, the Host included, is emailed before the album ends.
After removal, the link shows "This event is no longer available" and the event leaves every Film Library.

Acceptance criteria:

- Twelve months after the reveal the server holds no picture of the event and no read address works.
- The notices appear one month and one week before the end.
- Pictures members saved to Photos are unaffected.

### 5.9 Control, moderation and deletion

#### V2-FR-50 - Withdraw Before Reveal: a guest pulls all their pictures in one step

Before the reveal, a guest can remove all their own pictures from the event in one step, **Withdraw Before Reveal**, after a warning that the removal is for good, unseen, and returns no exposures.
It removes pictures waiting on their phone (which never upload), the Instant prints their phone keeps, and pictures already on the server, and nothing can bring them back: not the Host, not support, not a late upload.
It offers no preview and no choice of pictures (**carried from the parked design**, ADR 0008).
The guest can keep shooting afterwards with what is left of their Roll, until the End Time.

Acceptance criteria:

- After Withdraw Before Reveal, the reveal shows none of the guest's earlier pictures, each leaving a numbered gap.
- A picture that was waiting on the phone at the time never reaches the server, even if the phone was offline when the guest withdrew.
- The guest's count of exposures does not go back up.

#### V2-FR-51 - A guest removes any of their own pictures after the reveal

After the reveal, a guest can remove any of their own pictures, one at a time, for everyone, after a confirmation.
No exposure is returned.
Copies others already saved cannot be recalled, and the confirmation says so.

Acceptance criteria:

- A removed picture leaves the album and the web album within a minute and leaves a numbered gap.

#### V2-FR-52 - The Host removes any picture

After the reveal, the Host can remove any picture in the event for everyone, after a confirmation.
The Host cannot edit, crop, filter, caption, reorder or otherwise change anyone's picture.
Before the reveal the Host sees no picture and so removes none.

Acceptance criteria:

- The Host's removal works on any guest's picture and leaves a numbered gap.
- No Host control changes a picture's pixels, order or details.

#### V2-FR-53 - The Host removes a guest

While the event is open or revealed, the Host can remove a guest after a confirmation that says every picture the guest took in the event goes with them, for everyone, for good, and that copies members already saved cannot be recalled.
A removed guest can no longer shoot or see the event or its album.
Their pictures go with them: pictures on the server are deleted, each leaving a numbered gap; pictures still waiting on their phone are deleted there when it next comes online and never upload; and the phone deletes the Instant prints it keeps for that event until the reveal.
**Carried from the parked design:** removal is permanent for that guest identity in that event, and the Host cannot undo it.

Acceptance criteria:

- A removed guest's next attempt to join, shoot or open the album is refused on the server, and any picture of theirs that arrives later is refused.
- Within one minute of the removal none of the guest's pictures in the event can be seen or downloaded, in the app or the web album, and each leaves a numbered gap.
- A removed guest's phone deletes its waiting pictures and the Instant prints it keeps for that event when it next comes online, and uploads none.
- The removal does not return their Roll (V2-FR-28).

#### V2-FR-54 - Reporting a picture

After the reveal, any guest can report a picture they think is inappropriate or unsafe.
The report reaches the Host, in the app, and Immerse's support address, with the event, the picture and the reporter's chosen reason, and never the reporter's name to the Host.
A report removes nothing by itself.
Support can remove a reported picture, for everyone, where the Host has not, including in an event whose Host deleted their Account (V2-FR-06), and answers reports within a set time (open question OQ-12).
The support address is published in the app, on the join page and in the App Store listing (App Store guideline 1.2; section 11).

Acceptance criteria:

- A report reaches the Host in the app and the support address within five minutes.
- Support can remove a picture from any event.
- The reporter's identity is not shown to the Host.

#### V2-FR-55 - The Host deletes the whole event

The Host can delete the whole event, at any time before the album ends, after a warning that every picture is removed for everyone, for good, and that copies already saved cannot be recalled.
Deleting it removes every picture and the web album from the server, makes the link show "This event is no longer available", removes the event from every Film Library, deletes pictures still waiting on guests' phones, and the Instant prints those phones keep, when those phones next come online, and returns unclaimed Rolls to the balance (V2-FR-28).

Acceptance criteria:

- Within one minute of deletion no picture of the event can be seen or downloaded anywhere.
- A guest's phone that comes online later deletes its waiting pictures and the Instant prints it keeps for that event, and uploads none.

#### V2-FR-56 - A guest can leave

**Carried from the parked design:** a guest can leave an event; they stop shooting and their Roll stays used.
Their pictures stay in the event, and they keep the right to withdraw them.
A guest who left is still a member: they see the album after the reveal, and get the alert, because everyone who joined sees every picture; only a guest the Host removed loses access (V2-FR-43, V2-FR-53).
While the event is open, a guest who left can rejoin through the event's current link.
Rejoining brings them back to their own Roll and its remaining exposures and takes no new Roll, so it works when every Roll is taken, but not while joining is paused (**Reading**).

Acceptance criteria:

- A guest who leaves can no longer shoot in the event unless they rejoin.
- A guest who left before the reveal sees every picture after it.
- A guest who left and rejoins while the event is open continues their own Roll with the exposures they had left.

#### V2-FR-57 - Delete Guest Identity

**Carried from the parked design:** a guest who never signed in can delete their guest identity on that phone, which removes all their pictures from every event it joined, as Delete Account does for an Account.

Acceptance criteria:

- After Delete Guest Identity, none of that identity's pictures can be seen anywhere, each leaving a numbered gap, its waiting pictures never upload, and the phone deletes the Instant prints it keeps.

### 5.10 Paying

#### V2-FR-60 - Rolls are bought through Apple's in-app purchase

A Host buys Rolls in the full app through Apple's in-app purchase, as consumable purchases, into their signed-in balance.
The mini-app sells nothing.
Rolls are sold in packs of set sizes; their sizes and prices are the open pricing decision (V2-FR-64).
Each purchase is checked on the server with Apple before its Rolls are added, and is added exactly once, however many times the app reports it.
Paying is once per event in the sense that a Host pays for an event's Rolls up front, by exposure count, Roll by Roll, and never per picture or per guest afterwards.

Acceptance criteria:

- A purchase made while signed in adds its Rolls to that Account's balance within a minute, once.
- A purchase reported twice adds its Rolls once.
- A signed-out person who taps Buy is asked to sign in first.

#### V2-FR-61 - The Host's balance

Each Account has one balance of Rolls: bought, credited free, and returned.
Rolls in the balance never expire, as App Store guideline 3.1.1 requires for purchased credits.
A Host sets Rolls aside from the balance for an event at creation and when adding Rolls.
The balance is kept on the server and is the same on every iPhone the Host signs in on.

Acceptance criteria:

- The balance shows the same number on two iPhones signed in to the same Account.
- Rolls bought two years ago are still in the balance.

#### V2-FR-62 - Free Rolls for everyone, and more for subscribers

Every Account gets a very small number of free Rolls, about 3, enough for a small free event, once ever.
An Account linked to a v1 subscriber also gets a clearly larger number, once ever, when the server first confirms the subscription for it: not monthly, not yearly, and not again when the subscription renews.
Free Rolls are credited to the balance and used like bought ones.
Their numbers are the open pricing decision (V2-FR-64).

Acceptance criteria:

- A new Account can host an event of its free Rolls without paying.
- An Account that has had its free Rolls is never credited them again, however many events it hosts.
- A subscriber's Account has the larger number credited once, when the subscription is first confirmed (V2-FR-63), and a renewal credits no more.

#### V2-FR-63 - A subscriber's free Rolls, confirmed with Apple, feed one Account

A subscriber's free Rolls are credited to their balance only after the server has confirmed the subscription with Apple.
The v1 subscription stays account-free for personal Films: the subscriber signs in only to host, and the app then sends the subscription's signed transaction to the server, which verifies it with Apple and links it to that Account.
One subscription feeds one Account: once a subscription is linked, another Account cannot claim its free Rolls, and is told the subscription is already linked to another Account, without naming it.
Moving a subscription's link to another Account goes through support, never through the app.
Subscriber Rolls already credited stay in the balance if the subscription lapses or is refunded.

Acceptance criteria:

- No subscriber free Rolls are credited before Apple's confirmation.
- A second Account presenting the same subscription receives no subscriber free Rolls.
- A subscription that lapses or is refunded credits no further subscriber Rolls, and the subscriber Rolls already credited stay in the balance.

#### V2-FR-64 - The structure is fixed; the numbers are open

This PRD fixes the structure: Rolls sold by exposure count through in-app purchase, one Roll per guest, a free amount for everyone and a larger one for subscribers.
The prices, pack sizes and free amounts are left to the pricing decision still open for the v1 subscription (DEC-02), open check OC-5.

Acceptance criteria:

- No price, pack size or free amount is hard-coded in the app: the server and App Store Connect hold them.

#### V2-FR-65 - Failed, pending and refunded purchases

A purchase that fails or is cancelled adds nothing and changes nothing else.
A purchase that is pending, such as one awaiting Ask to Buy approval, adds its Rolls only when Apple completes it.
When Apple refunds a Roll purchase, the server learns of it from Apple's server notification and removes those Rolls from the balance: Rolls already set aside or used in events stay as they are, and the balance may go below zero, in which case the Host cannot set aside new Rolls until it is above zero again.
A refund that Apple reverses adds the Rolls back.

Acceptance criteria:

- A failed or cancelled purchase leaves the balance unchanged.
- An Ask to Buy purchase adds its Rolls only once approved.
- A refund lowers the balance by the refunded Rolls within an hour of Apple's notification, and never removes a guest's Roll or picture.

### 5.11 The alert, privacy and the copy that changes

#### V2-FR-70 - One alert: "Your Film is ready"

The only push notification in v2 is sent at the reveal: the Film Title and "Your Film is ready", as text only, with no picture.
It goes to every member with the full app who allowed notifications, the Host included.
Opening it checks the person's current access before showing anything.
It is sent from Convex through Apple's push notification service.
**Carried from the parked design:** declining notifications blocks nothing, and there are no capture reminders, activity alerts or upload alerts.

Acceptance criteria:

- Each member with the full app and notifications allowed receives exactly one alert per event, at its reveal.
- A removed guest receives none.
- No other push notification exists in v2.

#### V2-FR-71 - Mini-app guests come back through the same link

Mini-app guests get no alert.
The Join Confirmation and the event's page in the mini-app say when the album reveals and that the same link opens it.
Opening the link after the reveal opens the album in the mini-app, with an invitation to install the full app, which would have alerted them.
The mini-app does not use App Clip notifications.

Acceptance criteria:

- After the reveal, the link opens the album for a mini-app guest, with the invitation to install.

#### V2-FR-72 - Personal Films never leave the iPhone

Personal Films, their captures, developed results, Darkroom edits and details never leave the iPhone in v2, as in v1.
Signing in does not upload, back up or sync any personal Film.

Acceptance criteria:

- No network request carries any part of a personal Film.

#### V2-FR-73 - No advertising or tracking

Event pictures are stored on Immerse's server and used only to run the event.
v2 has no advertising, no tracking, no analytics SDK, no data broker, and no sharing or selling of data.
The server's own aggregate counts, such as how many events ran or pictures arrived, are kept without linking them to a person beyond what the event needs (section 13).

Acceptance criteria:

- The app contains no advertising or analytics SDK.
- The App Store privacy label lists no data used to track.

#### V2-FR-74 - The privacy copy and label change for v2

v1 tells people there is "No Accounts, sign-in, analytics or Immerse server"; that sentence becomes untrue in v2 and is rewritten before v2 ships, to say that personal Films stay on the iPhone and only Group Film pictures and the details listed in section 8 go to Immerse's server.
The privacy policy, the in-app privacy text, the App Store privacy label and the App Clip's own description are updated together.

Acceptance criteria:

- No text in v2 says Immerse has no server or no Accounts.
- The privacy label matches section 8's data.

### 5.12 The services

#### V2-FR-80 - Convex, Cloudflare, Clerk and Apple's push service

The backend uses:

- **Convex** for the data, the server logic and the timed reveal.
- **Cloudflare** for picture storage (R2), the join page and the web album (Workers).
- **Clerk** for sign-in, linked to Convex.
- **Apple's push notification service** for the one alert, sent from Convex.

Section 9 is the proposed engineering approach on these services.

Acceptance criteria:

- Every rule in this PRD that limits who may do what is enforced on the server, never only by hiding something in the app.

#### V2-FR-81 - The server is the authority

The server decides who may join, take a Roll, upload, see, save, remove and report, when an event ends and reveals, and what a balance holds.
The phone is the authority only for what it captured and developed.
Every operation that changes state can be repeated safely: repeating it changes nothing further.

Acceptance criteria:

- Repeating any join, upload, removal, purchase credit or withdrawal request gives the same end state as sending it once.

## 6. States, from creation to the 12-month end

The server holds every state below except a picture's states on the phone, which the phone holds until the server has the picture.

### 6.1 A Group Film (the event)

| State | Means | Entered when | Left when |
| --- | --- | --- | --- |
| Setting up | The Host is choosing title, Camera, Film Stock, rolls and times. Nothing exists on the server yet. | The Host chooses Group Film. | Load Film succeeds (to Open, or to Scheduled when the Host set a later Start Time), or the Host cancels (nothing kept). |
| Scheduled | The event exists and its link and QR code work, showing when it opens; nobody can join or shoot. | Load Film with a later Start Time. | The Start Time (to Open), or the Host deletes the event (to Deleted). |
| Open | Guests can join while Rolls are free and joining is not paused; guests shoot. | Load Film, or the Start Time when the Host set one. | The End Time passes or the Host ends early (to Ended), or the Host deletes the event (to Deleted). |
| Open, joining paused | As Open, but no one new can join. | The Host pauses joining. | The Host resumes (to Open), or as Open. |
| Open, every Roll taken | As Open, but no one new can join until the Host adds Rolls. | The last free Roll is taken. | The Host adds Rolls (to Open), or as Open. |
| Ended | Shooting has stopped; uploads continue; unclaimed Rolls have returned; nobody sees any picture. | The End Time. | End Time plus Reveal Delay (to Revealed), or deletion (to Deleted). With no delay, or when the Host ended early, Ended lasts no time. |
| Revealed | Every member sees every picture; late arrivals join; the web album can be on. | The scheduled reveal. | Eleven months after the reveal (to Ending), or deletion. |
| Revealed, web album on | As Revealed, and anyone with the link sees and saves the pictures on the join page. | The Host switches it on. | The Host switches it off, or as Revealed. |
| Ending | As Revealed, with the album's end notices shown. | One month before the album ends. | Twelve months after the reveal (to Gone), or deletion. |
| Gone | The pictures and the web album are removed; the link says the event is no longer available; the server keeps only the records section 8 keeps for accounting. | Twelve months after the reveal. | Never. |
| Deleted | As Gone, sooner. | The Host deletes the event. | Never. |

A Host's Account deletion does not change these states (V2-FR-06); it removes the Host's controls and pictures.

### 6.2 A Roll

| State | Means | Entered when | Left when |
| --- | --- | --- | --- |
| In the balance | Owned by the Host, not set aside. | Bought, credited free, or returned. | Set aside for an event (to Set aside), refunded (removed), or the Account is deleted (removed). |
| Set aside | Reserved for one event, not yet taken. | The Host creates the event or adds Rolls. | A guest takes it (to Taken), or the End Time or deletion returns it (to In the balance). |
| Taken | One guest's; used. | A guest joins. | The guest uses every exposure (to Finished); otherwise stays Taken. |
| Finished | Every exposure used. | The guest's last saved picture. | Never. |
| Lapsed | Set aside in an event whose Host deleted their Account, never taken, with no balance to return to. | The End Time of such an event. | Never. |

### 6.3 A picture

| State | Where | Means | Next |
| --- | --- | --- | --- |
| Captured | Phone | The original is saved on the phone; an exposure is used. | Developing. |
| Developing | Phone | The phone is developing it (paused while the app is in the background). | Developed. |
| Developed, waiting | Phone | The developed picture is in the upload queue; an Instant shooter can see their own print; nobody else can. | Uploading, or Withdrawn (Withdraw Before Reveal, the guest removed, Delete Account, Delete Guest Identity, or the event deleted). |
| Uploading | Phone and server | It is being sent; the phone keeps its copy. | Sealed (the server confirms it whole), or back to Developed, waiting (failed; retried). |
| Sealed | Server | Stored, unseen by anyone through the server; the phone deletes its original and developed copy, except that an Instant print's developed copy stays on its shooter's phone, seen only by its shooter, until the reveal. | Revealed (at the reveal), Withdrawn, or Removed (its guest removed, or deletion). |
| Revealed | Server | Every member sees it, and web-album viewers while the web album is on. | Removed by its shooter, the Host or support, Removed with its guest, Removed by deletion, or Gone at the album's end. |
| Arrived late | Server | Reached the server after the reveal; becomes Revealed on arrival. | As Revealed. |
| Refused | Phone | Its capture time is after the server's End Time, or the event is gone; the phone deletes it and tells the guest. | Never. |
| Withdrawn or Removed | Server and phone | Its media is deleted everywhere it was kept; a numbered gap remains in the album. | Never. |
| Lost | Phone | The phone was lost, broken or wiped before the picture reached the server. Nothing can bring it back. | Never. |
| Gone | Server | The album ended. | Never. |

### 6.4 A guest

| State | Means | Next |
| --- | --- | --- |
| Joined, on this phone | Has a Roll and a guest identity bound to this phone. | Signed in (claims the identity), Left, Removed, Deleted, or Lost with the phone. |
| Joined, signed in | The identity belongs to an Account; works on any iPhone signed in to it. | Left, Removed, or Deleted (Delete Account). |
| Left | Stopped shooting; Roll used; pictures stay; still a member, who sees the album after the reveal (V2-FR-56). | Rejoined (back to Joined, on their own Roll) while the event is open, or Removed, or Deleted. |
| Removed | Cannot shoot, upload or see the event; every picture of theirs in it is removed (V2-FR-53). | Never back in this event. |
| Deleted | Delete Account or Delete Guest Identity removed every picture. | Never. |
| Lost | An unsigned guest's phone was lost or replaced; uploaded pictures stay, nobody can act for them. | Never. |

### 6.5 An Account and a purchase

| Thing | States |
| --- | --- |
| Account | Signed out (none) → Signed in (age confirmed) → Deletion requested → Deleted. A deleted Account's events follow V2-FR-06. |
| Subscription link | Not linked → Linked to one Account (after Apple's confirmation; its free Rolls credited once) → Lapsed or Refunded (no further subscriber Rolls; those already credited stay). Support alone can move the link to another Account. |
| Roll purchase | Started → Pending (Ask to Buy) → Completed and verified (Rolls added once) → possibly Refunded (Rolls removed) → possibly Refund reversed (Rolls added back); or Failed or Cancelled (nothing added). |

## 7. Failure and edge cases

| Case | What happens | Requirement |
| --- | --- | --- |
| A guest shoots with no signal after joining | Every picture is saved and developed on the phone and waits; uploads run when the phone is online and the app (or mini-app) is open. | V2-FR-31, V2-FR-35 |
| A guest closes the mini-app with pictures waiting | Nothing uploads until they open the link again; the mini-app warned them; the pictures stay on the phone. | V2-FR-35; open check OC-10 |
| iOS removes the mini-app's data before its pictures upload | Those pictures are lost; the mini-app's warnings, the full app's background upload and open check OC-10 exist to make this rare. | V2-FR-35, risk RK-V2-04 |
| A picture arrives after the reveal | It joins the album in capture order. | V2-FR-41 |
| A picture taken after the End Time on a phone that did not know the End Time moved earlier | The server refuses it and the guest is told. | V2-FR-31 |
| A guest's phone clock is wrong | Shooting stops by the server's End Time once the phone has been online since joining; the capture time a phone reports is accepted as it is. | V2-FR-31, risk RK-V2-09 |
| The Host removes a guest before the reveal | The guest stops shooting and loses access, and every picture of theirs is removed, unseen; the album reveals with numbered gaps in their place. | V2-FR-53 |
| The Host removes a guest after the reveal | Their pictures leave the album and the web album within a minute, leaving numbered gaps; copies members saved to Photos cannot be recalled. | V2-FR-53, V2-FR-44 |
| A removed guest's phone comes online with pictures waiting | The phone deletes the waiting pictures and the Instant prints it keeps for that event, uploads none, and says the guest was removed. | V2-FR-53 |
| A removed guest tries the link again, or a replaced code | Refused: their identity, or the Account it was claimed into, is blocked in that event. | V2-FR-24 |
| A guest leaves and wants to come back | While the event is open and joining is not paused, they rejoin through the current link and continue their own Roll; after the End Time they cannot shoot again, and they still see the album after the reveal. | V2-FR-56 |
| A guest who left before the reveal | Sees every picture after the reveal, and gets the alert if they have the full app. | V2-FR-56, V2-FR-70 |
| A guest signs in to an Account that already holds a place in the same event | Both places stay as they were, each with its own Roll and pictures; the app explains. | V2-FR-04 |
| A guest deletes their Account | Every picture of theirs is removed everywhere, numbered gaps remain, waiting pictures never upload. | V2-FR-05 |
| An unsigned guest loses or replaces their phone | Their place is lost with no recovery; uploaded pictures stay theirs in the album; nobody can withdraw them through the app, though support can remove one on request. | V2-FR-04, V2-FR-54 |
| The Host deletes their Account before the reveal | The event runs on, reveals, and stays 12 months; no one can change it; reports go to support. | V2-FR-06 |
| The Host deletes their Account after the reveal | The album stays for the rest of its 12 months without the Host's pictures. | V2-FR-06 |
| Someone opens the link before the Start Time | The join page and the app show when the event opens; nobody can join. | V2-FR-12, V2-FR-18 |
| Joining is paused | The link works but admits no one new; joined guests keep shooting. | V2-FR-16 |
| The code is replaced | The old link and every printed copy stop working at once; joined guests are unaffected. | V2-FR-17 |
| A printed code is replaced by mistake | It cannot be restored; the Host prints the new one. | V2-FR-17 |
| Every Roll is taken | No one new can join until the Host adds Rolls; the join page says so. | V2-FR-18, V2-FR-27 |
| The event reaches 200 Rolls | No more can be added; the app says the limit is reached. | V2-FR-26 |
| Two people take the last Roll together | One gets it; the other is told every Roll is taken. | V2-FR-24 |
| The Host's balance is too small to set Rolls aside | The app offers to buy Rolls or set aside fewer. | V2-FR-60 |
| A Host who has used their free Rolls hosts again | They buy Rolls; free Rolls are never given to the same Account again. | V2-FR-62 |
| A purchase fails or is cancelled | Nothing is added; the Host can try again. | V2-FR-65 |
| A purchase is pending (Ask to Buy) | Its Rolls are added when Apple completes it. | V2-FR-65 |
| A purchase is refunded | The Rolls are removed from the balance, which may go below zero; events already running are untouched. | V2-FR-65 |
| A refunded purchase's refund is reversed | The Rolls are added back. | V2-FR-65 |
| A subscriber's subscription lapses or is refunded | No further subscriber free Rolls; those already credited stay in the balance. | V2-FR-63 |
| The same subscription is presented by a second Account | No subscriber free Rolls for it; the app says the subscription is linked elsewhere. | V2-FR-63 |
| A subscriber wants the subscription linked to another Account | Support moves the link on request; the app cannot. | V2-FR-63 |
| The Host deletes the event while guests are offline and shooting | Their phones delete the event's waiting pictures and the Instant prints they keep when they come online, and say the event was deleted. | V2-FR-55 |
| A guest withdraws before the reveal while offline | The phone deletes its waiting pictures at once and tells the server when online; nothing that was waiting ever uploads. | V2-FR-50 |
| A picture is reported | It reaches the Host and support; nothing is removed until one of them removes it. | V2-FR-54 |
| Someone opens the link on Android, a computer or iOS before 26 | The join page explains, and shows the web album when the Host has it on. | V2-FR-18 |
| The mini-app is too large for Apple's cap | Guests install the full app from the join page. | V2-FR-19, open check OC-1 |
| A guest declines the Camera permission | The shooting screen explains how to allow it, as in v1; the Roll stays theirs. | V2-FR-31 |
| A member declines notifications | They get no alert and see the album when they next open the app or link. | V2-FR-70 |
| A member declines Photos access | Saving says how to allow it; nothing else is blocked. | V2-FR-44 |
| The phone runs out of storage while shooting | The camera says so as v1's does; pictures already saved stay; the low-storage warning of v1 also shows on the event's page. | V2-FR-34 |
| Development fails on a phone (for example a renderer without Metal for a color stock) | The picture stays waiting and Development retries; if it can never develop on that phone, the guest is told and the original stays on the phone; it never uploads undeveloped. | V2-FR-33, V2-FR-36 |
| The Host ends early | Shooting stops and the album reveals at once; the Reveal Delay does not apply; pictures still waiting arrive late and join the album. | V2-FR-40, V2-FR-41 |
| The server is unreachable at the End Time or the reveal | Shooting stops by each phone's known End Time; the reveal runs on the server when it is reachable again, and its delay is reported (success measure M-3). | V2-FR-38 |
| The web album is switched off while someone is viewing it | Their next picture load fails and the page says the pictures are no longer shared. | V2-FR-47 |
| Saving the whole album is interrupted | It resumes without duplicates. | V2-FR-44 |
| The album ends | Pictures and the web album are removed; saved copies are unaffected. | V2-FR-48 |

## 8. What the backend holds

The backend holds only what running events needs.
It never holds a personal Film, an original capture, a location, a contact list, an advertising identifier or anything for analytics.

| Record | Held | Kept until |
| --- | --- | --- |
| Account | Clerk's user id, the confirmation of age 13 or over and when it was given, the display name the Host chose, the creation time. Clerk itself holds the sign-in method and email or Apple or Google identity. | Delete Account. |
| Roll balance and ledger | Each purchase credit, free credit, set-aside, return, refund and reversal, with Apple's transaction id. | Delete Account, except purchase records needed for accounting and refunds, which are kept without the person's name or user id for as long as the law requires. |
| Subscription link | Apple's original transaction id for a confirmed subscription, linked to one Account. | Delete Account. |
| Push token | The device token for the alert, per signed-in or joined installation of the full app. | Sign-out, Delete Account, removal, or the token's rejection by Apple. |
| Guest identity | A random id and a secret's verifier, never a device identifier; the Account it was claimed into, if any. | Delete Guest Identity, Delete Account, or 12 months after the last album it took part in ends. |
| Event | Title, Host, Camera, Film Stock, Camera package and treatment versions, Rolls set aside and taken, Start Time if any, End Time, Reveal Delay, joining state, Join Code (stored as a verifier), web album switch, reveal time, state. | Twelve months after the reveal, or deletion; then a minimal record of its Rolls for the balance ledger. |
| Membership | Which guest identity or Account holds which Roll in which event, the Guest Name, exposures used, left or removed. | The event's end, as above. |
| Picture | Event, shooter, exposure number, capture time, upload and seal state, size, checksum, storage key, removed or withdrawn. The picture itself is in Cloudflare R2, with a smaller viewing copy (section 9.4). | Its removal, withdrawal, the shooter's deletion, or the event's end; a removed picture leaves only its number. |
| Report | The picture, the reason, when, and which member reported (never shown to the Host). | Ninety days after it is resolved, or the event's end if sooner (**Proposed**). |
| Removal markers | That a picture or a guest's pictures were withdrawn or removed, so a late upload cannot bring them back. | The event's end. |
| Operational logs | Requests and errors, without picture content, kept for running the service. | Thirty days (**Proposed**). |

## 9. Proposed engineering approach on the chosen services

This section is a proposed engineering approach.
The services are decided (V2-FR-80); how they are used may change without a product decision, as long as every requirement holds.

### 9.1 The shape

```text
 iPhone: full app or mini-app (iOS 26)
   Cameras + Development (as v1) | upload queue | album | StoreKit (full app only) | Clerk sign-in (full app)
        |  data and logic (websocket)         |  picture bytes (one-time addresses)
        v                                     v
   Convex: tables, server functions,     Cloudflare R2: private picture bucket
   timed reveal (scheduled functions),   Cloudflare Workers: join page and web album,
   Apple purchase checks, push sender    reading R2 directly; links and App Clip metadata
        |                                     ^
        |  verifies Clerk sessions            |  web album reads only revealed, shared events
        v                                     |
   Clerk (Apple, Google, email)          Convex grants the Worker what it may show
   Apple: App Store Server API and notifications; Apple push notification service
```

There is no render worker: every picture is developed on the phone that took it (V2-FR-33), so the server stores and serves finished files only.
This replaces the "render worker" in the v1 architecture's list of parts deferred to v2.

### 9.2 Sign-in and the guest identity (open check OC-4)

- A Host signs in with Clerk's iOS SDK; the app passes Clerk's session token to Convex, which verifies it against Clerk's issuer, as Convex's Clerk integration describes; Clerk publishes a Convex adapter for Swift.
- A guest identity is a random id and secret made on the phone at joining; Convex stores only a verifier of the secret and gives the phone a short-lived token for that guest in that event.
  Whether that token rides on Convex's custom authentication or on an argument every guest function checks is the open check.
- Claiming a guest identity links its id to the Account on the server; the phone's secret is then retired.

### 9.3 The upload path (open check OC-3)

1. The phone asks a Convex function for permission to upload one developed picture, naming its event, exposure number, size and checksum.
2. Convex checks the guest's membership, the event's state and the exposure, records the picture as uploading, and returns a one-time upload address: a presigned R2 PUT address, signed in Convex with R2's S3-compatible credentials, for one unguessable key, valid for a few minutes and bound to the picture's content type.
3. The phone sends the file straight to R2 at that address.
4. The phone tells Convex it is done; Convex checks the object's size and checksum in R2 and only then marks the picture sealed and tells the phone it may delete its copy.

Cloudflare's documentation says presigned addresses support PUT, last from 1 second to 7 days, must be signed with an S3 client because the Workers binding cannot sign them, fail if the content type differs from the signed one, and work only on R2's S3 domain, not a custom domain.
The page does not say a presigned PUT can enforce a size, which is why step 4 checks it.
No official example of a presigned R2 upload from an iPhone app was found; the open check builds one.

### 9.4 Sealing, viewing and the web album (open check OC-4)

- The R2 bucket is private: no public access and no public domain for pictures.
- Before the reveal, Convex issues no read address for any picture and the Worker serves none.
- After the reveal, a member's app asks Convex for read addresses; Convex checks current membership and returns short-lived presigned GET addresses.
- The phone uploads, beside each developed picture, a smaller viewing copy it makes itself, so browsing the album does not download every full picture; saving downloads the full one.
- The join page and the web album are a Cloudflare Worker reading R2 through its binding; it shows pictures only for an event that has revealed, has its web album switched on and is not gone, which it learns from Convex.
- Whether sealing also needs the pictures encrypted with a key that only the reveal releases, so that even a leaked storage address shows nothing before the reveal, is part of the open check.

### 9.5 The timed reveal and the album's end

- Load Film schedules the event's opening at its Start Time, if any, and its end and reveal with Convex's scheduler at their exact times; changing the Start Time, the End Time or the delay, ending early (which reveals at once), or deleting the event cancels and reschedules them.
- Convex's documentation says a scheduled mutation runs exactly once and can be cancelled before it starts, and that functions can be scheduled months ahead, which also serves the 12-month removal and its notices.
- Each scheduled step is safe to repeat and checks the event's current state first.

### 9.6 The alert

Convex sends "Your Film is ready" at the reveal through Apple's push notification service with token-based authentication.
Apple's service needs HTTP/2; whether a Convex action can make that request, or needs a small relay, is open check OC-7.

### 9.7 Purchases

- The full app buys a consumable Roll pack with StoreKit 2, setting the purchase's app account token to a value Convex gave that Account, which Apple returns in the transaction so the server can link the purchase to the Account.
- The app sends the signed transaction to Convex, which verifies it with Apple, credits the Rolls once by transaction id, and only then lets the app finish the transaction.
- Convex receives App Store Server Notifications; Apple's documentation lists a REFUND notification for consumable purchases and a REFUND_REVERSED notification when a refund is reversed, which drive V2-FR-65.
- For a subscriber's free Rolls, the app sends the subscription's signed transaction; Convex verifies it and links its original transaction id to one Account (V2-FR-63).

### 9.8 Deletion

- Delete Account calls Clerk's delete for the signed-in user, which Clerk's iOS reference documents as `user.delete()`, and Convex removes the person's records and R2 objects; Clerk's `user.deleted` webhook to Convex catches a deletion made anywhere else.
- Removals write a marker before deleting media, so a late or repeated upload cannot bring a removed picture back.

## 10. Costs: Convex against Cloudflare for pictures (open check OC-2)

### 10.1 Prices read on 2026-11-22

| Service | Price | Source |
| --- | --- | --- |
| Convex Professional | $25 per developer per month; includes 100 GB file storage, 50 GB data egress, 25M function calls; then $0.03 per GB of file storage and $0.12 per GB of egress per month | https://www.convex.dev/pricing |
| Convex Free and Starter | 1 GB file storage and 1 GB egress included; then $0.033 per GB of storage and $0.132 per GB of egress | https://www.convex.dev/pricing |
| Convex limits | Limits apply per team; queries and mutations run up to 1 second, actions up to 30 minutes (10 minutes on the Node runtime); 1,000,000 outstanding scheduled functions | https://docs.convex.dev/production/state/limits |
| Cloudflare R2 Standard | $0.015 per GB-month; Class A operations (uploads) $4.50 per million; Class B (downloads) $0.36 per million; egress free; free each month: 10 GB-month, 1 million Class A, 10 million Class B | https://developers.cloudflare.com/r2/pricing/ |
| Cloudflare R2 limits | Single upload up to 5 GiB; presigned addresses valid 1 second to 7 days | https://developers.cloudflare.com/r2/platform/limits/ and https://developers.cloudflare.com/r2/api/s3/presigned-urls/ |
| Cloudflare Workers | Free: 100,000 requests a day; Paid: $5 a month minimum, 10 million requests included then $0.30 per million; no charge for egress; static asset requests free | https://developers.cloudflare.com/workers/platform/pricing/ |
| Clerk Hobby | Free; 50,000 monthly retained users per app; fixed 7-day session lifetime; Clerk branding on prebuilt screens; up to 3 social connections; email codes and links | https://clerk.com/pricing |
| Clerk Pro | $25 a month, or $20 a month billed yearly; 50,000 monthly retained users included, then $0.02 each; custom session lifetime; no Clerk branding | https://clerk.com/pricing |

Only Hosts and guests who choose to sign in are Clerk users, so Clerk's included users are unlikely to be the first limit.

### 10.2 Estimate per event

Assumptions, all to be replaced by measurement in the open check:

- Every Roll is taken and finished, on the Disposable: 27 pictures a Roll.
- A developed Disposable picture is a JPEG of up to 12 megapixels, as v1 exports it; its file size is assumed to average 4 MB (unmeasured; a 6×6 picture is 3072 × 3072 and an Instant print 2282 × 2774, so both are smaller).
- Every member downloads every full picture once (Host plus one member per Roll); viewing copies are ignored.
- Pictures are kept 12 months; 1 GB is taken as 1,000 MB.
- Included allowances are ignored, since they are shared across every event in a month.

| Event | Pictures | Stored | Downloaded | R2: 12 months' storage + uploads + downloads | Convex: 12 months' storage + egress |
| --- | --- | --- | --- | --- | --- |
| 3 Rolls (the free size) | 81 | 0.32 GB | 1.3 GB | about $0.06 | about $0.27 |
| 25 Rolls | 675 | 2.7 GB | 70 GB | about $0.50 | about $9.40 |
| 100 Rolls | 2,700 | 10.8 GB | 1,091 GB | about $2.05 | about $134.78 |
| 200 Rolls (the limit) | 5,400 | 21.6 GB | 4,342 GB | about $4.30 | about $528.77 |

How the R2 column is made, for the 200-Roll event: 21.6 GB × $0.015 × 12 months = $3.89 storage; 5,400 uploads × $4.50 per million = $0.02; 201 members × 5,400 downloads = 1,085,400 Class B operations × $0.36 per million = $0.39; egress free.
The Convex column: 21.6 GB × $0.03 × 12 = $7.78 storage; 4,342 GB × $0.12 = $520.99 egress.

Reading: downloads, not storage, decide the cost, and R2's free egress makes the plan's choice of Cloudflare for picture storage far cheaper at every event size; Convex's file storage would cost more than any likely price of a large event.
The open check confirms it by measuring real file sizes, real download behavior with viewing copies, and Convex's own costs for data and functions per event.

## 11. Privacy and App Store review

Apple's rules below were read on 2026-11-22 from the pages listed in section 17.

### 11.1 The mini-app (App Clip)

| Apple's rule | What it means for v2 |
| --- | --- |
| Apple's size table for the uncompressed App Clip binary reads: 10 MB for "iOS 15 and earlier", 15 MB for "iOS 16 and earlier" and 25 MB for "iOS 27.3 and later". Starting with iOS 17 it may be up to 100 MB only if it supports digital invocations alone (no App Clip Codes, QR codes or NFC tags), is used where a reliable connection is likely, and does not support iOS 16 or earlier; the App Clip demo link that App Store Connect generates also allows 100 MB with physical invocations. | Guests join by QR code, a physical invocation, so the mini-app must fit the smaller limit unless the demo link can carry each event's link, or the mini-app is opened from links alone. Read together, the table appears to leave iOS 26 to 27.2 at 15 MB for a QR-opened App Clip; open check OC-1 confirms the limit and measures the mini-app. |
| "All App Clip features and functionality must be included in the main app binary. App Clips cannot contain advertising." (guideline 2.5.16) | Everything the mini-app does, the full app does too (V2-FR-19); neither has advertising (V2-FR-73). |
| App Clips can't perform background activity, including background networking with URLSession. | The mini-app uploads only while open (V2-FR-35). |
| In-app purchases are reserved for the full app in an in-the-moment App Clip. | The mini-app sells nothing; Rolls are bought in the full app (V2-FR-60). |
| PhotoKit provides no functionality in an App Clip, and App Clips can't access data from Photos. | Saving to Photos from the mini-app may be limited (V2-FR-44; open check OC-6). |
| App Clips can't share data with any app except their own full app. | The mini-app hands a guest's place to the full app on install (V2-FR-19). |
| App Clips can schedule or receive notifications for up to 8 hours after each launch, if enabled. | Not used: mini-app guests come back through the link (V2-FR-71). |
| App Clips can't request tracking authorization. | Consistent with no tracking (V2-FR-73). |

### 11.2 Accounts, sign-in and age

- "If your app supports account creation, you must also offer account deletion within the app." (guideline 5.1.1(v)) - Delete Account is in the app (V2-FR-05).
- "If your app doesn't include significant account-based features, let people use it without a login." (guideline 5.1.1(v)) - guests and personal Films never sign in (V2-FR-02).
- Guideline 4.8: an app that uses a third-party login such as Google Sign-In to set up the primary account "must also offer as an equivalent option another login service" that limits data collection to name and email, lets people keep their email private, and does not collect app interactions for advertising without consent - Sign in with Apple is offered beside Google (V2-FR-01).
- Accounts are for people 13 or over (V2-FR-03); the App Store age rating, the privacy policy and the sign-in screen say so, and how age is confirmed is open check OC-9.

### 11.3 In-app purchase

- Rolls unlock event capacity, a digital good, so they are sold through in-app purchase (guideline 3.1.1).
- "Any credits or in-game currencies purchased via in-app purchase may not expire" (guideline 3.1.1) - the balance never expires (V2-FR-61).
- Rolls are consumables held on the server against an Account, so a Host restores them by signing in, not through StoreKit's restore (V2-FR-61).
- Refunds arrive as App Store Server Notifications and are handled as V2-FR-65 says.
- The review notes explain the free Rolls, the subscriber's larger free amount and that hosting needs no subscription.

### 11.4 User-generated content

Guideline 1.2 requires an app with user-generated content to include "A method for filtering objectionable material from being posted to the app", "A mechanism to report offensive content and timely responses to concerns", "The ability to block abusive users from the service" and "Published contact information so users can easily reach you".

| Requirement | v2 |
| --- | --- |
| Filtering | Pictures are seen only by the event's members, and nothing is public unless the Host switches on the web album; the Host removes any picture and support removes reported ones. Whether App Review accepts this as filtering, or wants automatic screening before the reveal, is risk RK-V2-06; any automatic screening would have to keep V2-FR-73's no-tracking promise. |
| Reporting and timely responses | Report a picture to the Host and support (V2-FR-54), with a response time set by open question OQ-12. |
| Blocking abusive users | The Host removes a guest, permanently for that event and with every picture they took in it (V2-FR-53). |
| Published contact information | The support address in the app, on the join page and in the App Store listing (V2-FR-54). |

### 11.5 Privacy

- Personal Films never leave the iPhone (V2-FR-72).
- Event pictures, Guest Names, Accounts and the records in section 8 are held on Convex, Cloudflare and Clerk, which the privacy policy names as processors.
- No advertising or tracking (V2-FR-73); the privacy label lists Contact Info (the Host's email or name), User Content (photos), Identifiers (Account and guest ids) and Purchases, all for app functionality and none for tracking.
- The privacy copy that says Immerse has no server or Accounts is rewritten (V2-FR-74).
- Deletion: Delete Account (V2-FR-05), Delete Guest Identity (V2-FR-57), Withdraw Before Reveal (V2-FR-50), removing a picture (V2-FR-51) and the 12-month end (V2-FR-48) remove media from the server; saved copies outside Immerse cannot be recalled, and each place says so.

## 12. Order of building: four stages

v2 work starts only after v1 is on the App Store.
Each stage ends with what it proves on real iPhones and on the real services; compile-only or simulator evidence is not a pass.
Tasks for each stage are written into the tracker once this PRD is approved.

### Stage 1 - The backend and sign-in

Builds: the Convex project with the data of section 8, Clerk sign-in with Apple, Google and email linked to Convex, the age confirmation, Delete Account, the private R2 bucket with the one-time upload and read addresses, and a Convex-to-Apple push test.
Personal Films, the Trial and the subscription are untouched.

Proves:

- A Host can sign up, sign in on a second iPhone, stay signed in for eight days without a prompt (OC-8), and delete their Account, removing everything section 8 says.
- A picture-sized file goes from the iPhone to R2 through a Convex-issued one-time address, is confirmed by size and checksum, and cannot be read without a grant (OC-3, OC-4).
- A push notification reaches an iPhone from Convex (OC-7).
- With the network off, every v1 personal Film action works as before.
- The mini-app's size is measured with the three Cameras inside, so stage 3's plan is known early (OC-1).

### Stage 2 - Events in the full app, with free Rolls only

Builds: creating a Group Film with an optional later Start Time, the Join Code with its link and QR code opening the full app, joining, Rolls, shooting offline, Development on the phone, the upload queue, sealing, the timed reveal, the album, saving, Withdraw Before Reveal, removals, removing a guest with their pictures, reporting, deleting the event, leaving and rejoining, ending early, the alert, the 12-month end and its notices, and a deleted Host's events.
Guests install the full app; Rolls are free Rolls only.

Proves:

- A whole event on real iPhones: a Host and several guests, some shooting offline, one joining late, one coming online two days after the reveal; every picture taken reaches the album (M-1), the reveal happens on time with every phone off (M-3), and nobody sees a picture before it.
- Every case of section 7 that does not need the mini-app or purchases.
- The cost of an event, measured, against section 10's estimate (OC-2).

### Stage 3 - The no-install mini-app and the join page

Builds: the App Clip, the join page and its messages for everyone who cannot join, the web album and its switch, and the hand-off from the mini-app to the full app.
If OC-1 found the mini-app cannot fit, this stage builds the join page, its messages and the web album, and the join page sends guests to install the full app.

Proves:

- A guest with no app installed scans a printed QR code and is shooting within the time of success measure M-2, with only a name and one tap.
- A mini-app guest's place, pictures and uploads survive installing the full app.
- An Android phone and a computer see the right message, and the web album when it is on, and nothing when it is off.
- What the mini-app can save to Photos (OC-6).

### Stage 4 - Buying Rolls and the subscriber benefit

Builds: Roll packs through in-app purchase, the balance, failed, pending and refunded purchases, and the subscriber's free Rolls confirmed with Apple.
Prices and free amounts are set by the pricing decision before this stage starts (OC-5).

Proves:

- A purchase in Apple's sandbox credits its Rolls once, on the server, and a refund notification removes them.
- A subscriber's Account gets its larger free Rolls only after Apple's confirmation, and a second Account with the same subscription gets none.
- App Review accepts the purchases, the sign-in, account deletion, the App Clip and the user-generated content features.

## 13. Measures of success

v2 has no analytics.
These measures come from the server's own aggregate counts, App Store Connect, Apple's crash reports, support reports and interviews with Hosts.

| ID | Measure | Target |
| --- | --- | --- |
| M-1 | Pictures that reach the album, of pictures taken on phones that came back online with the app opened | At least 99.9 percent, and no confirmed case of a picture lost after the server confirmed it |
| M-2 | Time from scanning a QR code with no app installed to the shooting screen, on an iPhone 12 or later on a normal mobile connection, not counting typing the name | Under 10 seconds (**Proposed**) |
| M-3 | Reveals that happen within one minute of their scheduled time | At least 99.9 percent |
| M-4 | Hosts asked to sign in again while an event they host is open or awaiting its reveal | None |
| M-5 | Unclaimed Rolls returned to the Host's balance at the End Time | All |
| M-6 | Crash-free sessions in the mini-app and the full app | At least 99.5 percent |
| M-7 | Reports answered by support within the time open question OQ-12 sets | All |
| M-8 | Storage and download cost per event | Within section 10's estimate once measured |
| M-9 | Events with more than the free Rolls, and Hosts who host a second event | Learned from App Store Connect and the server's counts, with targets set at the pricing decision |
| M-10 | App Review | v2, its App Clip and its purchases accepted without a rejection for the features this PRD specifies |

## 14. Risks

| ID | Risk | Effect | Early check or mitigation |
| --- | --- | --- | --- |
| RK-V2-01 | The mini-app does not fit Apple's limit for a QR-opened App Clip (15 MB in Apple's table, 25 MB from iOS 27.3) with the three Cameras' looks inside. | Guests must install the full app, losing the no-install join. | Measure in stage 1 (OC-1); the decided fallback is installing the full app (V2-FR-19). |
| RK-V2-02 | Downloads cost more than estimated, or a large event's members download repeatedly. | Margin per event shrinks. | Pictures on R2, whose egress is free; viewing copies; measure in stage 2 (OC-2). |
| RK-V2-03 | Clerk's free plan fixes sessions at 7 days, shorter than an event of 7 days plus 24 hours. | Hosts signed out mid-event, the complaint Once's reviewers make. | Open check OC-8: Clerk Pro's custom session lifetime, or the SDK refreshing the session while the app is used. |
| RK-V2-04 | iOS removes a mini-app's data before its pictures upload, or a guest never reopens it. | Lost pictures. | The mini-app's warnings and counts, prompting the full app, measuring when iOS removes App Clip data (OC-10). |
| RK-V2-05 | A phone cannot develop a picture (for example the color stocks' table reader without Metal). | A picture that never reaches the album. | The original stays on the phone and Development retries; the same rule as v1 (V2-FR-33). |
| RK-V2-06 | App Review asks for automatic filtering of user-generated content. | A rejection, or a moderation service that conflicts with no tracking. | Explain the sealed, members-only design in review notes; any screening must run without tracking. |
| RK-V2-07 | Sealing leaks: a read address or a cached copy shows a picture before the reveal. | The product's central promise broken. | No read address before the reveal, a private bucket, tests that try direct reads (OC-4), and encryption if the check says so. |
| RK-V2-08 | Apple's push service needs HTTP/2, which a Convex action may not offer. | No "Your Film is ready". | Open check OC-7; a small relay if needed. |
| RK-V2-09 | A guest's phone clock is wrong, so pictures carry wrong times or a guest shoots past the End Time while offline. | Odd order in the album; a few pictures after the end. | The server's End Time is applied whenever the phone has been online; pictures stamped after it are refused; the remaining error is accepted. |
| RK-V2-10 | Fraud or abuse: guessed codes, spam joins, refunded purchases used for large events, new Accounts made for their free Rolls. | Unwanted guests or unpaid Rolls. | Unguessable codes and rate limits, pause and replace, removal, refunds removing Rolls (V2-FR-65), free Rolls once per Account (V2-FR-62). |
| RK-V2-11 | A vendor changes its prices or limits. | Costs or limits move. | Prices recorded with their date (section 10); data and pictures kept in portable formats. |
| RK-V2-12 | Developing every picture on phones heats or slows older iPhones during an event. | A slow camera or battery drain at the event. | Develop while the app is open and the camera idle; measure on the oldest supported iPhone in stage 2. |

## 15. Open checks

Each is a fact to establish before the work it affects is promised.
None is settled by this document.

| ID | Open check | How it gets answered | Before |
| --- | --- | --- | --- |
| OC-1 | Whether the mini-app fits Apple's size cap with the three Cameras' looks (the Disposable, the 6×6 with both Film Stocks, the Instant) inside. Apple's size table lists 15 MB uncompressed (its row reads "iOS 16 and earlier") and 25 MB for iOS 27.3 and later; 100 MB needs digital-only invocation or the App Store Connect demo link. Which limit applies to a QR-opened App Clip on iOS 26 is part of this check. | Build an App Clip target with the capture and Development code and the three Cameras' look assets, export it, and read Xcode's App Thinning Size Report for every variant; test whether the demo link can carry each event's link and QR code. If it does not fit, guests install the full app (V2-FR-19). | Stage 3 is planned (measure in stage 1). |
| OC-2 | Convex's current price for downloads and file storage against Cloudflare's, with storage and download cost per event size. Section 10 gives the prices read on 2026-11-22 and an estimate on assumed file sizes. | Measure real developed file sizes per Camera, viewing-copy sizes and download behavior in stage 2's events, and Convex's own data and function costs per event; recompute section 10. | Prices are set (OC-5). |
| OC-3 | The iPhone upload path: the app asks Convex for a one-time upload address and sends the finished picture straight to Cloudflare. No official iPhone example was found. | Build the path of section 9.3 in stage 1: sign an R2 presigned PUT in a Convex action with an S3 signer, upload from URLSession on an iPhone over a poor connection, confirm by size and checksum, and test expiry, a wrong content type, a repeated upload and a killed app. | Stage 2. |
| OC-4 | How a guest with no account is identified to Convex and Cloudflare, and how sealed pictures stay unreadable before the reveal. | Build the guest token of section 9.2 and the read grants of section 9.4 in stage 1; try every way to read a sealed picture (direct R2 addresses, expired or reused grants, the Worker, a removed guest's token); decide whether encryption with a reveal-released key is needed. | Stage 2. |
| OC-5 | The actual prices, Roll pack sizes and free amounts, for everyone and for subscribers. | The pricing decision still open for the v1 subscription (DEC-02), using section 10's measured costs. | Stage 4. |
| OC-6 | What the mini-app can save to Photos, since PhotoKit gives no functionality in an App Clip. | Test, in an App Clip on iOS 26, saving one picture through the share sheet and saving many; if it cannot, the mini-app sends the guest to the full app or the web album to save. | Stage 3. |
| OC-7 | Whether a Convex action can send to Apple's push service, which needs HTTP/2 and token-based authentication. | Send a test alert from a Convex action in stage 1; if it cannot, add the smallest relay that can, on Cloudflare. | Stage 2. |
| OC-8 | How a Host stays signed in for an event of 7 days plus a 24-hour delay, when Clerk's free plan fixes sessions at 7 days. | Test the Clerk iOS SDK's session refresh over eight days without opening the app; if the session ends, use Clerk Pro's custom session lifetime. | Stage 1 ends. |
| OC-9 | How age 13 or over is confirmed: the person's own statement, or a system age signal Apple offers on iOS 26. | Read Apple's current guidance and API for declared age on iOS 26, and choose the least intrusive way that App Review accepts. | Stage 1 ends. |
| OC-10 | How long iOS keeps an App Clip's data when it is not used, and whether pictures waiting in it survive until the guest returns. | Read Apple's current documentation and test on iOS 26 over days; use the result in the mini-app's warnings. | Stage 3. |

## 16. Open questions and readings

### 16.1 Open questions

Version 1.0 listed fourteen open questions.
The captain answered every one but OQ-12 on 2026-11-22; section 16.3 records each answer and where this PRD now states it.
The question below is still open and needs his answer before the stage it names.

| ID | Question | Where it matters | Parked rule or reading, if any | Needed before |
| --- | --- | --- | --- | --- |
| OQ-12 | Who answers the support address, and within what time must a report be answered? | V2-FR-54, M-7 | DEC-13 left support and reports "beyond Host moderation" open. | Stage 2 |

### 16.2 Readings this PRD makes

Version 1.0 stated these as readings of the plan's words, and the captain confirmed on 2026-11-22 that they stand as written; the requirements now state them as decided:

- A deleted Host's event keeps accepting joins and pictures until its End Time, because it "still runs to its reveal" (V2-FR-06).
- Deleting an event before its End Time returns its unclaimed Rolls, as the End Time does (V2-FR-28).
- The album's end warning is shown in the app and on the event's page, not as a push alert or an email, because there is one alert only (V2-FR-48).
- "Pay once per event" means the Host pays for an event's Rolls up front, from the balance, rather than per picture or per guest afterwards; adding Rolls while the event is open is part of the same payment model (V2-FR-60).
- Without the Private Prints, event pictures have no Darkroom in v2 (section 2.2).

Version 1.0's reading that ending early keeps the Reveal Delay did not stand: ending early reveals at once (V2-FR-40).

Version 1.1 makes these readings, each needed to state an answer of 2026-11-22 in full; each can be corrected without changing anything else:

- Before the Start Time the link and the QR code show the event and when it opens, but nobody can join or shoot, the Host included (V2-FR-12).
- The Host can move the Start Time until the event opens (V2-FR-12).
- A guest who left and rejoins comes back to their own Roll and its remaining exposures and takes no new Roll, so rejoining works when every Roll is taken, but not while joining is paused (V2-FR-56).

### 16.3 Answers to version 1.0's open questions

The captain gave these answers on 2026-11-22.

| ID | Question | Answer | Stated in |
| --- | --- | --- | --- |
| OQ-1 | Can the Host shoot in their own event, and does the Host take a Roll from the event like a guest? | Yes: the Host can shoot, taking one Roll from the event like any guest. | V2-FR-25, V2-FR-26, 4.2 |
| OQ-2 | How often are free Rolls given, and the same for a subscriber's larger amount? | Once ever for everyone: the small free amount once per Account, and a subscriber's larger amount also once, not monthly. | V2-FR-62 |
| OQ-3 | Does an event open when the Host loads it, or can the Host set a later start? | The Host can set a later Start Time, so the code can be printed weeks ahead, while shooting still lasts at most 7 days from the start. | V2-FR-12, V2-FR-13, V2-FR-18, 6.1 |
| OQ-4 | When the Host ends early, does the chosen Reveal Delay still apply? | No: the album reveals at once (version 1.0 read the opposite). | V2-FR-40 |
| OQ-5 | Are late pictures accepted until the album ends, or until a cut-off? | Until the album ends, as version 1.0 read. | V2-FR-41 |
| OQ-6 | When the Host removes a guest, do that guest's pictures stay or go? | They go with the guest, reversing the parked rule; so the guest's phone deletes the pictures still waiting on it and the Instant prints it keeps, and uploads none. | V2-FR-53 |
| OQ-7 | Is the Host also emailed before the album ends? | No: notices in the app and on the page only, as version 1.0 read. | V2-FR-48 |
| OQ-8 | Does the web album show Guest Names in each picture's details? | Yes, as version 1.0 read. | V2-FR-47 |
| OQ-9 | Does a guest who left see the album after the reveal, and may they rejoin while the event is open? | Yes to both, reversing the parked rule that leaving ends album access; only guests the Host removed lose access. | V2-FR-43, V2-FR-56 |
| OQ-10 | When a subscription lapses or is refunded, do subscriber free Rolls already credited stay? | Yes, they stay in the balance. | V2-FR-63 |
| OQ-11 | What happens when a guest claims their identity into an Account that already holds a place in the same event? | Both places stay as they were, as version 1.0 read. | V2-FR-04 |
| OQ-13 | Can a subscription's link be moved from one Account to another, and how? | Only through support, as version 1.0 read. | V2-FR-63 |
| OQ-14 | May a refund after the Rolls were used take the balance below zero? | Yes, as V2-FR-65 proposed. | V2-FR-65 |

## 17. Sources

Vendor and Apple pages, read on 2026-11-22:

- Convex pricing: https://www.convex.dev/pricing
- Convex limits: https://docs.convex.dev/production/state/limits
- Convex scheduled functions: https://docs.convex.dev/scheduling/scheduled-functions
- Convex with Clerk: https://docs.convex.dev/auth/clerk
- Convex Swift client: https://docs.convex.dev/client/swift
- Cloudflare R2 pricing: https://developers.cloudflare.com/r2/pricing/
- Cloudflare R2 presigned URLs: https://developers.cloudflare.com/r2/api/s3/presigned-urls/
- Cloudflare R2 limits: https://developers.cloudflare.com/r2/platform/limits/
- Cloudflare Workers pricing: https://developers.cloudflare.com/workers/platform/pricing/
- Clerk pricing: https://clerk.com/pricing
- Clerk iOS quickstart: https://clerk.com/docs/ios/getting-started/quickstart
- Clerk Sign in with Apple for iOS: https://clerk.com/docs/ios/guides/configure/auth-strategies/sign-in-with-apple
- Clerk iOS user reference (delete): https://clerk.com/docs/reference/native-mobile/user.md?sdk=ios
- Clerk webhooks: https://clerk.com/docs/webhooks/overview
- Apple, choosing the right functionality for your App Clip (size limits, unavailable frameworks, background limits, in-app purchases): https://developer.apple.com/documentation/appclip/choosing-the-right-functionality-for-your-app-clip
- Apple, enabling notifications in App Clips: https://developer.apple.com/documentation/appclip/enabling-notifications-in-app-clips
- Apple, creating an App Clip with Xcode (measuring its size): https://developer.apple.com/documentation/appclip/creating-an-app-clip-with-xcode
- Apple, App Store Review Guidelines (1.2, 2.5.16, 3.1.1, 4.8, 5.1.1(v)): https://developer.apple.com/app-store/review/guidelines/
- Apple, App Store Server Notifications types (REFUND, REFUND_REVERSED): https://developer.apple.com/documentation/appstoreservernotifications/notificationtype
- Apple, StoreKit purchase option app account token: https://developer.apple.com/documentation/storekit/product/purchaseoption/appaccounttoken(_:)

Once, read on 2026-11-21: its App Store record (https://apps.apple.com/us/app/once-disposable-camera-event/id6754265953) with its ratings, reviews and version history, the US and Canadian review feeds, its website (https://once.film/, https://once.film/pricing, https://once.film/qr-code-wedding-photos, https://once.film/privacy, https://once.film/terms) and its public demo join page.
