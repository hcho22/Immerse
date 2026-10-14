# Bundled Media Catalog

`BundleMediaCatalog` reads a versioned JSON manifest from an app-owned bundle root.
It has no network, media import or capture/entitlement dependency. Resource and
license bytes are hash-checked; traversal, symlink escape, duplicate IDs, wrong
Camera medium, missing approval declarations and insufficient export rights fail
closed. Native decoding remains the consumer's responsibility.

An entry's `rights` declaration is not a legal opinion or evidence that the
captain approved an asset. Production `productionApproved` records must link to
actual retained approval and complete license text. Instrumentals require rights
to bundle audio into exported Movies. `syntheticTestOnly` is rejected by the public
initializer; only package tests can use the internal fixture initializer.

The app's production manifest is intentionally empty and stays empty until the
captain supplies his own sample shots, one for each Camera and Film Stock, and
until a license allows a soundtrack inside exported Movies (DEC-05, the captain,
2026-10-13). A Movie's soundtrack can be changed later, any number of times,
without developing again (DEC-11, the same day), so the manifest no longer
carries a reselection setting; one written with the earlier
`soundtrackReselection` key still loads. Run `swift test --package-path
Packages/MediaCatalog` for catalog integrity/rights-boundary tests. Their synthetic
bytes do not prove photo/audio decoding, emulation quality or production rights.
