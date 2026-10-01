#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p DerivedData
temporary=$(mktemp -d "$PWD/DerivedData/documents-check.XXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
unzip -l 2026-09-29-film-camera-experience-v1-documents.zip
unzip -q 2026-09-29-film-camera-experience-v1-documents.zip -d "$temporary"
diff -qr 2026-09-29-film-camera-experience-v1 "$temporary/2026-09-29-film-camera-experience-v1"
