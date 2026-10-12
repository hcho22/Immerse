# Look review boards

This non-shipping probe builds the side-by-side boards on which the captain reviews each Camera's Developed Treatment (tracker QA-16, DEC-04).
It sets no look: every value is in `Packages/RenderCore/Sources/RenderCore/FilmLook.swift`, and the tool only shows what the production renderers develop.
Nothing here, and no reference image, ships in the app.
The boards and their outcomes are in `Evidence/AssetReview/looks/` and `Evidence/NativeApp/prd-2-slice-4-looks.md`.

## Render the scenes

```sh
swift run -c release --package-path Probes/LookReviewBoards LookReviewBoards <scenes.json> <new output directory>
```

`scenes.json` lists photo scenes and Movie scenes with paths relative to the file.
Each photo is developed by every Photo Camera and Film Stock with `NativePhotoRenderer.develop`, and by both Movie Cameras as a two-second still clip from which one frame is kept; each Movie scene is developed with `NativeMovieRenderer.developClip`.
A scene may set `"flash": true`, which writes the Exif flash record the Disposable reads, or `"light": "3200,0"`, which writes the clip's recorded white balance for the 16mm color Film Stock's fixed daylight balance.
The output holds the developed pictures, the same scenes with treatment version 2, full-size center crops, extra Instant prints, the clips and a `manifest.json`.
Movie scenes must be SDR; an HLG capture from a phone has to be tone-mapped first or it develops blown out.

## Build the boards

```sh
python3 Probes/LookReviewBoards/build_boards.py --renders <renders> --sources <sources> --scenes <scenes.json> \
  --output Evidence/AssetReview/looks --date <YYYY-MM-DD> --round <NN> [--only 6x6 16mm]
```

`<sources>` is a directory with `manifest.json` and `SOURCES.md`: every test scene and reference image with its source page, author and license.
Use only public-domain or openly licensed images there, and record each one's source and license.
Each board is a self-contained directory, `index.html` with the pictures and clips it shows beside it, served for review with `lavish-axi <board>/index.html`.
The output directory also gets `SOURCES.md`, `sources.json` (the manifest, with each file's download URL) and `scenes.json`, so the same files can be fetched and rendered again.
`--slim` writes smaller pictures and clips and leaves out the comparison with treatment version 2; it is the copy kept in the repository once a board is approved.

- `--alternate <renders>` with `--alternate-boards` shows a second candidate look beside the first, rendered from values that are not in the app; `--alternate-film-stocks` limits it to some Film Stocks, and `--alternate-values <file>` prints its values on the board.
  Use it for a look outside ADR 0013: such a look enters the app only on the captain's choice, recorded in ADR 0016.
- `--remote-references <json>` links pictures the captain supplied that are not openly licensed.
  The board shows them from where they are published; they are never copied into the repository.

## Lightroom values

```sh
python3 Probes/LookReviewBoards/lightroom_curve.py --highlights -30 --shadows 40 --whites 15 --blacks -5 --dehaze -5 --black-node 4
```

The captain wrote some look notes as Lightroom slider values.
This prints the `points`, `black` and `white` of a `FilmLook.ToneCurve` for them.
Adobe does not publish the sliders' math, so it is a stated approximation of their effect, described at the top of the script, not Lightroom itself.
