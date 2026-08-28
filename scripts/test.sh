#!/usr/bin/env bash
set -euo pipefail
SELECT="$(xcode-select -p 2>/dev/null || echo "")"
if [[ "$SELECT" == *"CommandLineTools"* ]]; then
  CANDIDATE="/Applications/Xcode-16.4.0.app/Contents/Developer"
  if [[ -d "$CANDIDATE" ]]; then
    export DEVELOPER_DIR="$CANDIDATE"
    echo "→ CLT detected, using DEVELOPER_DIR=$DEVELOPER_DIR" >&2
  else
    FOUND="$(ls -d /Applications/Xcode*.app/Contents/Developer 2>/dev/null | head -1 || true)"
    if [[ -n "$FOUND" ]]; then export DEVELOPER_DIR="$FOUND"; echo "→ using $DEVELOPER_DIR" >&2; fi
  fi
fi
exec xcrun --sdk macosx swift test "$@"
