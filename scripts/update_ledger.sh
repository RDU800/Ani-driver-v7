#!/usr/bin/env bash
set -euo pipefail

LEDGER_FILE="${1:-BUILD_LEDGER.md}"
DRIVER_VER="${2:-dev}"
UPSTREAM_REF="${3:-unknown}"
PATCH_DIR="${4:-patches}"

COMMIT_SHA="$(git rev-parse --short HEAD)"
RUN_ID="${GITHUB_RUN_ID:-local}"
UTC_NOW="$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

if [ -d "$PATCH_DIR" ] && compgen -G "$PATCH_DIR/*.patch" > /dev/null; then
  PATCH_LIST="$(ls -1 "$PATCH_DIR"/*.patch | xargs -n1 basename | paste -sd ', ' -)"
else
  PATCH_LIST="none"
fi

if [ ! -f "$LEDGER_FILE" ]; then
  cat <<'EOF' > "$LEDGER_FILE"
# Ani-Driver Build & Emulator Performance Ledger

| Date (UTC) | Driver Ver | Commit | Run | Upstream Ref | Patches Included | Emulator / Game Notes | Perf Delta vs Prev |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
EOF
fi

echo "| ${UTC_NOW} | ${DRIVER_VER} | \`${COMMIT_SHA}\` | ${RUN_ID} | \`${UPSTREAM_REF}\` | ${PATCH_LIST} | *Pending benchmark* | *TBD* |" >> "$LEDGER_FILE"
