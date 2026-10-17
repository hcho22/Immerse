#!/bin/sh
# Holds the repository to Scripts/validation-parts.sh, which says what each part of validation runs. A package,
# probe, test target or suite that belongs to no part fails here, so one added later cannot fall out of the
# check unnoticed. So does a listed name that no longer exists, since a test selection that names a missing
# suite runs nothing.
set -eu
cd "$(dirname "$0")/.."
. Scripts/validation-parts.sh
failed=0
fail() { echo "verify-validation-parts: $*" >&2; failed=1; }
listed() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }
# The test bundle targets an XcodeGen project defines.
test_targets() {
    awk '
        /^targets:/ { inside = 1; next }
        /^[^ #]/ { inside = 0 }
        inside && /^  [^ #]/ { name = $1; sub(/:$/, "", name) }
        inside && /^    type: bundle\.(unit-test|ui-testing)/ { print name }
    ' "$1"
}
# The test classes in a directory of test sources: the XCTestCase subclasses and the screen tests' own base classes,
# ScreenTestCase and HarnessTestCase, each of which is an XCTestCase whose setUp holds the simulator portrait. The
# base classes themselves, which hold no tests, are left out.
suites() {
    sed -nE 's/^.*class ([A-Za-z0-9_]*) *: *(XCTestCase|ScreenTestCase|HarnessTestCase).*$/\1 \2/p' "$1"/*.swift \
        | awk '$2 != "XCTestCase" || ($1 != "ScreenTestCase" && $1 != "HarnessTestCase") { print $1 }' | sort
}

for manifest in Packages/*/Package.swift; do
    [ -f "$manifest" ] || continue
    name=$(basename "$(dirname "$manifest")")
    listed "$name" "$mac_packages" || fail "Packages/$name belongs to no part; add it to mac_packages"
done
for name in $mac_packages; do
    [ -f "Packages/$name/Package.swift" ] || fail "mac_packages names $name, which is not a package in Packages"
done

probes="$mac_probes $built_probes $harness_probe $separate_probes"
for directory in Probes/*/; do
    name=$(basename "$directory")
    [ -f "$directory/Package.swift" ] || ls -d "$directory"*.xcodeproj > /dev/null 2>&1 || continue
    listed "$name" "$probes" || fail "Probes/$name belongs to no part; add it to mac_probes, built_probes or separate_probes"
done
for name in $probes; do
    [ -d "Probes/$name" ] || fail "a probe list names $name, which is not in Probes"
done
for name in $mac_probes $built_probes; do
    [ -f "Probes/$name/Package.swift" ] || fail "Probes/$name is listed as a package and has no Package.swift"
done

for target in $(test_targets App/Immerse/project.yml); do
    listed "$target" "$app_unit_test_target $app_screen_test_target" \
        || fail "the app's test target $target belongs to no part"
done
for target in $app_unit_test_target $app_screen_test_target; do
    listed "$target" "$(test_targets App/Immerse/project.yml | tr '\n' ' ')" \
        || fail "validation selects the app's test target $target, which App/Immerse/project.yml does not define"
done
for target in $(test_targets "Probes/$harness_probe/project.yml"); do
    listed "$target" "$harness_test_targets" || fail "the harness test target $target belongs to no part"
done
for target in $harness_test_targets; do
    listed "$target" "$(test_targets "Probes/$harness_probe/project.yml" | tr '\n' ' ')" \
        || fail "harness_test_targets names $target, which the harness project does not define"
done

screen_suites=$(suites App/Immerse/UITests | tr '\n' ' ')
flow_suites=""
for suite in $screen_suites; do
    listed "$suite" "$text_size_suites" || flow_suites="$flow_suites $suite"
done
for suite in $text_size_suites $dark_suites; do
    listed "$suite" "$screen_suites" || fail "validation selects the suite $suite, which App/Immerse/UITests does not define"
done
[ -n "$flow_suites" ] || fail "every suite of $app_screen_test_target is a text-size suite, so ui-flows would run nothing"

[ "$failed" = 0 ] || exit 1
echo "Validation parts: packages runs $(echo "$mac_packages" | wc -w | tr -d ' ') packages, $(echo "$mac_probes" | wc -w | tr -d ' ') probes and $app_unit_test_target; harness runs $harness_test_targets; ui-text runs $text_size_suites; ui-flows runs$flow_suites and, in dark, $dark_suites."
