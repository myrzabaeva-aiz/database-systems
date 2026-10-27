#!/bin/zsh
# Lab 07 — Primary Keys
# Execute SQL in PostgreSQL and save the actual terminal output.
set -euo pipefail

LAB_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
mkdir -p "$LAB_DIR/output/screenshots"
OUTPUT_FILE="$LAB_DIR/output/psql-session.txt"

{
    echo '$ psql --version'
    psql --version
    echo ''
    echo '$ psql -X -a -v ON_ERROR_STOP=1 -P pager=off -d postgres -f lab-07/psql-demo.sql'
    psql -X -a -v ON_ERROR_STOP=1 -P pager=off -d postgres -f "$LAB_DIR/psql-demo.sql"
} 2>&1 | tee "$OUTPUT_FILE"

printf '\nLab 07 finished successfully. Output saved to: %s\n' "$OUTPUT_FILE"
