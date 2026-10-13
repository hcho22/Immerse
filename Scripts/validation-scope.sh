#!/bin/sh
# Decides which parts of validation a change needs, for the job matrix of .github/workflows/native.yml.
#
# A pull request that changes only Markdown cannot change what the screen tests drive. It runs the packages part
# alone, which holds the document checks and every test that drives no screen, and skips harness, ui-text and
# ui-flows (the captain, 2026-10-13). Any other file in the change runs all four parts, and so does every push to
# main, so main's own tree always has a full result. Markdown under App or the harness probe counts as code:
# Xcode bundles what it finds in their source directories into what the screen tests run.
#
# Usage: git diff --name-only --no-renames <base> <head> | sh Scripts/validation-scope.sh <event name>
# Prints two GitHub step outputs: `parts`, a JSON list, and `note`, one sentence for the summary check to say.
set -eu
event=${1:?usage: validation-scope.sh <event name> with the changed paths on standard input}
every='["packages","harness","ui-text","ui-flows"]'
if [ "$event" != pull_request ]; then
    printf 'parts=%s\nnote=%s\n' "$every" "Every part ran: only a pull request that changes Markdown alone may skip the screen tests."
    exit 0
fi
documents=0
code=""
while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
        App/*|Probes/PopulatedJournalHarness/*) code=$path; break ;;
        *.md) documents=$((documents + 1)) ;;
        *) code=$path; break ;;
    esac
done
if [ -n "$code" ]; then
    printf 'parts=%s\nnote=%s\n' "$every" "Every part ran: the pull request changes $code, which is not a document."
elif [ "$documents" = 0 ]; then
    printf 'parts=%s\nnote=%s\n' "$every" "Every part ran: the pull request's changed files could not be listed."
else
    printf 'parts=%s\nnote=%s\n' '["packages"]' "Markdown-only pull request ($documents files): harness, ui-text and ui-flows were skipped because Markdown cannot change what the screen tests drive. The packages part ran, with the document checks."
fi
