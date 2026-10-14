# Look review boards

This non-shipping probe builds the side-by-side boards on which the captain reviews each Camera's Developed Treatment (tracker QA-16, DEC-04).
It sets no look: every value is in `Packages/RenderCore/Sources/RenderCore/FilmLook.swift`, and the tool only shows what the production renderers develop.
It also builds the comparison board for the Darkroom's chemical toners (DEC-11) and measures the scans of the Instant print study.
Nothing here, and no reference image, ships in the app.
The boards and their outcomes are in `Evidence/AssetReview/looks/`, `Evidence/NativeApp/prd-2-slice-4-looks.md` and `Evidence/NativeApp/instant-study-and-toning-061.md`.

## Render the scenes

```sh
swift run -c release --package-path Probes/LookReviewBoards LookReviewBoards <scenes.json> <new output directory> [--version=<treatment version>] [camera ...]
```

Naming Cameras by identifier (`cinema16mm`, `mediumFormat6x6` and so on) develops only those, for a round that changes one board.
`--version` develops an earlier treatment version a Film can still carry, such as `film-look-3`, in place of today's, to set beside it on a board; the kept Instant board's version 3 renders were made this way.

`scenes.json` lists photo scenes and Movie scenes with paths relative to the file.
Each photo is developed by every Photo Camera and Film Stock with `NativePhotoRenderer.develop`, and by both Movie Cameras as a two-second still clip from which one frame is kept; each Movie scene is developed with `NativeMovieRenderer.developClip`.
A scene may set `"flash": true`, which writes the Exif flash record the Disposable reads, or `"light": "3200,0"`, which writes the clip's recorded white balance for the 16mm color Film Stock's fixed daylight balance.
A scene with `"boards": ["16mm"]` is shown only on those boards.
The output holds the developed pictures, the same scenes with treatment version 2, full-size center crops, extra Instant prints, the clips and a `manifest.json`.
`scenes.json` may also name two further kinds of render:

- `"instantPacks"`: each entry is one Instant Film, with an `id`, a `film` identifier and the ten `scenes` its exposures are of.
  The tool makes that Film, records its ten photographs and asks `DevelopmentRun` for each exposure's assignment, so every print develops with the seed and the treatment version Development would give it.
- `"toning"`: the `scenes` to develop as a black-and-white 6×6 Film and the slider `amounts` to print each with, for each toner, through `NativePhotoRenderer.print`.
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
`--approved` adds each board's approval, in the captain's words, under its title; the words are in `build_boards.py` beside each board.

- `--alternate <renders> [<renders>]` with `--alternate-boards` shows one or two further candidate looks beside the first, rendered from values that are not in the app; `--alternate-film-stocks` limits them to some Film Stocks, and `--alternate-label`, `--alternate-note` and `--alternate-values <file>` take one value per candidate, printed on the board; `--alternate-values FilmLook.<name>` prints a block the app keeps, such as `FilmLook.instantVersion3` for the Instant as treatment version 3.
  Use it for a look outside ADR 0013: such a look enters the app only on the captain's choice, recorded in ADR 0016.
  `--comparison-only 1` marks a further look as shown for comparison and not a choice, such as the look the app carried before; `--looks-heading` words the heading over the looks' notes, and a note may hold several paragraphs separated by blank lines.
- `--remote-references <json>` links pictures the captain supplied that are not openly licensed.
  The board shows them from where they are published; they are never copied into the repository.
- `--packs <label>=<renders> ...` with `--pack-notes` shows the Instant packs of several sets of renders one under another, such as the variation in the app and a proposed one.
  Without it the Instant's board shows the primary renders' own packs.
- `--findings <json>`, `--questions <json>` and `--further-values <json>`, each keyed by board, put what a study found before a board's scenes, replace the single approve-or-change form with the round's own questions, and print candidate values after the values in the app.
- `--no-previous` leaves out the comparison with treatment version 2.

## The toning board

`--only toning` builds `toning/index.html` from the renders' toned prints: each scene untoned and with each toner at each amount.
`--stronger-toning <chemistry>=<top>=<renders>` adds a row past the top of the range, from renders made with the amount `ToningLook.apply` passes for that toner multiplied by `<top>` in the working tree; an amount there is `amount * top` in strength.
`--toning-approved <text>` with `--approved` prints what the captain approved.

## The Instant print study

```sh
python3 Probes/LookReviewBoards/instant_print_study.py --sources <sources> --scenes <scenes.json> \
  --output Evidence/AssetReview/looks/instant-study [--renders "<label>=<renders>" ...]
```

It measures every entry of `<sources>/manifest.json` that carries a `study` record, after checking its file against the recorded SHA-256, and the Instant prints of each named set of renders the same way.
It writes `measurements.json` and `measurements.md`, and needs numpy and Pillow.
What is measured and what it can and cannot show is in `Evidence/NativeApp/instant-study-and-toning-061.md`.
