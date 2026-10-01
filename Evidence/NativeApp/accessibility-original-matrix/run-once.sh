#!/bin/sh
set -eu
cd "$(dirname "$0")/../../.."
SIM=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60
OUT=Evidence/NativeApp/accessibility-original-matrix
test ! -e DerivedData/Immerse-OriginalMatrix-Light.xcresult
test ! -e DerivedData/Immerse-OriginalMatrix-Dark.xcresult
xcrun simctl boot "$SIM"
xcrun simctl bootstatus "$SIM" -b
xcrun simctl ui "$SIM" appearance > "$OUT/appearance-before.txt"
xcrun simctl ui "$SIM" content_size > "$OUT/category-before.txt"
cleanup() {
    xcrun simctl ui "$SIM" appearance "$(cat "$OUT/appearance-before.txt")"
    xcrun simctl ui "$SIM" content_size "$(cat "$OUT/category-before.txt")"
    xcrun simctl shutdown "$SIM"
}
trap cleanup EXIT
trap 'exit 130' INT TERM
xcrun simctl ui "$SIM" content_size large
result=0
for appearance in Light Dark; do
    mode=$(printf '%s' "$appearance" | tr '[:upper:]' '[:lower:]')
    xcrun simctl ui "$SIM" appearance "$mode"
    xcrun simctl ui "$SIM" appearance > "$OUT/$mode-appearance.txt"
    xcrun simctl ui "$SIM" content_size > "$OUT/$mode-category.txt"
    status=0
    xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
        -destination "platform=iOS Simulator,id=$SIM" \
        -derivedDataPath DerivedData/ValidationSimulator \
        -resultBundlePath "DerivedData/Immerse-OriginalMatrix-$appearance.xcresult" \
        -only-testing:ImmerseUITests/JournalFlowTests/testCatalogBrowsingDoesNotLoadFilmAndSettingsDiscloseRestore \
        -only-testing:ImmerseUITests/JournalFlowTests/testLargestDynamicTypeCatalogAndLandscapeSettings \
        -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
        CODE_SIGNING_ALLOWED=NO test > "$OUT/$mode-execution.log" 2>&1 || status=$?
    printf '%s\n' "$status" > "$OUT/$mode-exit.txt"
    xcrun xcresulttool get test-results summary \
        --path "DerivedData/Immerse-OriginalMatrix-$appearance.xcresult" \
        --format json > "$OUT/$mode-summary.json"
    node -e 'const s=require("./"+process.argv[1]); if(s.totalTestCount!==2 || s.skippedTests!==0) throw Error("Expected two executed original cases; stop batch");' "$OUT/$mode-summary.json"
    if [ "$status" -ne 0 ]; then result=1; fi
done
exit "$result"
