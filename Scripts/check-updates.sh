#!/usr/bin/env bash
#
# Maintenance audit for keeping the template current. Report-only — it never mutates the repo.
#
# It complements Dependabot (which already opens PRs for GitHub Actions and SwiftPM version
# bumps) by surfacing the things Dependabot can't see:
#   - Apple SDK deprecation warnings (early signal that Swift/AppKit APIs are drifting).
#   - The CI runner image label (macos-NN) — Dependabot doesn't bump this.
#   - The Swift toolchain / deployment target actually in use.
#   - Whether pinned Actions have a newer major (best-effort, needs `gh`).
#   - A build-health check.
#
# Run it periodically (see docs/MAINTAINING.md). Act on the findings by hand or with an AI; the
# judgment calls (raising the Swift/macOS baseline, adopting new Apple guidance) live in that doc.
#
# Usage: Scripts/check-updates.sh
#
set -uo pipefail   # deliberately NOT -e: run every section, then summarize.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

hdr()  { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }
note() { printf '   %s\n' "$*"; }
warn() { printf '   \033[1;33m! %s\033[0m\n' "$*"; }
ok()   { printf '   \033[1;32m%s\033[0m\n' "$*"; }

FINDINGS=0
flag() { FINDINGS=$((FINDINGS+1)); warn "$*"; }

# --- 1. Toolchain snapshot -------------------------------------------------------------------
hdr "Toolchain in use"
note "$(swift --version 2>/dev/null | head -1 || echo 'swift: not found')"
note "$(xcodebuild -version 2>/dev/null | tr '\n' ' ' || echo 'xcodebuild: not found')"
note "macOS $(sw_vers -productVersion 2>/dev/null || echo '?') on $(uname -m)"
TOOLS_VERSION="$(grep -m1 'swift-tools-version' Package.swift | sed 's/.*version:[[:space:]]*//')"
DEPLOY_TARGET="$(grep -oE '\.macOS\(\.v[0-9]+\)' Package.swift | head -1)"
note "Package.swift: swift-tools-version $TOOLS_VERSION, deployment target ${DEPLOY_TARGET:-?}"
INSTALLED_SWIFT="$(swift --version 2>/dev/null | sed -n 's/.*Swift version \([0-9][0-9.]*\).*/\1/p' | head -1)"
if [[ -n "$INSTALLED_SWIFT" && -n "$TOOLS_VERSION" ]]; then
    tools_maj="${TOOLS_VERSION%%.*}"
    tools_rest="${TOOLS_VERSION#*.}"
    tools_min="${tools_rest%%.*}"
    inst_maj="${INSTALLED_SWIFT%%.*}"
    inst_rest="${INSTALLED_SWIFT#*.}"
    inst_min="${inst_rest%%.*}"
    if [[ "$tools_maj" =~ ^[0-9]+$ && "$tools_min" =~ ^[0-9]+$ && \
          "$inst_maj" =~ ^[0-9]+$ && "$inst_min" =~ ^[0-9]+$ ]]; then
        tools_key=$((tools_maj * 1000 + tools_min))
        inst_key=$((inst_maj * 1000 + inst_min))
        if (( inst_key - tools_key >= 2 )); then
            flag "swift-tools-version $TOOLS_VERSION is ≥2 minors behind installed Swift $INSTALLED_SWIFT — consider raising it (docs/MAINTAINING.md)."
        elif (( inst_key > tools_key )); then
            note "Installed Swift $INSTALLED_SWIFT is newer than tools-version $TOOLS_VERSION (judgment call to raise)."
        fi
    fi
fi
note "Compare against the latest stable Swift/Xcode; raising the baseline is a judgment call (docs/MAINTAINING.md)."

# --- 2. CI runner image ----------------------------------------------------------------------
hdr "CI runner image (Dependabot does NOT bump this)"
RUNNERS="$(grep -rhoE 'runs-on:[[:space:]]*[^ ]+' .github/workflows 2>/dev/null | sort -u)"
if [[ -n "$RUNNERS" ]]; then
    while IFS= read -r r; do note "$r"; done <<< "$RUNNERS"
    note "Latest images: https://github.com/actions/runner-images (bump macos-NN when a newer stable ships)."
else
    note "No workflows found."
fi

# --- 3. Pinned GitHub Actions ----------------------------------------------------------------
hdr "Pinned GitHub Actions"
USES="$(grep -rhoE 'uses:[[:space:]]*[^@[:space:]]+@[^[:space:]]+' .github/workflows 2>/dev/null \
        | sed -E 's/uses:[[:space:]]*//' | sort -u)"
if [[ -z "$USES" ]]; then
    note "No actions referenced."
elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    while IFS= read -r u; do
        repo="${u%@*}"; ref="${u#*@}"
        latest="$(gh api "repos/$repo/releases/latest" --jq .tag_name 2>/dev/null || echo '')"
        if [[ -z "$latest" ]]; then
            note "$u  (no published release to compare)"
        elif [[ "${latest%%.*}" != "${ref%%.*}" ]]; then
            flag "$u  → newer major available: $latest"
        else
            ok "$u  (current major; Dependabot handles minor/patch)"
        fi
    done <<< "$USES"
else
    while IFS= read -r u; do note "$u"; done <<< "$USES"
    note "(Install + authenticate 'gh' to auto-compare against the latest release.)"
fi

# --- 4. SwiftPM dependencies -----------------------------------------------------------------
hdr "SwiftPM dependencies"
if grep -qE '^\s*\.package\(' Package.swift; then
    note "Checking for available updates (Dependabot also opens PRs for these)…"
    swift package update --dry-run 2>&1 | sed 's/^/   /' || warn "swift package update --dry-run failed (offline?)."
    note "Ensure Package.resolved is committed so builds are reproducible and Dependabot can read it."
else
    note "None declared. When you add dependencies, list their licenses in NOTICE."
fi

# --- 5. Deprecations + build health ----------------------------------------------------------
hdr "Deprecation warnings + build health"
BUILD_LOG="$(mktemp)"
if swift build >"$BUILD_LOG" 2>&1; then
    ok "swift build: clean"
else
    flag "swift build FAILED — see output below:"
    sed 's/^/   /' "$BUILD_LOG"
fi
DEPRECATIONS="$(grep -i 'deprecated' "$BUILD_LOG" || true)"
if [[ -n "$DEPRECATIONS" ]]; then
    flag "Deprecation warnings (Apple API drift — update to the recommended replacements):"
    echo "$DEPRECATIONS" | sed 's/^/     /'
else
    ok "No deprecation warnings."
fi
rm -f "$BUILD_LOG"

# --- Summary ---------------------------------------------------------------------------------
hdr "Summary"
if [[ "$FINDINGS" -eq 0 ]]; then
    ok "Nothing flagged. Template looks current."
else
    warn "$FINDINGS item(s) flagged above — review docs/MAINTAINING.md for how to act on them."
fi
note "Run Scripts/verify.sh for the full build+release+test gate."
