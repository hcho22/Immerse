# Film UI study — throwaway prototype

> **v1 scope note (2026-09-30, PRD version 1.1).**
> By captain decision, v1 ships personal Photo and Movie Films only, and all Group functionality is deferred to v2.
> This prototype still simulates Group flows (Join with a code, Guest participation, shared loads, closure, Host Private Review and Release, Private Prints on Group photos, Group notifications), and the notes below keep describing them because v2 needs them.
> Read those Group flows as v2 design study, not v1 scope.
> The personal Film flows, Camera samples, Darkroom on personal photos, Development, and the selected Film Journal direction describe v1.
>
> **Version 1.2 note (2026-09-30).**
> v1 also has no Account, sign-in, server or analytics, and runs on iOS 26, iPhone only.
> Any sign-in or Account behavior this prototype simulates is v2 design study; the v1 Trial is one Film per iPhone held in the Keychain (ADR 0012).
>
> **Version 1.4 note (2026-09-30, PRD version 1.4): the v1 clickable prototype.**
> A second, separate prototype now exists; everything else in this file describes the earlier three-direction study.
> The v1 clickable prototype is a browser prototype of an iOS 26 style iPhone app in light and dark, with no sign-in or administrator mode.
> It covers onboarding, the Film Journal, choosing and previewing a Camera, Load Film, capture, Movie recording, completion and early Development, Development, reveal, the Darkroom, Save to Photos, settings, and error and empty states.
> The captain approved its iOS design on 2026-09-30.
> It is kept outside this repository as a design reference only: it is not a requirement, a decision or evidence of native behavior, and its code and review controls must not be promoted into the product.
> The questions it raised that are still pending are listed in [PRD section 18](../2026-10-06-film-camera-experience-v1-prd-version-2.0.md#18-current-evidence-and-definition-of-done).
>
> **Version 2.0 note (2026-10-06, PRD version 2.0).**
> Both prototypes were built before PRD version 2.0.
> Neither has a Film Stock choice at Load Film for the 6×6 Medium Format or the 16mm Cinema, the Instant print's white card, the reversed 6×6 viewfinder, the Disposable's low-light cue, or the renamed Cameras, so their screens are not a design for those parts.
> The Film Stock control is therefore a flow choice that the approved prototype does not settle.

Question: which of three structurally different iPhone-style layouts makes loading, intentional capture, delayed reveal, and shared Host Release feel clearest?

Run from the workspace with one command:

```sh
/Users/hcho/.nvm/versions/node/v20.19.5/bin/lavish-axi .lavish/film-prototype.html
```

Alternatively, open `film-prototype.html` directly in a browser. `?variant=A`, `B`, or `C` selects a layout. The floating arrows and keyboard arrow keys switch layouts without resetting the in-memory Film state. Inputs retain their normal arrow-key behavior.

- A — Film Journal: memory-first editorial library, roll receipts, developed contact sheets.
- B — Camera Case: equipment shelf, physical Camera tiles, dark tactile capture controls.
- C — Roll Ledger: chronological typography-led rows and a separate loading dock.

The project contained domain documentation but no source app, design system, theme, or assets. The study uses the suggested Tailwind browser runtime and DaisyUI foundation, then film-inspired local tokens. External Unsplash photographs are illustrative samples, not validated emulations or actual user captures; local SVG fallback illustrations keep the flows usable if these photographs cannot load. CDN styles and remote photographs need internet; the prototype's own styles, behavior, and fallback scene are local.

## What to try

Start a personal Film, inspect Camera samples, choose a title, and explicitly Load Film. Shoot a frame, switch lenses between captures, or use the clearly separate review console to simulate consuming the remaining capacity. Roll captures stay sealed; early Development requires an unused-capacity warning. Instant prints develop individually. Movie time advances at 10× while recording and consumes no paused time. Movie playback is an illustrated sequence, not generated video or live audio.

(Group flow, deferred to v2.) Join as Jamie with `CAMP27`, confirm the Camera and sharing rules, and capture account-free. Switch to Maya to opt into adding one full subscriber Camera load to the shared pool; joining or subscription alone never contributes it. Switch to You to close the Group Film, explicitly Develop it, privately review, and Release it. Switch back to Jamie to check that neither exhaustion, closure, nor Host Private Review reveals the Film. Released Group viewing is unavailable in simulated offline mode.

Interrupt Development and resume the same saved result. Open a revealed personal photo in the Darkroom, adjust print exposure, contrast, filtration, crop, and local Dodge/Burn, and reset to the developed master. Own Group photos offer Private Prints after Release; the shared original remains unchanged. Export and notifications are simulated and never save files, create push messages, or change a real Photos library.

## Scope and unresolved matters

This is not a native iOS app and does not validate AVFoundation capture, film rendering quality, the absence of microphone permission prompts, export fidelity, Photos permissions, StoreKit, Apple/Google sign-in, cloud concurrency, or push delivery. The review console can change roles and skip captures solely for inspection. It is not a product feature or a production security boundary. Whole identity deletion, bulk withdrawal, member removal, upload failures, long-term Group retention, storage economics, final pricing, and launch compliance are outside this UI study. Existing domain rules remain in `../CONTEXT.md`.

No persistent storage is used. Reloading or Reset clears every demo mutation. Prototype code is intentionally disposable; do not promote it directly to production.

## Verification

Browser interaction checks covered Guest consent before enrollment, account-free pooled capture, one explicit subscriber load, exact unused-capacity warnings, separate closure/Development/Release, same-treatment recovery, Host-only Private Review, contributor-only reversible printing, offline Group-view blocking, text-only notifications, the final Instant print, and paused movie timing. All three desktop layouts and a 390px narrow viewport were rendered and inspected; no script errors or horizontal overflow were observed. Screenshots are in `../outputs/`. Native capture, security, concurrent cloud operations, and rendering/export fidelity still require real-app verification.

## Selected direction

On 2026-09-29, the user selected **A — Film Journal** as the basis for the app: a memory-first library using loaded-roll cards and developed contact sheets, with Start a Film prominent. B and C are comparison alternatives only, not alternate production modes.

This answers the layout-direction question, not final sign-off on every capture or sharing interaction. Keep A as the design reference during interaction review; when the native implementation absorbs the validated design, remove the throwaway comparison variants and switcher rather than shipping this prototype code.
