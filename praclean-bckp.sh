#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/praClean.sh"

echo "[INFO] praclean-bckp.sh sekarang launcher kompatibilitas. Menjalankan praClean.sh..."
exec "$MAIN_SCRIPT" "$@"
