#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
package=2026-09-29-film-camera-experience-v1
mkdir -p DerivedData
temporary=$(mktemp -d "DerivedData/requirement-map.XXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

awk '
    /^## Deferred to v2/ { exit }
    /^- \[ \] [A-Z]+-[0-9][0-9] / { print $4 }
    /^- \[x\] DEC-09 / { print $3 }
' "$package/$package-task-tracker.md" | sort > "$temporary/tracker"
awk -F '|' '
    { id=$2; gsub(/^ +| +$/, "", id) }
    id ~ /^[A-Z]+-[0-9][0-9]$/ { print id }
' "$package/$package-evidence-map.md" | sort > "$temporary/map"
diff -u "$temporary/tracker" "$temporary/map"
test "$(wc -l < "$temporary/map" | tr -d ' ')" = 136
test -z "$(uniq -d "$temporary/map")"

awk -F '|' '
    { id=$2; gsub(/^ +| +$/, "", id) }
    id ~ /^FR-[0-9][0-9] A[0-9][0-9]$/ { print id }
' "$package/$package-acceptance-evidence.md" | sort > "$temporary/clauses"
test "$(wc -l < "$temporary/clauses" | tr -d ' ')" = 74
test -z "$(uniq -d "$temporary/clauses")"
awk -F '|' '
    /^## Section 11 Invariants/ { inInvariants=1; next }
    inInvariants && /^## / { exit }
    inInvariants && /^\| / && $2 !~ /Invariant|---/ { print $2 }
' "$package/$package-acceptance-evidence.md" > "$temporary/invariants"
test "$(wc -l < "$temporary/invariants" | tr -d ' ')" = 9
printf '%s\n' 'Traceability: 136 intake IDs, 74 unique acceptance clauses, 9 invariants. This is coverage, not product acceptance.'
