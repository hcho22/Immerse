#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Validation runs whole when IMMERSE_VALIDATE_PART is unset, as on a Mac here. CI runs it as four parts side by
# side, one per job (.github/workflows/native.yml): packages, harness, ui-text and ui-flows.
# Scripts/validation-parts.sh says what each part holds. A named part needs its simulators; run whole, a phase
# whose simulator is not given is skipped.
part=${IMMERSE_VALIDATE_PART:-all}
case "$part" in
    all) ;;
    packages) : "${IMMERSE_SIMULATOR_UDID:?the packages part needs IMMERSE_SIMULATOR_UDID}" \
                "${IMMERSE_STOREKIT_SIMULATOR_UDID:?the packages part needs IMMERSE_STOREKIT_SIMULATOR_UDID}" ;;
    harness) : "${IMMERSE_WORKFLOW_SIMULATOR_UDID:?the harness part needs IMMERSE_WORKFLOW_SIMULATOR_UDID}" ;;
    ui-text|ui-flows) : "${IMMERSE_SIMULATOR_UDID:?the $part part needs IMMERSE_SIMULATOR_UDID}" ;;
    *) echo "validate-local: unknown IMMERSE_VALIDATE_PART \"$part\" (packages, harness, ui-text or ui-flows)" >&2; exit 2 ;;
esac
. Scripts/validation-parts.sh
runs() { [ "$part" = all ] || [ "$part" = "$1" ]; }
# The -only-testing or -skip-testing flags that name suites of the app's screen tests.
suites() {
    flag=$1; shift
    for suite in "$@"; do printf ' %s:%s/%s' "$flag" "$app_screen_test_target" "$suite"; done
}
# Simulator UI gates run with light appearance and large text, like the retained
# harness runner, and the production accessibility audits (JournalFlowTests, the
# populated Journal card in MovieCapacityUITests and the Film Stock choice in
# FilmStockUITests) run once more in dark;
# each simulator's own preferences are restored on exit. Every simulator booted here has
# its photo-analysis service switched off first (Scripts/quiet-simulator.sh).
pinned_simulators=""
pin_simulator() {
    xcrun simctl bootstatus "$1" -b > /dev/null
    sh Scripts/quiet-simulator.sh "$1"
    case " $pinned_simulators " in
        *" $1:"*) ;;
        *) pinned_simulators="$pinned_simulators $1:$(xcrun simctl ui "$1" appearance):$(xcrun simctl ui "$1" content_size)" ;;
    esac
    xcrun simctl ui "$1" appearance light
    xcrun simctl ui "$1" content_size large
}
restore_simulators() {
    for entry in $pinned_simulators; do
        udid=${entry%%:*}; rest=${entry#*:}
        xcrun simctl ui "$udid" appearance "${rest%%:*}"
        xcrun simctl ui "$udid" content_size "${rest#*:}"
    done
}
trap restore_simulators EXIT
xcodebuild -version
swift --version
if runs packages; then
    # The scripts' own tests, then the guard that holds every test target to a part.
    python3 -B -m unittest discover -s Scripts/Tests
    sh Scripts/verify-validation-parts.sh
    sh Scripts/verify-requirement-map.sh
    for package in $mac_packages; do
        swift test --package-path "Packages/$package"
    done
    for probe in $mac_probes; do
        swift test --package-path "Probes/$probe"
    done
    for probe in $built_probes; do
        swift build --package-path "Probes/$probe"
    done
    sh Scripts/verify-document-package.sh
    xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
        -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/ValidationSimulator \
        CODE_SIGNING_ALLOWED=NO build
    xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
        -destination 'generic/platform=iOS' -derivedDataPath DerivedData/ValidationDevice \
        CODE_SIGNING_ALLOWED=NO build
    sh Scripts/verify-release-excludes-testing-unlock.sh
fi
if runs harness && [ -n "${IMMERSE_WORKFLOW_SIMULATOR_UDID:-}" ]; then
    pin_simulator "$IMMERSE_WORKFLOW_SIMULATOR_UDID"
    # The Photos permission workflow needs a denied add-only status; the harness has no usage key to prompt.
    xcrun simctl privacy "$IMMERSE_WORKFLOW_SIMULATOR_UDID" revoke photos-add com.immerse.PopulatedJournalHarness
    xcodebuild -quiet -project "Probes/$harness_probe/$harness_probe.xcodeproj" \
        -scheme "$harness_probe" \
        -destination "platform=iOS Simulator,id=$IMMERSE_WORKFLOW_SIMULATOR_UDID" \
        -derivedDataPath DerivedData/PopulatedJournalHarness \
        -resultBundlePath "DerivedData/Populated-$(date -u +%Y%m%dT%H%M%SZ).xcresult" \
        -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
        CODE_SIGNING_ALLOWED=NO test
fi
if runs packages && [ -n "${IMMERSE_SIMULATOR_UDID:-}" ]; then
    pin_simulator "$IMMERSE_SIMULATOR_UDID"
    # The render tests once more, inside the simulator. Core Image differs between a Mac and iOS in ways no test on a
    # Mac sees: a filter's default, the widest table it takes (Evidence/NativeApp/prd-2-slice-4-looks.md). The
    # version 2 pictures LegacyLookTests compares with were recorded on a Mac, and version 2 is frozen with one of
    # those defaults in it, so that class runs on the Mac only.
    (cd Packages/RenderCore && xcodebuild -quiet -scheme RenderCore \
        -destination "platform=iOS Simulator,id=$IMMERSE_SIMULATOR_UDID" \
        -derivedDataPath ../../DerivedData/RenderCoreSimulator \
        -resultBundlePath "../../DerivedData/RenderCore-$(date -u +%Y%m%dT%H%M%SZ).xcresult" \
        -skip-testing:RenderCoreTests/LegacyLookTests \
        -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
        CODE_SIGNING_ALLOWED=NO test)
fi
if { runs ui-text || runs ui-flows; } && [ -n "${IMMERSE_SIMULATOR_UDID:-}" ]; then
    pin_simulator "$IMMERSE_SIMULATOR_UDID"
    # Run whole, the app's screen tests are one run. As parts, ui-text takes the text-size suites, which are most
    # of the minutes, and ui-flows takes every other suite, whatever is added later.
    # shellcheck disable=SC2086 # the suite lists are words
    case "$part" in
        ui-text) selection=$(suites -only-testing $text_size_suites) ;;
        ui-flows) selection="-only-testing:$app_screen_test_target$(suites -skip-testing $text_size_suites)" ;;
        *) selection="-only-testing:$app_screen_test_target" ;;
    esac
    # shellcheck disable=SC2086 # the selection is flags
    xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
        -destination "platform=iOS Simulator,id=$IMMERSE_SIMULATOR_UDID" \
        -derivedDataPath DerivedData/ValidationSimulator \
        -resultBundlePath "DerivedData/Validation-$(date -u +%Y%m%dT%H%M%SZ).xcresult" \
        $selection \
        -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
        CODE_SIGNING_ALLOWED=NO test
fi
if runs ui-flows && [ -n "${IMMERSE_SIMULATOR_UDID:-}" ]; then
    # The accessibility audits, including the populated Journal card and Film Stock audits, again in dark
    # appearance, from the same build; a test cannot switch the app's appearance itself (Evidence/NativeApp/qa13-audit-exceptions-052.md).
    xcrun simctl ui "$IMMERSE_SIMULATOR_UDID" appearance dark
    # shellcheck disable=SC2086,SC2046 # the suite list and its flags are words
    xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
        -destination "platform=iOS Simulator,id=$IMMERSE_SIMULATOR_UDID" \
        -derivedDataPath DerivedData/ValidationSimulator \
        -resultBundlePath "DerivedData/ValidationDark-$(date -u +%Y%m%dT%H%M%SZ).xcresult" \
        $(suites -only-testing $dark_suites) \
        -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
        CODE_SIGNING_ALLOWED=NO test-without-building
    xcrun simctl ui "$IMMERSE_SIMULATOR_UDID" appearance light
fi
if runs packages && [ -n "${IMMERSE_STOREKIT_SIMULATOR_UDID:-}" ]; then
    sh Scripts/quiet-simulator.sh "$IMMERSE_STOREKIT_SIMULATOR_UDID"
    xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
        -destination "platform=iOS Simulator,id=$IMMERSE_STOREKIT_SIMULATOR_UDID" \
        -derivedDataPath DerivedData/ValidationSimulator \
        -resultBundlePath "DerivedData/StoreKit-$(date -u +%Y%m%dT%H%M%SZ).xcresult" \
        -only-testing:"$app_unit_test_target" \
        -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 \
        CODE_SIGNING_ALLOWED=NO test
fi
