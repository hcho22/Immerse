# Render Fixture Evidence

Generated on 2026-09-30 local time with:

```sh
swift run --package-path Packages/RenderFixtures RenderFixtureTool Evidence/RenderFixtures
```

These files are synthetic native API fixtures for DEC-04 renderer discovery only.
They are not production Camera treatment, not production assets, not a product toggle and not an approval of final export settings.

- `synthetic-developed-photo.jpg`: ImageIO-written JPEG, decoded in `manifest.json`.
- `synthetic-developed-movie.mov`: AVFoundation-written H.264 `.mov`, decoded in `manifest.json`.
- `manifest.json`: exact settings and decoded dimensions, codec, nominal cadence, duration and orientation transform.

The package tests prove these are decoded real media files generated through native APIs, unlike the earlier domain/planning tests that use fakes or byte payloads.
