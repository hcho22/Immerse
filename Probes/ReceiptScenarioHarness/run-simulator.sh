#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mode=${1:?unit, security or ui}
label=${2:?unique evidence label}
SIM=${SIMULATOR_ID:?explicit authorized simulator UUID required}
case "$label" in *[!a-zA-Z0-9_-]*|'') exit 64 ;; esac
case "$mode" in
  unit) scheme=ReceiptScenarioHarness; selection=ReceiptScenarioTests ;;
  security) scheme=ReceiptNativeSecurity; selection=ReceiptNativeSecurityTests ;;
  ui) scheme=ReceiptScenarioHarness; selection=ReceiptScenarioUITests ;;
  *) exit 64 ;;
esac
OUT="Evidence/ReceiptScenarioHarness/035/$label"
RESULT="DerivedData/Receipt035-$label.xcresult"
test ! -e "$OUT"
test ! -e "$RESULT"
mkdir -p "$OUT"
xcrun simctl list devices --json | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
 const ds=Object.values(JSON.parse(s).devices).flat();const d=ds.find(d=>d.udid===process.argv[1]);
 if(!d||!d.isAvailable||d.state!=="Shutdown")throw Error("Require available, stopped authorized simulator");
 console.log(JSON.stringify(d,null,2));
});' "$SIM" > "$OUT/device-before.json"
xcrun simctl boot "$SIM"
xcrun simctl bootstatus "$SIM" -b > "$OUT/boot.log"
xcrun simctl ui "$SIM" appearance > "$OUT/appearance-before.txt"
xcrun simctl ui "$SIM" content_size > "$OUT/category-before.txt"
cleanup() {
  xcrun simctl ui "$SIM" appearance "$(cat "$OUT/appearance-before.txt")"
  xcrun simctl ui "$SIM" content_size "$(cat "$OUT/category-before.txt")"
  xcrun simctl shutdown "$SIM"
}
trap cleanup EXIT
trap 'exit 130' INT TERM
xcrun simctl ui "$SIM" appearance light
xcrun simctl ui "$SIM" content_size large
find Probes/ReceiptScenarioHarness -type f ! -path '*/xcuserdata/*' -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 > "$OUT/source.sha256"
git rev-parse HEAD > "$OUT/base-revision.txt"
xcodebuild -version > "$OUT/xcode.txt"
status=0
xcodebuild -quiet -project Probes/ReceiptScenarioHarness/ReceiptScenarioHarness.xcodeproj \
  -scheme "$scheme" -destination "platform=iOS Simulator,id=$SIM" \
  -derivedDataPath DerivedData/ReceiptScenario035 -resultBundlePath "$RESULT" \
  "-only-testing:$selection" -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
  CODE_SIGNING_ALLOWED=NO test > "$OUT/execution.log" 2>&1 || status=$?
printf '%s\n' "$status" > "$OUT/exit.txt"
if [ -d "$RESULT" ]; then
  xcrun xcresulttool get test-results summary --path "$RESULT" --format json > "$OUT/summary.json"
fi
container=$(xcrun simctl get_app_container "$SIM" com.immerse.validation.ReceiptScenarioHarness035 data)
if [ -d "$container/Documents/ReceiptScenarios" ]; then
  cp -R "$container/Documents/ReceiptScenarios" "$OUT/scenarios"
fi
find DerivedData/ReceiptScenario035/Build/Products/Debug-iphonesimulator/ReceiptScenarioHarness.app \
  -maxdepth 1 -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 > "$OUT/app-files.sha256"
exit "$status"
