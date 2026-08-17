#!/usr/bin/env bash
#
# Smoke test for the template's core promise: a fresh clone, rebranded, finalized, and stripped of
# scaffolding, still builds and tests. Copies the working tree to a temp dir, runs rename.sh +
# finalize.sh + strip-scaffolding.sh with throwaway values, asserts no operational file still points
# at a removed script or doc, then `swift build && swift test`. Never touches the real repo.
#
# Run locally before releasing template changes, and in CI (see .github/workflows/rebrand-smoke.yml).
#
# Usage: Scripts/test-rename.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NEW_NAME="SmokeApp"
NEW_PREFIX="com.smoketest"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
err() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }

log "Copying working tree to $TMP (excluding .git/.build/dist)"
rsync -a \
    --exclude='.git' --exclude='.build' --exclude='.swiftpm' --exclude='dist' \
    "$ROOT"/ "$TMP"/

cd "$TMP"

log "Sanity: template must be in its un-renamed state"
[[ -d "Sources/GradleLens" ]] || { err "Sources/GradleLens missing — not a fresh template?"; exit 1; }

log "rename.sh \"$NEW_NAME\" \"$NEW_PREFIX\""
Scripts/rename.sh "$NEW_NAME" "$NEW_PREFIX"

log "finalize.sh (throwaway repo/category/copyright)"
Scripts/finalize.sh \
    --app "$NEW_NAME" \
    --repo "smoketest/$NEW_NAME" \
    --category "public.app-category.productivity" \
    --copyright "Smoke Test"

log "Verifying the rebrand left no template markers behind"
LEFTOVERS="$(grep -rIl --exclude-dir=.git --exclude-dir=.build \
    --exclude-dir=.opencode --exclude-dir=.cursor --exclude-dir=.claude \
    --exclude-dir=.grok \
    --exclude=rename.sh --exclude=FINALIZE.md --exclude=CLAUDE.md --exclude=NOTICE \
    -e 'GradleLens' -e 'com.ethancooke' -e 'ethancooke/GradleLens' . || true)"
if [[ -n "$LEFTOVERS" ]]; then
    err "template markers survived the rebrand in:"
    echo "$LEFTOVERS"
    exit 1
fi

log "strip-scaffolding.sh \"$NEW_NAME\" (simulating setup.sh's scaffolding removal)"
Scripts/strip-scaffolding.sh "$NEW_NAME"

log "Asserting no operational file still references removed scaffolding"
REMOVED_PATTERNS=(
    'Scripts/test-rename.sh'
    'Scripts/rename.sh'
    'Scripts/finalize.sh'
    'Scripts/setup.sh'
    'Scripts/strip-scaffolding.sh'
    'docs/FINALIZE.md'
    'INSTRUCTIONS.md'
    '.github/workflows/rebrand-smoke.yml'
    'This is a TEMPLATE'
)

DANGLING=""
for pattern in "${REMOVED_PATTERNS[@]}"; do
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        DANGLING+="$f (matches: $pattern)"$'\n'
    done < <(grep -rIl --exclude-dir=.git --exclude-dir=.build --exclude-dir=.swiftpm \
        "$pattern" . 2>/dev/null || true)
done

if [[ -n "$DANGLING" ]]; then
    err "dangling references to removed scaffolding:"
    printf '%s' "$DANGLING" | sort -u
    exit 1
fi

log "swift build && swift test on the rebranded, stripped project"
swift build
swift test

echo
log "Smoke test passed: rename + finalize + strip produce a building, tested $NEW_NAME."