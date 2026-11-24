#!/bin/bash
# Installs VIGE on this Mac, or finishes the setup of a copy you dragged into Applications.
# Safe to run again. No sudo.
#   Full install:  curl -fsSL https://verve2026.github.io/vige/install.sh | bash
#   Setup only:    curl -fsSL https://verve2026.github.io/vige/install.sh | bash -s -- --setup-only
set -euo pipefail
RELEASE="https://github.com/verve2026/vige/releases/latest/download"
DATA_DIR="$HOME/Library/Application Support/VIGE"
MODEL_NAME="ggml-large-v3-turbo.bin"
MODEL_SHA256="1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL_NAME"
SETUP_ONLY=0
[ "${1:-}" = "--setup-only" ] && SETUP_ONLY=1
step() { printf '\n==> %s\n' "$1"; }
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
for d in /opt/homebrew/bin /usr/local/bin; do case ":$PATH:" in *":$d:"*) ;; *) [ -d "$d" ] && PATH="$d:$PATH" ;; esac; done; export PATH

if [ "$(uname -m)" != "arm64" ]; then echo "This build is for Apple Silicon Macs (M1 or newer). This Mac is $(uname -m)."; exit 1; fi

if [ "$SETUP_ONLY" = 1 ]; then
  step "Checking VIGE in Applications"
  [ -d "/Applications/VIGE.app" ] || { echo "VIGE is not in Applications yet. Open the downloaded VIGE disk image, drag VIGE into Applications, then run this again."; exit 1; }
else
  step "Downloading VIGE"
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  curl -fL --retry 3 --progress-bar -o "$TMP/VIGE.zip" "$RELEASE/VIGE.zip"
  WANT="$(curl -fsSL --retry 3 "$RELEASE/VIGE.zip.sha256" | awk '{print $1}')"
  [ "$WANT" = "$(sha "$TMP/VIGE.zip")" ] || { echo "Download is corrupt (checksum mismatch). Run this again."; exit 1; }

  step "Installing to Applications"
  osascript -e 'tell application "VIGE" to quit' >/dev/null 2>&1 || true
  sleep 1
  rm -rf "/Applications/VIGE.app"
  ditto -x -k "$TMP/VIGE.zip" /Applications
fi
# A copy that came through a browser is quarantined; clearing it lets the app open without a warning.
xattr -dr com.apple.quarantine "/Applications/VIGE.app" 2>/dev/null || true
echo "Ready: /Applications/VIGE.app"

step "Speech model (1.6 GB, one time)"
mkdir -p "$DATA_DIR/models"
M="$DATA_DIR/models/$MODEL_NAME"
if [ -f "$M" ] && [ "$(sha "$M")" = "$MODEL_SHA256" ]; then
  echo "Already there."
else
  curl -fL --retry 3 -C - --progress-bar -o "$M.part" "$MODEL_URL"
  [ "$(sha "$M.part")" = "$MODEL_SHA256" ] || { rm -f "$M.part"; echo "Model download is corrupt. Run this again."; exit 1; }
  mv "$M.part" "$M"
fi

step "Tools VIGE needs"
MISSING=0
if command -v brew >/dev/null 2>&1; then
  command -v ffmpeg >/dev/null 2>&1 || brew install ffmpeg
  command -v whisper-cli >/dev/null 2>&1 || brew install whisper-cpp
else
  echo "MISSING  Homebrew. Install it from https://brew.sh, then run this again (it adds ffmpeg and whisper-cpp)."; MISSING=1
fi
[ -d "/Applications/Google Chrome.app" ] || { echo "MISSING  Google Chrome. Install it from google.com/chrome (VIGE posts to TikTok through it)."; MISSING=1; }
if command -v claude >/dev/null 2>&1; then echo "Claude Code: found"; else echo "MISSING  Claude Code (the AI editor and caption writer). Install it from claude.com/claude-code, then run: claude auth login"; MISSING=1; fi

step "Done"
[ "$MISSING" = 0 ] && echo "Everything is in place." || echo "VIGE is installed, but see the MISSING lines above. Settings > Setup check in the app shows the same."
echo "Open VIGE from Applications, create your account, then add your TikTok accounts."
open -a VIGE || true
