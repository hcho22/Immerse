# Calibration tool runs, 2026-10-12

What the captain's own look files printed when run unchanged, kept as firstmate's messages 009 and 010 asked.
The files themselves are in `Probes/FilmLookCalibration/`, and how the app is held to them is in `../../prd-2-slice-4-looks.md`.
These runs measure his looks; no number from them went into the app, whose values are the constants written in his generators.

## 16mm Cinema, color Film Stock

| File | What it is |
| --- | --- |
| `16mm-self-tests.txt` | Both files' own self-tests: `vision3_250d_lut.py --test` and `effects_16mm_reference.py`. Both passed. |
| `16mm-derive.txt` | `derive_stock.py vision3_250d_lut print ...`: how far his finished "print" look sits from the simulation it was fitted to (color chart dE2000 mean 3.48, worst 8.50 on cyan; skin 2.58 and 2.31), how closely his 33-point tables agree with each other and with a 65-point one, his tone curve, and his look's net hue, color strength and lightness change by color. |
| `16mm-preview.jpg` | `preview_16mm.py`'s contact sheet: a color chart in daylight and in tungsten light with the balance locked at daylight, and three photographs, each as the original, his "print" look and his "scan" variant. Only the "print" look is in the app. |
| `16mm-developed-frame.jpg` | The same script's fully developed frame, with every per-frame pass, beside the original and two enlarged crops. |

`derive_stock.py` and `preview_16mm.py` write under `/tmp/claude-0`; they were run as copies with that path pointed at a scratch folder and nothing else changed.
The two pictures are JPEG copies (quality 90) of the PNG files the script wrote, to keep the repository small.
`preview_16mm.py` printed "ok".

The three photographs are scikit-image's sample pictures: `coffee` (Rachel Michetti, CC0), `chelsea` (Stefan van der Walt, CC0) and `rocket` (SpaceX, released into the public domain).
The color chart is drawn from published reflectance data by colour-science.

## The environment

A scratch virtual environment (Python 3.12) under the task's temporary folder; nothing was installed system-wide and nothing from these packages is in the repository.
`spectral_film_lut` 0.18.12 declares numba 0.67 and numpy 2.4.6 or later, which have no prebuilt build for this Intel Mac, so it was installed with `--no-deps` over numba 0.62.1 and numpy 2.3.5, as firstmate's message 008 allowed.
Run there, the captain's fit tool reproduced the fit his 6×6 spec published (grays 1.45 and 2.23 dE against his 1.40 and 2.14, color chart 2.85 and 6.36 against 2.81 and 6.30, the same constants), so the environment computes what his did.

| Package | Version | License |
| --- | --- | --- |
| spectral_film_lut | 0.18.12 | MIT |
| numba | 0.62.1 | BSD-2-Clause |
| llvmlite | 0.45.1 | BSD-2-Clause |
| numpy | 2.3.5 | BSD-3-Clause |
| colour-science | 0.4.7 | BSD-3-Clause |
| scipy | 1.18.1 | BSD-3-Clause |
| scikit-image | 0.26.0 | BSD-3-Clause |
| pillow | 12.3.0 | MIT-CMU |
| opencv-python | 5.0.0.93 | Apache-2.0 |
| PyQt6 | 6.11.0 | GPL-3.0-only |
| PyQt6-Qt6 | 6.11.2 | LGPL-3.0 |
| PyQt6-sip | 13.13.0 | BSD-2-Clause |
| matplotlib | 3.11.2 | Matplotlib license (PSF-based) |
| networkx | 3.7 | BSD-3-Clause |
| imageio | 2.38.1 | BSD-2-Clause |
| tifffile | 2026.9.20 | BSD-3-Clause |
| lazy-loader | 0.6 | BSD-3-Clause |
| contourpy | 1.4.0 | BSD-3-Clause |
| cycler | 0.12.1 | BSD-3-Clause |
| fonttools | 4.66.1 | MIT |
| kiwisolver | 1.5.1 | BSD-3-Clause |
| packaging | 26.3 | Apache-2.0 or BSD-2-Clause |
| pyparsing | 3.3.3 | MIT |
| python-dateutil | 2.9.0.post0 | Apache-2.0 or BSD-3-Clause |
| six | 1.17.0 | MIT |

PyQt6 is a dependency of `spectral_film_lut`'s own window, which these runs never open (`QT_QPA_PLATFORM=offscreen`); it was installed only so the package imports.

## Whether the project's notices need an entry

The app carries no code and no data file from any of these packages.
What it carries from this work is the captain's finished constants, written in `FilmLook.swift`.
His generator labels three of them, the negative's per-layer contrast, as straight-line slopes of the film maker's published characteristic curves as `spectral_film_lut` digitized them, and the rest as fitted to that package's simulation and then tuned by hand.
The MIT License asks for its notice with copies or substantial portions of the software; a handful of numbers read from, or fitted against, its output is neither, so no notice is required.
The project has no notices file today, and the app has no acknowledgements screen.
Whether to credit the package anyway, as a courtesy, is the captain's call and was put to firstmate.
