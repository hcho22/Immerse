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
# populated Journal card in MovieCapacityUITests, the Film Stock choice in
# FilmStockUITests and the low-storage warning in LowStorageUITests) run once more in dark;
# each simulator's own preferences are restored on exit. Every simulator booted here has
# its photo-analysis service switched off first (Scripts/quiet-simulator.sh).
pinned_simulators=""
pin_simulator() {
    # The quiet script boots the simulator itself, after settings that must be in place before the first boot.
    sh Scripts/quiet-simulator.sh "$1"
    xcrun simctl bootstatus "$1" -b > /dev/null
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
# Scripts/screen-tests.sh notes each set of screen tests that passed only through its one rerun, which it is
# allowed when the simulator's own log shows it dropped a failed test's touch. They are said again here, last.
mkdir -p DerivedData
rm -f DerivedData/validation-notes.txt
finish() {
    restore_simulators
    if [ -s DerivedData/validation-notes.txt ]; then
        echo "Validation notes:"
        cat DerivedData/validation-notes.txt
    fi
}
trap finish EXIT
xcodebuild -version
swift --version
if runs packages && [ -n "${IMMERSE_STOREKIT_SIMULATOR_UDID:-}" ]; then
    # The billing simulator boots first, though its tests run last. Minutes after a new simulator's first boot,
    # trustd installs the trust data it has just downloaded; on CI its pinning database update held every trust
    # check for three minutes, in which StoreKit's local test server could not sign an approved purchase
    # (Evidence/NativeApp/main-ci-flakes-066.md). Booted here, the simulator does that during the Mac tests.
    sh Scripts/quiet-simulator.sh "$IMMERSE_STOREKIT_SIMULATOR_UDID"
fi
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
    # EXPERIMENT C: build before the simulator boots
    xcodebuild -quiet -project "Probes/$harness_probe/$harness_probe.xcodeproj" -scheme "$harness_probe" \
        -derivedDataPath DerivedData/PopulatedJournalHarness \
        -destination "platform=iOS Simulator,id=$IMMERSE_WORKFLOW_SIMULATOR_UDID" CODE_SIGNING_ALLOWED=NO build-for-testing
    pin_simulator "$IMMERSE_WORKFLOW_SIMULATOR_UDID"
    # The Photos permission workflow needs a denied add-only status; the harness has no usage key to prompt.
    xcrun simctl privacy "$IMMERSE_WORKFLOW_SIMULATOR_UDID" revoke photos-add com.immerse.PopulatedJournalHarness
    sh Scripts/screen-tests.sh "$IMMERSE_WORKFLOW_SIMULATOR_UDID" Populated test-without-building "" \
        -project "Probes/$harness_probe/$harness_probe.xcodeproj" -scheme "$harness_probe" \
        -derivedDataPath DerivedData/PopulatedJournalHarness
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
    # EXPERIMENT C: build before the simulator boots
    xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -derivedDataPath DerivedData/ValidationSimulator \
        -destination "platform=iOS Simulator,id=$IMMERSE_SIMULATOR_UDID" CODE_SIGNING_ALLOWED=NO build-for-testing
    # Run whole, the render tests above have pinned this simulator.
    runs packages || pin_simulator "$IMMERSE_SIMULATOR_UDID"
    # Run whole, the app's screen tests are one run. As parts, ui-text takes the text-size suites, which are most
    # of the minutes, and ui-flows takes every other suite, whatever is added later.
    # shellcheck disable=SC2086 # the suite lists are words
    case "$part" in
        ui-text) selection=$(suites -only-testing $text_size_suites) ;;
        ui-flows) selection="-only-testing:$app_screen_test_target$(suites -skip-testing $text_size_suites)" ;;
        *) selection="-only-testing:$app_screen_test_target" ;;
    esac
    sh Scripts/screen-tests.sh "$IMMERSE_SIMULATOR_UDID" Validation test-without-building "$selection" \
        -project App/Immerse/Immerse.xcodeproj -scheme Immerse -derivedDataPath DerivedData/ValidationSimulator
fi
if runs ui-flows && [ -n "${IMMERSE_SIMULATOR_UDID:-}" ]; then
    # The accessibility audits, including the populated Journal card and Film Stock audits, again in dark
    # appearance, from the same build; a test cannot switch the app's appearance itself (Evidence/NativeApp/qa13-audit-exceptions-052.md).
    xcrun simctl ui "$IMMERSE_SIMULATOR_UDID" appearance dark
    # shellcheck disable=SC2086 # the suite list is words
    sh Scripts/screen-tests.sh "$IMMERSE_SIMULATOR_UDID" ValidationDark test-without-building \
        "$(suites -only-testing $dark_suites)" \
        -project App/Immerse/Immerse.xcodeproj -scheme Immerse -derivedDataPath DerivedData/ValidationSimulator
    xcrun simctl ui "$IMMERSE_SIMULATOR_UDID" appearance light
fi
if runs packages && [ -n "${IMMERSE_STOREKIT_SIMULATOR_UDID:-}" ]; then
    xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
        -destination "platform=iOS Simulator,id=$IMMERSE_STOREKIT_SIMULATOR_UDID" \
        -derivedDataPath DerivedData/ValidationSimulator \
        -resultBundlePath "DerivedData/StoreKit-$(date -u +%Y%m%dT%H%M%SZ).xcresult" \
        -only-testing:"$app_unit_test_target" \
        -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 \
        CODE_SIGNING_ALLOWED=NO test
fi
