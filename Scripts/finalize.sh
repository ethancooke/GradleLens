#!/usr/bin/env bash
#
# Post-rename finalization for a freshly cloned AppleFactory template.
# Run AFTER Scripts/rename.sh. Does the mechanical substitutions rename.sh
# doesn't cover: GitHub repo URL, App Store category, copyright holder, and
# (optionally) App Sandbox for App Store distribution.
#
# Usage:
#   Scripts/finalize.sh \
#     --app "MyApp" \
#     --repo "acme/my-app" \
#     --category "public.app-category.productivity" \
#     [--copyright "Acme Inc."] \
#     [--distribution direct|appstore]
#
#   --app         The new app name (what rename.sh produced). Used to scope the
#                 copyright substitution ("<App> contributors" -> "<holder>").
#   --repo        Your GitHub "owner/repo" (e.g. "acme/my-app"). Replaces the
#                 template's "ethancooke/GradleLens" in URLs and links.
#   --category    An LSApplicationCategoryType value (see docs/FINALIZE.md).
#   --copyright   Optional. Replaces "<App> contributors" in LICENSE, NOTICE,
#                 and Info.plist with this holder. Omit to keep "<App> contributors".
#   --distribution  Optional. "direct" (default, Developer ID + notarize) or
#                 "appstore" (enables App Sandbox in Entitlements.plist).
#
set -euo pipefail

APP="" ; REPO="" ; CATEGORY="" ; COPYRIGHT="" ; DISTRIBUTION="direct"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)         APP="$2"; shift 2;;
        --repo)        REPO="$2"; shift 2;;
        --category)    CATEGORY="$2"; shift 2;;
        --copyright)   COPYRIGHT="$2"; shift 2;;
        --distribution) DISTRIBUTION="$2"; shift 2;;
        -h|--help)
            sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2;;
    esac
done

if [[ -z "$APP" || -z "$REPO" || -z "$CATEGORY" ]]; then
    echo "ERROR: --app, --repo, and --category are required." >&2
    echo "See: Scripts/finalize.sh --help" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f "Resources/Info.plist" ]]; then
    echo "ERROR: Resources/Info.plist not found — run this from the repo root after rename.sh." >&2
    exit 1
fi

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# Text files to edit, excluding tool/build dirs.
edit_files() {
    grep -rlI --exclude-dir=.git --exclude-dir=.build --exclude-dir=.swiftpm \
            --exclude-dir=.opencode --exclude-dir=.cursor --exclude-dir=.claude \
            "$1" . || true
}

# --- 1. GitHub repo URL --------------------------------------------------------------------
log "Replacing repo URL: ethancooke/GradleLens -> $REPO"
while IFS= read -r f; do
    sed -i '' "s|ethancooke/GradleLens|$REPO|g" "$f"
done < <(edit_files "ethancooke/GradleLens")

# --- 2. App Store category -----------------------------------------------------------------
log "Setting LSApplicationCategoryType -> $CATEGORY"
sed -i '' "s|public.app-category.utilities|$CATEGORY|g" Resources/Info.plist

# --- 3. Copyright holder (optional) --------------------------------------------------------
if [[ -n "$COPYRIGHT" ]]; then
    # Strip trailing periods — the source text already supplies them (e.g. "contributors. Apache").
    COPYRIGHT="${COPYRIGHT%.}"
    log "Setting copyright holder -> $COPYRIGHT"
    sed -i '' "s|$APP contributors|$COPYRIGHT|g" LICENSE NOTICE Resources/Info.plist 2>/dev/null || true
fi

# --- 4. Distribution: App Sandbox for App Store --------------------------------------------
if [[ "$DISTRIBUTION" == "appstore" ]]; then
    log "Enabling App Sandbox (App Store distribution)"
    /usr/libexec/PlistBuddy -c "Add :com.apple.security.app-sandbox bool true" \
        Resources/Entitlements.plist 2>/dev/null || true
    echo "  NOTE: App Sandbox is now ON. For App Store distribution, drop the notarization"
    echo "        step from the release pipeline (see docs/RELEASING.md 'App Store instead of direct distribution')."
elif [[ "$DISTRIBUTION" != "direct" ]]; then
    echo "ERROR: --distribution must be 'direct' or 'appstore' (got '$DISTRIBUTION')" >&2
    exit 2
fi

# --- 5. Bare template repo name (AppleFactory -> app name) -----------------------------------
# rename.sh only substitutes GradleLens/com.ethancooke; the human-facing repo name "AppleFactory"
# slips through into README, CONTRIBUTING, MAINTAINING, etc. Preserve NOTICE attribution.
log "Replacing bare repo name: AppleFactory -> $APP"
while IFS= read -r f; do
    case "$f" in
        ./NOTICE) continue ;;
        ./Scripts/*) continue ;;
        ./INSTRUCTIONS.md|./docs/FINALIZE.md) continue ;;
        ./.opencode/*|./.cursor/*|./.claude/*|./.grok/*) continue ;;
    esac
    sed -i '' "s|AppleFactory|$APP|g" "$f"
done < <(edit_files "AppleFactory")

echo
log "Finalization complete. Verify it builds:"
echo "  swift build && swift test"
