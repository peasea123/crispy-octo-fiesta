#!/usr/bin/env bash
# Package the Roku channel into a sideload-ready zip.
#
# The Roku dev server expects the manifest, source/, components/, and images/
# directories to live at the root of the zip.
set -euo pipefail

cd "$(dirname "$0")"

OUT="roku-slideshow.zip"
rm -f "$OUT"

zip -r "$OUT" \
    manifest \
    source \
    components \
    images \
    -x "*.DS_Store" "*/__pycache__/*"

echo "Built $(pwd)/$OUT"
