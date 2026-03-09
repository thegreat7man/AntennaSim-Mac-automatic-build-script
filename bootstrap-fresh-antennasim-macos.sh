#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OVERLAY_SOURCE="${OVERLAY_SOURCE:-$SCRIPT_DIR/bootstrap-assets/source-overlay}"
REPO_URL="${REPO_URL:-https://github.com/EA1FUO/AntennaSim.git}"
TARGET_DIR="${1:-$SCRIPT_DIR/AntennaSim-fresh}"
OUTPUT_APP="${OUTPUT_APP:-$SCRIPT_DIR/AntennaSim.app}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_cmd git
require_cmd rsync
require_cmd swiftc
require_cmd xcodebuild

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is intended for macOS."
  exit 1
fi

if [[ ! -d "$OVERLAY_SOURCE" ]]; then
  echo "Standalone overlay bundle not found at $OVERLAY_SOURCE"
  exit 1
fi

if [[ ! -f "$OVERLAY_SOURCE/scripts/build-macos-app.sh" || ! -f "$OVERLAY_SOURCE/desktop/macos/AntennaSimApp.swift" ]]; then
  echo "Overlay bundle is missing the standalone macOS build layer."
  exit 1
fi

if [[ -e "$TARGET_DIR" ]]; then
  if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Target exists and is not a directory: $TARGET_DIR"
    exit 1
  fi
  if [[ -n "$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "Target directory is not empty: $TARGET_DIR"
    exit 1
  fi
else
  mkdir -p "$TARGET_DIR"
fi

echo "Cloning latest upstream repo into $TARGET_DIR"
git clone --recursive "$REPO_URL" "$TARGET_DIR"

echo "Overlaying portable macOS app layer from local bundle"
rsync -a \
  --exclude '.git' \
  --exclude '.gitmodules' \
  --exclude '.local' \
  --exclude 'frontend/node_modules' \
  --exclude 'frontend/dist' \
  --exclude 'dist-macos' \
  --exclude 'wasm/build' \
  --exclude '.DS_Store' \
  "$OVERLAY_SOURCE/" "$TARGET_DIR/"

git -C "$TARGET_DIR" submodule update --init --recursive

echo "Building standalone macOS app inside cloned folder"
"$TARGET_DIR/scripts/build-macos-app.sh"

echo "Copying app next to the bootstrap script"
rm -rf "$OUTPUT_APP"
cp -R "$TARGET_DIR/dist-macos/AntennaSim.app" "$OUTPUT_APP"

echo ""
echo "Fresh portable build completed:"
echo "  Project: $TARGET_DIR"
echo "  App:     $OUTPUT_APP"
