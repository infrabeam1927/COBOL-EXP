#!/usr/bin/env bash
# Compiles bank-system.cob and drives it through a scripted sequence of
# transactions, producing data/bank-accounts.dat and data/event_log.csv
# for the web visualizer to render.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COBOL_DIR="$REPO_ROOT/cobol"
DATA_DIR="$REPO_ROOT/data"
SOURCE="$COBOL_DIR/bank-system.cob"
BINARY="$COBOL_DIR/bank-system"

if ! command -v cobc >/dev/null 2>&1; then
  echo "ERROR: cobc (the GnuCOBOL compiler) was not found on PATH." >&2
  echo "Install GnuCOBOL with indexed-file (ISAM) support enabled — see README.md." >&2
  exit 1
fi

mkdir -p "$DATA_DIR"

echo "==> Compiling $SOURCE"
cobc -x "$SOURCE" -o "$BINARY"

echo "==> Resetting demo data in $DATA_DIR"
rm -f "$DATA_DIR/bank-accounts.dat" "$DATA_DIR/event_log.csv"

echo "==> Running scripted transaction sequence"
# Menu options: 1=create 2=deposit 3=withdraw 4=balance 5=interest 6=history 7=exit
# Includes a deliberate insufficient-funds attempt to exercise the
# validation-fail path end to end.
(
  cd "$DATA_DIR"
  "$BINARY" <<'TRANSACTIONS'
1
ACC001
Aditya Roshan
1000.00
1
ACC002
Priya Nair
500.00
2
ACC001
250.50
3
ACC002
1000.00
3
ACC001
100.00
4
ACC002
5
ACC001
5.00
30
6
ACC001
2
ACC002
225.00
7
TRANSACTIONS
)

echo "==> Done. Generated:"
echo "    $DATA_DIR/bank-accounts.dat  (indexed account file)"
echo "    $DATA_DIR/event_log.csv      (structured event log)"
echo
echo "Open visualizer/index.html in a browser and click 'Try Auto-Fetch'"
echo "(when served from the repo root, e.g. 'python3 -m http.server'),"
echo "or upload $DATA_DIR/event_log.csv directly."
