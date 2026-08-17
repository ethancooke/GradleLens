#!/usr/bin/env bash
#
# One-command bootstrap: turn a freshly cloned AppleFactory template into your own app.
#
# Run this AFTER you have cloned the template and cd'd into it (see INSTRUCTIONS.md). It:
#   1. asks a few questions (app name, bundle id, description, category, distribution, copyright,
#      your GitHub owner/repo),
#   2. runs Scripts/rename.sh + Scripts/finalize.sh to rebrand everything,
#   3. verifies it builds,
#   4. (optional) removes the template scaffolding,
#   5. (optional) starts a fresh git history and pushes to YOUR repo — never the template's.
#
# Every destructive or outward-facing step is confirmed before it runs. Non-interactive callers can
# pipe answers on stdin (empty line = accept the shown default).
#
# Usage: Scripts/setup.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }

ask() {  # ask "prompt" "default" -> echoes the answer (default if empty/EOF)
    local prompt="$1" default="${2:-}" reply=""
    if [[ -n "$default" ]]; then
        printf '%s [%s]: ' "$prompt" "$default" >&2
    else
        printf '%s: ' "$prompt" >&2
    fi
    read -r reply || true
    echo "${reply:-$default}"
}

confirm() {  # confirm "prompt" -> returns 0 on yes; default No
    local reply=""
    printf '%s [y/N]: ' "$1" >&2
    read -r reply || true
    [[ "${reply:-}" =~ ^[Yy] ]]
}

# --- Guard: must be a fresh template -------------------------------------------------------------
if [[ ! -d "Sources/GradleLens" ]]; then
    err "This doesn't look like a fresh AppleFactory template (Sources/GradleLens is gone)."
    err "setup.sh is meant to run once, right after cloning."
    exit 1
fi

bold "Set up your app from the AppleFactory template"
echo "Answer a few questions. Press Enter to accept a [default]."
echo

# --- Gather answers ------------------------------------------------------------------------------
APP="$(ask 'App name (a Swift identifier, e.g. MyApp)')"
[[ -n "$APP" ]] || { err "App name is required."; exit 2; }

PREFIX="$(ask 'Bundle ID prefix (reverse-DNS, e.g. com.myco)')"
[[ -n "$PREFIX" ]] || { err "Bundle ID prefix is required."; exit 2; }

DESC="$(ask 'One-line description' "A native macOS app.")"
CATEGORY="$(ask 'App Store category (LSApplicationCategoryType)' 'public.app-category.utilities')"
DISTRIBUTION="$(ask 'Distribution: direct or appstore' 'direct')"
COPYRIGHT="$(ask 'Copyright holder' "$APP contributors")"
REPO="$(ask 'Your GitHub owner/repo (e.g. you/MyApp), or blank to set up git later' '')"

echo
bold "Summary"
printf '  App name .......... %s\n' "$APP"
printf '  Bundle id ......... %s.%s\n' "$PREFIX" "$APP"
printf '  Description ....... %s\n' "$DESC"
printf '  Category .......... %s\n' "$CATEGORY"
printf '  Distribution ...... %s\n' "$DISTRIBUTION"
printf '  Copyright ......... %s\n' "$COPYRIGHT"
printf '  GitHub repo ....... %s\n' "${REPO:-<none — git set up later>}"
echo
confirm "Proceed with these values?" || { echo "Aborted. Nothing changed."; exit 0; }

# --- Rebrand -------------------------------------------------------------------------------------
log "Rebranding ($APP, $PREFIX)"
Scripts/rename.sh "$APP" "$PREFIX"

FINALIZE_REPO="${REPO:-OWNER/$APP}"   # placeholder if the user hasn't picked a repo yet
log "Finalizing (repo=$FINALIZE_REPO, category=$CATEGORY)"
Scripts/finalize.sh \
    --app "$APP" \
    --repo "$FINALIZE_REPO" \
    --category "$CATEGORY" \
    --copyright "$COPYRIGHT" \
    --distribution "$DISTRIBUTION"

# Update the README description (H1 stays the app name via rename.sh).
if [[ -f README.md ]]; then
    log "Setting README description"
    # Replace the template's opening description line with the user's one-liner (best effort).
    /usr/bin/sed -i '' "1,15 s|^A \*\*macOS app template\*\*.*|$DESC|" README.md 2>/dev/null || true
fi

# Point CODEOWNERS at the new owner if we know it.
if [[ -n "$REPO" && -f .github/CODEOWNERS ]]; then
    OWNER="${REPO%%/*}"
    log "Setting CODEOWNERS owner to @$OWNER"
    /usr/bin/sed -i '' "s|@ethancooke|@$OWNER|g" .github/CODEOWNERS
fi

# --- Verify --------------------------------------------------------------------------------------
log "Verifying the rebranded project builds"
Scripts/verify.sh --quick

# --- Optional: remove template scaffolding -------------------------------------------------------
# Scripts/strip-scaffolding.sh is the single source of truth for cleanup: it slims CLAUDE.md, cleans
# the Package.swift header, scrubs the agent configs, and removes the finalize-only files (including
# this script). The rebrand smoke test runs the same routine, so it can't silently break.
echo
if confirm "Remove the template scaffolding and finalize this as a clean app repo? Recommended."; then
    Scripts/strip-scaffolding.sh "$APP"
    echo "  (Kept: slimmed CLAUDE.md, agent configs (.claude/, opencode.json), add-permission.sh,"
    echo "         verify.sh, check-updates.sh, format.sh, release.sh, and docs/.)"
else
    log "Keeping scaffolding. CLAUDE.md still targets finalization; run Scripts/strip-scaffolding.sh \"$APP\" to slim it later."
fi

# --- Optional: fresh git history -----------------------------------------------------------------
echo
if [[ -d .git ]] && confirm "Start a fresh git history for $APP (discards the template's history)?"; then
    log "Re-initializing git"
    rm -rf .git
    git init -q
    git add -A
    git commit -q -m "Initial commit: $APP from the AppleFactory template"
    git branch -M main
    GIT_READY=1
elif [[ ! -d .git ]]; then
    log "Initializing git"
    git init -q
    git add -A
    git commit -q -m "Initial commit: $APP from the AppleFactory template"
    git branch -M main
    GIT_READY=1
else
    GIT_READY=0
fi

# --- Optional: push to the user's GitHub repo ----------------------------------------------------
echo
if [[ "${GIT_READY:-0}" == "1" && -n "$REPO" ]]; then
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        if confirm "Create GitHub repo '$REPO' and push now?"; then
            VIS="$(ask 'Visibility: private or public' 'private')"
            log "Creating and pushing to $REPO ($VIS)"
            gh repo create "$REPO" "--$VIS" --source . --remote origin --push
        else
            echo "Skipped. When ready:  git remote add origin git@github.com:$REPO.git && git push -u origin main"
        fi
    else
        echo "gh not installed/authenticated. When ready:"
        echo "  git remote add origin git@github.com:$REPO.git && git push -u origin main"
    fi
elif [[ "${GIT_READY:-0}" == "1" ]]; then
    echo "No repo chosen. When ready, create one and:"
    echo "  git remote add origin <your-repo-url> && git push -u origin main"
fi

echo
bold "Done — $APP is ready."
echo "Next: open in Xcode (xed .) or 'swift run $APP', then start replacing the sample code."
echo "See docs/GETTING_STARTED.md and docs/PRINCIPLES.md."
