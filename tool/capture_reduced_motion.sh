#!/bin/sh
# Regenerates doc/reduced-motion.png, the figure the README's reduced-motion
# section links to. Run it from anywhere:
#
#   tool/capture_reduced_motion.sh
#
# The capture test writes to a temp file unless it is told otherwise, so the
# committed figure is always the output of a run rather than something
# assembled by hand once and then quietly left behind.
set -eu

cd "$(dirname "$0")/.."

SKELETON_SHIMMER_DOC_OUT="$PWD/doc/reduced-motion.png" \
  flutter test --tags demo test/reduced_motion_capture_test.dart
