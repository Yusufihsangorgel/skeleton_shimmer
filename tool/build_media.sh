#!/bin/sh
# Rebuilds everything under doc/ that the README and pub.dev point at. Run it
# from anywhere:
#
#   tool/build_media.sh
#
# Each figure comes out of a capture test that asserts what the figure is
# evidence for before it writes anything, so a picture in the README cannot
# quietly stop matching the code. The two conversions at the end are here for
# the same reason: they belong to a script rather than to somebody's shell
# history.
set -eu

cd "$(dirname "$0")/.."

need() {
  command -v "$1" >/dev/null 2>&1 && return 0
  echo "missing: $1 ($2)" >&2
  exit 1
}
need magick "brew install imagemagick"
need gif2webp "brew install webp"

# --- doc/sync.png : one sweep per card vs one ShimmerScope -------------------
# Rendered at 2x and then reduced to a 256-colour palette. Every colour in the
# figure sits on one grey ramp, so the palette is close to lossless (measured:
# RMSE 0.36%) and it takes the file from 177 KB to 54 KB. A README image is
# also a page-load cost.
SYNC_RAW="$(mktemp -t skeleton_shimmer_sync).png"
SKELETON_SHIMMER_SYNC_OUT="$SYNC_RAW" \
  flutter test --tags demo test/sync_capture_test.dart
magick "$SYNC_RAW" -colors 256 -define png:compression-level=9 doc/sync.png
rm -f "$SYNC_RAW"
echo "doc/sync.png            $(wc -c < doc/sync.png) bytes"

# --- doc/reduced-motion.png : sweep vs frozen sweep --------------------------
tool/capture_reduced_motion.sh
echo "doc/reduced-motion.png  $(wc -c < doc/reduced-motion.png) bytes"

# --- doc/demo.webp : the loading demo ----------------------------------------
# Same animation as doc/demo.gif, an eleventh of the bytes. doc/demo.gif is
# kept as the capture's output; this is what the README links to.
gif2webp -q 60 -m 6 -mixed doc/demo.gif -o doc/demo.webp >/dev/null
echo "doc/demo.webp           $(wc -c < doc/demo.webp) bytes"
