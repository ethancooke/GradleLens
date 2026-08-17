#!/usr/bin/env bash
#
# Format Swift sources with the toolchain's `swift format` (config: .swift-format).
#
# Formatting is a convenience, NOT a gate — the project's only hard check is the Swift 6 compiler
# (see AGENTS.md). Use this to keep code visually consistent; CI does not enforce it.
#
# Usage:
#   Scripts/format.sh          # format in place
#   Scripts/format.sh --lint   # report deviations without editing (exit non-zero if any)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! swift format --version >/dev/null 2>&1; then
    echo "ERROR: 'swift format' is unavailable. It ships with the Swift 6 toolchain (Xcode 26+)." >&2
    exit 1
fi

TARGETS=(Package.swift Sources Tests)

if [[ "${1:-}" == "--lint" ]]; then
    echo "Linting formatting (no files changed)…"
    swift format lint --strict --recursive "${TARGETS[@]}"
    echo "Formatting: OK"
else
    echo "Formatting in place…"
    swift format --in-place --recursive "${TARGETS[@]}"
    echo "Done. Review with: git diff"
fi
