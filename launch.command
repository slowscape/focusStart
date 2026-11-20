#!/usr/bin/env bash
# macOS: double-click this in Finder to start StepTask (it runs launch.sh next to it).
# The first time, macOS may ask you to allow it: right-click > Open.
cd "$(dirname "$0")" && exec ./launch.sh "$@"
