#!/usr/bin/env bash
set -euo pipefail

RAW_URL="https://raw.githubusercontent.com/F3aarLeSS/DNSTest/main/NeoDNS_Top3.command"

# Check curl or wget
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$RAW_URL" | bash
elif command -v wget >/dev/null 2>&1; then
  wget -qO- "$RAW_URL" | bash
else
  echo "Error: require curl or wget to continue." >&2
  exit 1
fi
