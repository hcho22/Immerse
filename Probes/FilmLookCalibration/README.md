# Film look calibration

This non-shipping probe holds the captain's own look files for the color negative Film Stocks, exactly as he sent them, and the scripts that turn them into the fixtures the app's tests are held to.
The files are the source of truth for those looks: the app's values in `Packages/RenderCore/Sources/RenderCore/FilmLook.swift` are copied from them, never the other way round, and never refitted.
Nothing here is built into the app, and the Format Reference names in these files (manufacturers and films) are internal and never appear in the product (ADR 0015).

## 16mm Cinema, color Film Stock (`16mm/`)

The captain sent these on 2026-10-12 with "please apply the attached for immerse - 16mm camera kodak vision3 250d".
They are byte-for-byte copies; check them with `shasum -a 256 16mm/*`.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `vision3_250d_lut.py` | The look generator: one film model with written constants for a default "print" look and a "scan" variant, the neutral values the app must reproduce (`SANITY`) and its own self-test. The app develops with the "print" look. | `68095625df60485d19a8ffb48ebc58a21d7a635aeda99bc852a8463b3fe24c7a` |
| `effects_16mm_reference.py` | The reference for the per-frame passes (halation, soft darkened edges, softness, grain, weave) and their order, with its own self-test. | `e03d61f3f823e0ca526ecd7bf9a9c9402e7c37e056d1416e0ef882fd6540541c` |
| `ref_stock.py` | Reference renders from a spectral film simulation for a negative and print pair. | `1f399600a7e44e858f49dee78ff8b874a7008167ad1f19a3ec4525fcb05a0bf8` |
| `fit_stock.py` | The two-stage fit of a generator's constants to that simulation. Not needed for the look: his constants were fitted and then timed by hand, and a raw fit never replaces them. | `7cc4cce79d104ad7007d23a6ec776fcbeb6b65621bc4d079c3b6f71bf2e68032` |
| `derive_stock.py` | Measures a finished look against the simulation. | `71527acbd95ce884faac8261548497cb3eac55e4acda54b082af995a2e4b17e4` |
| `preview_16mm.py` | A contact sheet and one fully developed frame. | `dcc33317b2d3a5db87670899a90db361c21b685c1b419d90b9e33ab552b6f9d0` |
| `README.md` | His note on the tools. | `e783993226abb89561bd6bb633438616419b17e650707a2eceb3dedb34d053dc` |

`make_fixtures.py` is ours.
It imports his two reference files, unchanged, and writes the colors, neutral values, test frames and grain and weave statistics that `NegativeFilmTests` and `ScenePassesTests` compare the app's own pipeline with:

```sh
python3 Probes/FilmLookCalibration/16mm/make_fixtures.py Packages/RenderCore/Tests/RenderCoreTests/Fixtures/Cinema16mmColor
```

It needs numpy, scipy and pillow.
Every number and picture it writes comes from his functions; the script only chooses the colors and the test frame they are asked about.

## 6×6 Medium Format, color Film Stock (`6x6/`)

The captain sent these on 2026-10-12 with "please apply attached files to immerse 6x6 portra 400 film".
They are byte-for-byte copies; check them with `shasum -a 256 6x6/*`.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `2026-10-12-6x6-color-film-stock-look-spec.md` | His spec for the look: the film, the way a photograph goes in (section 2), the constants (section 3), the passes (section 5) and what he leaves open. | `d5044dac6e1b022a7d9a5f7c0710f24aa3179b5e8d2fa81291997a11a54cddf7` |
| `portra400_lut.py` | The look generator: the same film model as the 16mm's, with written constants for a default "scan" look and a "print" look it keeps for reference, the neutral values the app must reproduce (`SANITY`) and its own self-test. The app develops with the "scan" look. | `5d5d6f08db80d3950ecab49e9224e511348c9a570d543abba8ec4d9a88be5071` |
| `immerse_6x6_color_scan_applelog_33.cube` | The table the generator writes for the app: the "scan" look at 33 Apple Log tones a side on Rec.2020 primaries. The app makes the same table from his constants and reads it as his spec does. | `c6cdb3e85f3562982b2fcb4069a4bceb59efa62786cb05f8860f5acd046cff3f` |
| `immerse_6x6_color_scan_srgb_33.cube` | The table for previewing an ordinary photograph on a desktop. Not used by the app. | `051ebc8d4140757b2655e00d31cff39dddf675b735d76d0a1a26574911322913` |
| `ref_eval.py` | Reference values from the spectral film simulation. | `f6797802f6fd201193b0166bc7ad1fcfbcbaadd483ce383ea308aa4f4a4364df` |
| `fit.py` | The two-stage fit. Not needed for the look, and never a replacement for his finished constants. | `f56c1e89eecb6f46d23d4c9c52fb8c227fe407cc76e05a1c1402d55a048c7909` |
| `derive.py` | Measures the finished look against the simulation and as a tone curve and a table of color changes. | `105b4754d742d1b9f2fa747fb5147578a3441dd083074e8298605391f94b2df9` |
| `preview.py` | A before-and-after contact sheet through the table. | `e787959c7ac993a7d52ce25bef0f95065ac631f5b605ebb19d33eda67ed08719` |
| `README.md` | His note on the tools. | `02ee40b02129269cdfd4f4cb550e9889098b3d2fac7df9482e50dffe0fee990b` |

`make_fixtures.py` is ours.
It imports his generator unchanged, checks that the generator still writes his table byte for byte, and writes the colors, neutral values, table readings, test frames and grain statistics that `NegativeFilmTests` and `MediumFormatPassesTests` compare the app's own pipeline with:

```sh
python3 Probes/FilmLookCalibration/6x6/make_fixtures.py Packages/RenderCore/Tests/RenderCoreTests/Fixtures/MediumFormatColor
```

It needs numpy, scipy, pillow and colour-science, whose tetrahedral table reading is the one his `preview.py` uses.
The 6×6 has no reference file for its passes, so the script writes them out from section 5 of his spec, with his 16mm reference's own functions where the spec says the shader is the same.

## Where the constants come from

His generator labels every constant: published (the film maker, Apple, the ITU); the film maker's characteristic curves as digitized in `spectral_film_lut`; fitted to that package's simulation of the negative printed on print film; or tuned by hand on top of the fit.
`spectral_film_lut` is MIT licensed.
None of its code or data is in this repository or in the app.
What the app carries is the captain's finished numbers: about seventy constants, three of which (the negative's per-layer contrast) are straight-line slopes read from the film maker's published curves as that package digitized them, the rest being values fitted to its output and then changed by hand.

## Running his tools

His self-tests need only numpy and scipy:

```sh
python3 Probes/FilmLookCalibration/16mm/vision3_250d_lut.py --test
python3 Probes/FilmLookCalibration/16mm/effects_16mm_reference.py
python3 Probes/FilmLookCalibration/6x6/portra400_lut.py --test
```

`ref_stock.py`, `fit_stock.py`, `derive_stock.py` and `preview_16mm.py`, and the 6×6's `ref_eval.py`, `fit.py`, `derive.py` and `preview.py`, need the simulation package.
Install it in a scratch virtual environment, never system-wide, and copy nothing from it into the repository.
The published `spectral_film_lut` 0.18.12 declares numba 0.67 and numpy 2.4.6 or later, which have no prebuilt build for an Intel Mac, so on 2026-10-12 it ran with `pip install --no-deps spectral_film_lut==0.18.12` over numba 0.62.1 and numpy 2.3.5.
That environment reproduced the fit the captain published for the 6×6 stock (grays within 0.1 dE of his, the same constants), so it computes what his did.
`derive_stock.py`, `preview_16mm.py`, `derive.py` and `preview.py` write under `/tmp/claude-0`; run copies with that path pointed at a scratch folder and nothing else changed.

The outputs kept from 2026-10-12, with every package's version and license, are in `Evidence/NativeApp/prd-2-slice-4-looks/calibration/`.
