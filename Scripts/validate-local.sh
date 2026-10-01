#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
xcodebuild -version
swift --version
sh Scripts/verify-requirement-map.sh
for package in FilmDomain MediaCatalog RenderFixtures RenderCore FilmPersistence NativeAdapters CapturePipeline EntitlementCore FilmRuntime; do
    swift test --package-path "Packages/$package"
done
swift test --package-path Probes/TrialCommitStudy
swift build --package-path Probes/AssetReviewGenerator
sh Scripts/verify-document-package.sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/ValidationSimulator \
    CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
    -destination 'generic/platform=iOS' -derivedDataPath DerivedData/ValidationDevice \
    CODE_SIGNING_ALLOWED=NO build
if [ -n "${IMMERSE_WORKFLOW_SIMULATOR_UDID:-}" ]; then
    xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj \
        -scheme PopulatedJournalHarness \
        -destination "platform=iOS Simulator,id=$IMMERSE_WORKFLOW_SIMULATOR_UDID" \
        -derivedDataPath DerivedData/PopulatedJournalHarness \
        -resultBundlePath "DerivedData/Populated-$(date -u +%Y%m%dT%H%M%SZ).xcresult" \
        -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
        CODE_SIGNING_ALLOWED=NO test
fi
if [ -n "${IMMERSE_SIMULATOR_UDID:-}" ]; then
    xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
        -destination "platform=iOS Simulator,id=$IMMERSE_SIMULATOR_UDID" \
        -derivedDataPath DerivedData/ValidationSimulator \
        -resultBundlePath "DerivedData/Validation-$(date -u +%Y%m%dT%H%M%SZ).xcresult" \
        -only-testing:ImmerseUITests \
        -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
        CODE_SIGNING_ALLOWED=NO test
fi
if [ -n "${IMMERSE_STOREKIT_SIMULATOR_UDID:-}" ]; then
    xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
        -destination "platform=iOS Simulator,id=$IMMERSE_STOREKIT_SIMULATOR_UDID" \
        -derivedDataPath DerivedData/ValidationSimulator \
        -resultBundlePath "DerivedData/StoreKit-$(date -u +%Y%m%dT%H%M%SZ).xcresult" \
        -only-testing:ImmerseTests \
        -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 \
        CODE_SIGNING_ALLOWED=NO test
fi
