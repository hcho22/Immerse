# Film look calibration

This non-shipping probe holds the captain's own look files for the color negative Film Stocks, exactly as he sent them, and the script that turns them into the fixtures the app's tests are held to.
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
```

`ref_stock.py`, `fit_stock.py`, `derive_stock.py` and `preview_16mm.py` need the simulation package.
Install it in a scratch virtual environment, never system-wide, and copy nothing from it into the repository.
The published `spectral_film_lut` 0.18.12 declares numba 0.67 and numpy 2.4.6 or later, which have no prebuilt build for an Intel Mac, so on 2026-10-12 it ran with `pip install --no-deps spectral_film_lut==0.18.12` over numba 0.62.1 and numpy 2.3.5.
That environment reproduced the fit the captain published for the 6×6 stock (grays within 0.1 dE of his, the same constants), so it computes what his did.
`derive_stock.py` and `preview_16mm.py` write under `/tmp/claude-0`; run copies with that path pointed at a scratch folder and nothing else changed.

The outputs kept from 2026-10-12, with every package's version and license, are in `Evidence/NativeApp/prd-2-slice-4-looks/calibration/`.
