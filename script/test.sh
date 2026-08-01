#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TEMP_DIR"' EXIT

xcrun swiftc \
  "$ROOT_DIR/Sources/Snappy/Models/SnapZone.swift" \
  "$ROOT_DIR/Sources/Snappy/Support/ShortcutMode.swift" \
  "$ROOT_DIR/Sources/Snappy/Support/ScreenLayoutGeometry.swift" \
  "$ROOT_DIR/Sources/Snappy/Support/HotspotMatcher.swift" \
  "$ROOT_DIR/Sources/Snappy/Support/WindowFrameGeometry.swift" \
  "$ROOT_DIR/Tests/SnappyCoreTests/SnapZoneSelfTests.swift" \
  -o "$TEST_TEMP_DIR/SnapZoneSelfTests"

"$TEST_TEMP_DIR/SnapZoneSelfTests"
