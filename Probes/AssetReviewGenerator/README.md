# Draft Asset Review Generator

Non-shipping preparation for the existing DEC-04/05/11 review. It does not import
anything into a Film, mutate Keychain, configure the production catalog or approve
render specifications/rights. The source is a recorded built-in generated image;
the soundtrack is an original coded score, not a purchased or sampled recording.

From the repo root, choose a **new** output directory (the tool refuses overwrite):

```sh
swift run --package-path Probes/AssetReviewGenerator AssetReviewGenerator Evidence/AssetReview/sources/window-still-life-generated.png DerivedData/AssetReview-repeat
```

Three photos, two digitally panned source clips, two Developed Clips per Movie
Camera, silent/instrumental assemblies and a WAV are rendered by native APIs.
Every main output is decoded and hashed; `manifest.json` records dimensions,
duration, cadence, codec, audio-track count and fixed seeds. Source Movie motion
is synthetic and is never described as real phone footage or performance evidence.
No shipping code depends on this tool, and CI need not synthesize large review media.

`Evidence/AssetReview/review.html` is the local review surface, with source and
result links. `sources/PROVENANCE.md` preserves the generation prompt, source and
rights status. Final production clearance and human audio/visual judgment remain
with the already registered asset review. The production manifest stays empty.
