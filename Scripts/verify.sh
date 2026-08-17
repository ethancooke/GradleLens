#!/usr/bin/env bash
#
# Quiet verification gate: debug build + release build + tests. Prints one line per step on
# success and only spills full output when a step fails — so the (human or AI) caller reads a
# short summary instead of hundreds of lines of build log.
#
# Usage:
#   Scripts/verify.sh            # build (debug) + build (release) + test
#   Scripts/verify.sh --quick    # skip the release build (faster inner-loop check)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1

green() { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
red()   { printf '\033[1;31m✗\033[0m %s\n' "$*"; }

# Run a step quietly; on failure, dump its captured output and abort.
step() {
    local name="$1"; shift
    local log; log="$(mktemp)"
    if "$@" >"$log" 2>&1; then
        green "$name"
        rm -f "$log"
    else
        red "$name — failed:"
        echo
        cat "$log"
        rm -f "$log"
        exit 1
    fi
}

step "build (debug)"   swift build
[[ "$QUICK" == "1" ]] || step "build (release)" swift build -c release
step "test"            swift test

echo
green "All checks passed."
