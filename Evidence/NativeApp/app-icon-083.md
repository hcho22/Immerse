# The App Icon: Tilted Spread (083)

On 2026-11-20 the captain asked for app icon layouts representing "film journal"; on 2026-11-21 he narrowed the first round to Spine, Curl and Open Spread and asked for layouts with minimal negative space.
From the second round he chose one: "lets go with tilted spread. i like this color vs orbits cream".
Asked whether it replaces the icon planned in his naming plan of 2026-10-28 (a film coil with no lettering) and whether to add it now or with the new public name, he answered "yes replace it, add it now".

Tilted Spread is the second round's layout "Open Spread D": an open journal seen from above whose two pages are two frames on one film strip, tilted 10 degrees and scaled past every edge like a journal lying open on a desk, with the sprocket holes the rounded corners would cut left out.
"This color" is that round's paper palette (film #1B1A18, paper #F1EADB, gutter and lines #B9AE98), not the Orbit palette (cream #E6D3B3 on black).
The icon has no lettering.

Until this change the app had no icon: the target set `ASSETCATALOG_COMPILER_APPICON_NAME` to an empty string, because the icon was not approved (DEC-01; [2026-10-01-native-candidate.md](2026-10-01-native-candidate.md), run 2), and the home screen showed the system's blank icon.

## What changed

- `App/Immerse/Sources/Assets.xcassets/AppIcon.appiconset`: one 1024 × 1024 icon in three appearances, the single-size form Xcode 26 builds every iPhone size from.
  - `AppIcon.png`, the default: the master as drawn, opaque, with no alpha channel and no rounded mask.
  - `AppIcon-Dark.png`, the dark appearance: the same drawing with the film left transparent, so iOS draws its own dark background behind the pages, as Apple's guidelines for dark icons describe, and the paper and its lines a step darker (#E2D9C6 and #A39883) so the pages do not glare on a dark home screen.
  - `AppIcon-Tinted.png`, the tinted appearance: the drawing in grayscale on black, the pages white and the lines a mid gray (#A0A0A0), which iOS tints in the person's chosen color.
- `App/Immerse/project.yml` and the generated `Immerse.xcodeproj`: the Immerse target's `ASSETCATALOG_COMPILER_APPICON_NAME` is `AppIcon`, in Debug and Release.
  The build's Info.plist then names it (`CFBundleIcons` → `CFBundlePrimaryIcon` → `CFBundleIconName` = `AppIcon`); nothing else in the target changed.
  The two non-shipping probes that compile the app's asset catalog, `Probes/PopulatedJournalHarness` and `Probes/SetupAccessibilityProbe`, keep their empty icon setting.

## The source and how to make the icon again

This folder, [app-icon-083](app-icon-083/), holds:

- `tilted-spread.svg`: the 1024 master in the paper palette, exactly as the second round's Claude Design canvas holds it (SHA-256 `67f1ea4ff66cf8996d48281b94ba4778910b45ad9ad3005b288a086f7300f78b`); it is used as drawn.
- `tilted-spread-dark.svg` and `tilted-spread-tinted.svg`: the two appearances derived from it, written by the script.
- `make-app-icon.sh`: derives the two appearances by changing only colors (and, for the dark one, removing the two film rectangles), renders all three at 1024 with `rsvg-convert`, and writes them into the icon set; `flatten.swift` writes the default and tinted icons without an alpha channel.

```sh
sh Evidence/NativeApp/app-icon-083/make-app-icon.sh
```

It needs `rsvg-convert` (Homebrew's `librsvg`) and Xcode; it prints each icon's size and whether it has alpha (default and tinted: no; dark: yes).

## What the simulator showed

Built for an iPhone 17 Pro simulator on iOS 26.5 (`xcodebuild ... build`): the asset catalog compiled with no warnings, and the app bundle carries `AppIcon60x60@2x.png` and the Info.plist entry above.
Installed, the home screen showed the icon in each of its three styles, chosen in the home screen's own Edit → Customize panel (Default with the light appearance, Dark, Tinted):

| Style | Home screen | The icon at full resolution |
| --- | --- | --- |
| Default (light) | [home-screen-light.png](app-icon-083/home-screen-light.png) | [home-screen-light-icon.png](app-icon-083/home-screen-light-icon.png) |
| Dark | [home-screen-dark.png](app-icon-083/home-screen-dark.png) | [home-screen-dark-icon.png](app-icon-083/home-screen-dark-icon.png) |
| Tinted | [home-screen-tinted.png](app-icon-083/home-screen-tinted.png) | [home-screen-tinted-icon.png](app-icon-083/home-screen-tinted-icon.png) |

In every style the journal, its gutter, the lines on the left page and both sprocket rows read at home-screen size; iOS 26 adds its own edge highlight to the icon.
The blank "Driver-Runner" icon beside it is the throwaway UI-test runner that chose each style; it is not part of the app.

## What only a phone shows

How the three appearances look on a real iPhone's display, and in the Clear style, which this icon set does not draw for (iOS makes it from the default), is [A01](manual-validation.md#a01---the-app-icon-in-every-home-screen-style) in the manual plan.
Whether the dark and tinted adaptations look right is the captain's to judge.

## Recovery

Reverting this change restores the empty icon setting and removes the icon set; no data, code path or entitlement depends on it.
