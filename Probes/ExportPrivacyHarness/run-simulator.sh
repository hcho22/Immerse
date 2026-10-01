#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mode=${1:?unit, ui, development or fifo}
label=${2:?unique evidence label}
SIM=${SIMULATOR_ID:?explicit authorized simulator UUID required}
case "$label" in *[!a-zA-Z0-9_-]*|'') exit 64 ;; esac
case "$mode" in
  unit) selection=ExportPrivacyTests ;;
  ui) selection=ExportPrivacyUITests ;;
  development) selection=DevelopmentObserverTests ;;
  fifo) selection=ReceiptFIFOTests/ProductionTrialReceiptTests/testQueuedDeletionQuiescesReceiptProjectionAndStaleCallbacksCannotRecreateFilm ;;
  *) exit 64 ;;
esac
OUT="Evidence/ExportPrivacyHarness/036/$label"
if [ "$mode" = development ]; then OUT="Evidence/DevelopmentObserver/036/$label"; fi
if [ "$mode" = fifo ]; then OUT="Evidence/ReceiptFIFO/036/$label"; fi
RESULT="DerivedData/Export036-$label.xcresult"
test ! -e "$OUT"
test ! -e "$RESULT"
mkdir -p "$OUT"
xcrun simctl list devices --json | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
 const d=Object.values(JSON.parse(s).devices).flat().find(d=>d.udid===process.argv[1]);
 if(!d||!d.isAvailable||d.state!=="Shutdown")throw Error("Require available stopped authorized simulator");
 console.log(JSON.stringify(d,null,2));
});' "$SIM" > "$OUT/device-before.json"
cleanup() {
  if [ -s "$OUT/appearance-before.txt" ]; then xcrun simctl ui "$SIM" appearance "$(cat "$OUT/appearance-before.txt")"; fi
  if [ -s "$OUT/category-before.txt" ]; then xcrun simctl ui "$SIM" content_size "$(cat "$OUT/category-before.txt")"; fi
  xcrun simctl shutdown "$SIM"
}
xcrun simctl boot "$SIM"
trap cleanup EXIT
trap 'exit 130' INT TERM
xcrun simctl bootstatus "$SIM" -b > "$OUT/boot.log"
xcrun simctl ui "$SIM" appearance > "$OUT/appearance-before.txt"
xcrun simctl ui "$SIM" content_size > "$OUT/category-before.txt"
xcrun simctl ui "$SIM" appearance light
xcrun simctl ui "$SIM" content_size large
find Probes/ExportPrivacyHarness -type f ! -path '*/xcuserdata/*' -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 > "$OUT/source.sha256"
shasum -a 256 Probes/ReceiptScenarioHarness/Sources/ScenarioEvidence.swift >> "$OUT/source.sha256"
find Packages/FilmRuntime/Sources -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 >> "$OUT/source.sha256"
shasum -a 256 Packages/FilmRuntime/Tests/FilmRuntimeTests/DevelopmentObserverTests.swift >> "$OUT/source.sha256"
shasum -a 256 Packages/FilmRuntime/Tests/FilmRuntimeTests/ProductionTrialReceiptTests.swift >> "$OUT/source.sha256"
git rev-parse HEAD > "$OUT/base-revision.txt"
xcodebuild -version > "$OUT/xcode.txt"
printf 'mode=%s\nselection=%s\nresult=%s\n' "$mode" "$selection" "$RESULT" > "$OUT/selection.txt"
status=0
xcodebuild -quiet -project Probes/ExportPrivacyHarness/ExportPrivacyHarness.xcodeproj \
  -scheme ExportPrivacyHarness -destination "platform=iOS Simulator,id=$SIM" \
  -derivedDataPath DerivedData/ExportPrivacy036 -resultBundlePath "$RESULT" \
  "-only-testing:$selection" -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
  CODE_SIGNING_ALLOWED=NO test > "$OUT/execution.log" 2>&1 || status=$?
printf '%s\n' "$status" > "$OUT/exit.txt"
if [ -d "$RESULT" ]; then
  xcrun xcresulttool get test-results summary --path "$RESULT" --format json > "$OUT/summary.json"
  xcrun xcresulttool get test-results tests --path "$RESULT" --format json > "$OUT/tests.json"
fi
container=$(xcrun simctl get_app_container "$SIM" com.immerse.validation.ExportPrivacyHarness036 data)
if [ -d "$container/Documents/ExportScenarios" ]; then
  cp -R "$container/Documents/ExportScenarios" "$OUT/scenarios"
fi
if [ -d "$container/Documents/DevelopmentScenarios" ]; then
  cp -R "$container/Documents/DevelopmentScenarios" "$OUT/development-scenarios"
fi
if [ -d "$container/Documents/ReceiptFIFO" ]; then
  cp -R "$container/Documents/ReceiptFIFO" "$OUT/receipt-fifo"
fi
find DerivedData/ExportPrivacy036/Build/Products/Debug-iphonesimulator/ExportPrivacyHarness.app \
  -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 > "$OUT/app-files.sha256"
exit "$status"
