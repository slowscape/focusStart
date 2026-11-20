#!/usr/bin/env bash
# StepTask launcher for macOS and Linux (the Windows one is launch.bat).
# First run: creates .venv next to this file and installs requirements.txt (a minute or two).
# Later runs start the app straight away. Any arguments are passed on, e.g.:
#   ./launch.sh --data-dir "$HOME/Dropbox/StepTask"
set -euo pipefail
cd "$(dirname "$0")"
VENV=.venv

# Already set up for this requirements.txt? Start right away.
if [ -x "$VENV/bin/python" ] && cmp -s requirements.txt "$VENV/.installed"; then
  nohup "$VENV/bin/python" -m app "$@" >/dev/null 2>&1 &
  exit 0
fi

echo "StepTask: first-time setup. This takes a minute or two..."
echo

PY=""
for candidate in python3.12 python3; do
  if command -v "$candidate" >/dev/null 2>&1 &&
     "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
    PY="$candidate"; break
  fi
done
if [ -z "$PY" ]; then
  echo "Couldn't find Python 3.10 or newer (tried python3.12 and python3)."
  echo "macOS: install Python 3.12 from https://www.python.org/downloads/ ,"
  echo "Linux: install python3 and python3-venv with your package manager. Then run this again."
  exit 1
fi
echo "Using: $PY"

if [ ! -x "$VENV/bin/python" ]; then
  if ! "$PY" -m venv "$VENV"; then
    echo "Couldn't create the .venv folder. On Debian/Ubuntu: sudo apt install python3-venv"
    exit 1
  fi
fi
"$VENV/bin/python" -m pip install --upgrade pip
"$VENV/bin/python" -m pip install -r requirements.txt
if ! "$VENV/bin/python" -c "import PySide6.QtQuick, PySide6.QtQuickControls2, PySide6.QtMultimedia"; then
  echo
  echo "PySide6 installed, but its Qt files couldn't be loaded."
  echo "Linux: Qt needs libxcb-cursor0 (Debian/Ubuntu: sudo apt install libxcb-cursor0)."
  echo "Otherwise delete the .venv folder next to this script and run it again."
  exit 1
fi
cp requirements.txt "$VENV/.installed"

nohup "$VENV/bin/python" -m app "$@" >/dev/null 2>&1 &
