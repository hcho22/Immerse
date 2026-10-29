#!/bin/sh
# After a failed packages part, keeps what the machine recorded about a media read that did not finish, so a clip that
# failed to read on CI can be told from a decoder that failed (Evidence/NativeApp/developed-clip-reader-failure-070.md):
# the crash and memory-pressure reports of the video decoder service and of the test processes, the system log of the
# last minutes filtered to them, media errors and memory-pressure lines, and the Film directories of the process-exit
# probe that did not finish, which hold only synthetic media. It reads nothing else and never fails the job itself.
# Usage: sh Scripts/collect-failure-evidence.sh [output directory]
set -u
out=${1:-DerivedData/FailureEvidence}
report_dirs=${IMMERSE_EVIDENCE_REPORT_DIRS:-"$HOME/Library/Logs/DiagnosticReports /Library/Logs/DiagnosticReports"}
films=${IMMERSE_EVIDENCE_FILMS_DIR:-"$(getconf DARWIN_USER_TEMP_DIR)DevelopmentProcessExit"}
minutes=20
log_seconds=300
log_bytes=50000000
most_reports=20
most_films=10
rm -rf "$out"
mkdir -p "$out/reports" "$out/films"
notes="$out/notes.txt"
: > "$notes"

# The decoder service's crashes, memory-pressure kills, and crashes of the test runner and the probe's helper process.
# shellcheck disable=SC2086 # the report folders are words
for dir in $report_dirs; do
    [ -d "$dir" ] || continue
    for report in "$dir"/VTDecoderXPCService* "$dir"/JetsamEvent* "$dir"/DevelopmentExitWorker* "$dir"/xctest*; do
        [ -f "$report" ] && echo "$report"
    done
done > "$out/report-list.txt"
# The newest first, and only so many.
if [ -s "$out/report-list.txt" ]; then
    tr '\n' '\0' < "$out/report-list.txt" | xargs -0 stat -f '%m %N' | sort -rn | head -n "$most_reports" \
        | cut -d ' ' -f 2- | while IFS= read -r report; do
            cp "$report" "$out/reports/" || echo "could not copy $report" >> "$notes"
        done
fi
rm -f "$out/report-list.txt"
echo "reports kept: $(find "$out/reports" -type f | wc -l | tr -d ' ')" >> "$notes"

# The system log of the last minutes: everything of the decoder service, and of the test processes their errors, faults
# and decoder connection lines, media errors from any process, and the kernel's memory-pressure lines. Stopped after
# $log_seconds seconds or $log_bytes bytes, whichever comes first.
predicate='process == "VTDecoderXPCService"'
predicate="$predicate"' OR (process IN {"xctest", "DevelopmentExitWorker", "swiftpm-testing-helper"}'
predicate="$predicate"' AND (messageType == error OR messageType == fault'
predicate="$predicate"' OR eventMessage CONTAINS "com.apple.coremedia.videodecoder" OR eventMessage CONTAINS "CONNECTION_INTERRUPTED"))'
predicate="$predicate"' OR (subsystem == "com.apple.coremedia" AND messageType == error)'
predicate="$predicate"' OR (process == "kernel" AND eventMessage CONTAINS "memorystatus")'
{
    perl -e 'alarm shift @ARGV; exec @ARGV or exit 127' "$log_seconds" \
        log show --last "${minutes}m" --style compact --predicate "$predicate" 2> "$out/system-log-errors.txt"
    echo $? > "$out/system-log-status"
} | head -c "$log_bytes" > "$out/system-log.txt"
status=$(cat "$out/system-log-status" 2> /dev/null || echo unknown)
rm -f "$out/system-log-status"
echo "system log: $(wc -c < "$out/system-log.txt" | tr -d ' ') bytes, log show ended with status $status" >> "$notes"
[ -s "$out/system-log-errors.txt" ] || rm -f "$out/system-log-errors.txt"

# A probe Film whose test finished has its resumed snapshot; one without it is where a test stopped.
kept=0
if [ -d "$films" ]; then
    for film in "$films"/*/; do
        film=${film%/}
        [ -d "$film" ] || continue
        [ -f "$film/resumed.json" ] && continue
        [ "$kept" -lt "$most_films" ] || { echo "more unfinished Films than $most_films; the rest were left" >> "$notes"; break; }
        cp -R "$film" "$out/films/" || echo "could not copy $film" >> "$notes"
        kept=$((kept + 1))
    done
fi
echo "unfinished probe Films kept: $kept" >> "$notes"
cat "$notes"
exit 0
