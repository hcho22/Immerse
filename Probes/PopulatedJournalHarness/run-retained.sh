#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
label=${1:?unique evidence label required}
mode=${2:-retained}
case "$mode" in
  retained) selection=PopulatedJournalHarnessTests/RetainedWorkflowTests ;;
  legacy) selection=PopulatedJournalHarnessTests/PopulatedWorkflowTests ;;
  *) exit 64 ;;
esac
SIM=${SIMULATOR_ID:?explicit authorized simulator UUID required}
case "$label" in *[!a-zA-Z0-9_-]*|'') exit 64 ;; esac
OUT="Evidence/PopulatedJournal/037/$label"
RESULT="DerivedData/Populated037-$label.xcresult"
test ! -e "$OUT"
test ! -e "$RESULT"
mkdir -p "$OUT"
xcrun simctl list devices --json | ruby -rjson -e '
 d=JSON.parse(STDIN.read).fetch("devices").values.flatten.find{|v|v["udid"]==ARGV[0]}
 abort "Require available stopped authorized simulator" unless d && d["isAvailable"] && d["state"]=="Shutdown"
 puts JSON.pretty_generate(d)
' "$SIM" > "$OUT/device-before.json"
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
container=$(xcrun simctl get_app_container "$SIM" com.immerse.PopulatedJournalHarness data 2> "$OUT/container-before-error.txt") || container=""
ruby -rjson -e 'puts JSON.generate(Dir.glob(File.join(ARGV[0],"Documents/WorkflowHistories/*")).map{|p|File.basename(p)})' "$container" > "$OUT/histories-before.json"
find Probes/PopulatedJournalHarness App/Immerse/Sources -type f ! -path '*/xcuserdata/*' -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 > "$OUT/source.sha256"
git rev-parse HEAD > "$OUT/base-revision.txt"
xcodebuild -version > "$OUT/xcode.txt"
printf 'mode=%s\nselection=%s\n' "$mode" "$selection" > "$OUT/selection.txt"
status=0
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj \
  -scheme PopulatedJournalHarness -destination "platform=iOS Simulator,id=$SIM" \
  -derivedDataPath DerivedData/PopulatedJournal037 -resultBundlePath "$RESULT" \
  "-only-testing:$selection" -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
  CODE_SIGNING_ALLOWED=NO test > "$OUT/execution.log" 2>&1 || status=$?
printf '%s\n' "$status" > "$OUT/exit.txt"
if [ -d "$RESULT" ]; then
  xcrun xcresulttool get test-results summary --path "$RESULT" --format json > "$OUT/summary.json"
  xcrun xcresulttool get test-results tests --path "$RESULT" --format json > "$OUT/tests.json"
  xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/attachments" > "$OUT/attachments-export.log"
fi
container=$(xcrun simctl get_app_container "$SIM" com.immerse.PopulatedJournalHarness data)
ruby -rjson -rfileutils -e '
 before=JSON.parse(File.read(ARGV[1])); out=ARGV[2]; FileUtils.mkdir_p(out)
 paths=Dir.glob(File.join(ARGV[0],"Documents/WorkflowHistories/*")).reject{|p|before.include?(File.basename(p))}
 paths.each{|p|FileUtils.cp_r(p,out)}
 puts JSON.pretty_generate(paths.map{|p|File.basename(p)})
' "$container" "$OUT/histories-before.json" "$OUT/histories" > "$OUT/histories-new.json"
find DerivedData/PopulatedJournal037/Build/Products/Debug-iphonesimulator/PopulatedJournalHarness.app \
  -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 > "$OUT/app-files.sha256"
exit "$status"
