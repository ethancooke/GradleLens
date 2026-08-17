#!/usr/bin/env bash
#
# Rebrand the AppTemplate placeholders to a real app name.
#
# Usage:
#   Scripts/rename.sh "MyApp" "com.myapp"
#
#   arg 1: new app name (used as the Swift target/module name and the .app/.dmg name).
#          Must be a valid Swift identifier: start with a letter or underscore, then
#          letters/digits/underscores.
#   arg 2: new bundle-id prefix in reverse-DNS form (e.g. "com.mycompany"). The final
#          bundle id becomes "<prefix>.<AppName>".
#
# What it does:
#   1. Renames Sources/AppTemplate -> Sources/<NewName>, Sources/AppTemplateCore ->
#      Sources/<NewName>Core, Tests/AppTemplateCoreTests -> Tests/<NewName>CoreTests.
#   2. Renames any file whose name contains "AppTemplate".
#   3. Replaces "com.example" -> "<prefix>" and "AppTemplate" -> "<NewName>" in every text
#      file (this script is left untouched so it can be re-inspected or deleted).
#
# Review the result with `git diff` and commit. Run this ONCE, right after cloning.
#
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: Scripts/rename.sh \"NewName\" \"com.yourdomain\""
    echo "  e.g. Scripts/rename.sh \"MyApp\" \"com.myapp\""
    exit 2
fi

NEW_NAME="$1"
NEW_BUNDLE_PREFIX="$2"
OLD_NAME="AppTemplate"
OLD_BUNDLE_PREFIX="com.example"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# --- Validate inputs -------------------------------------------------------------------------
if [[ ! "$NEW_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "ERROR: app name \"$NEW_NAME\" is not a valid Swift identifier."
    echo "       Use letters, digits, and underscores; start with a letter or underscore."
    exit 1
fi
if [[ ! "$NEW_BUNDLE_PREFIX" =~ ^[A-Za-z][A-Za-z0-9.-]*$ ]]; then
    echo "ERROR: bundle-id prefix \"$NEW_BUNDLE_PREFIX\" doesn't look like reverse-DNS (e.g. com.myapp)."
    exit 1
fi
if [[ "$NEW_NAME" == "$OLD_NAME" ]]; then
    echo "Nothing to do — the new name is already \"$OLD_NAME\"."
    exit 0
fi
if [[ ! -d "Sources/$OLD_NAME" ]]; then
    echo "ERROR: Sources/$OLD_NAME not found. Has the template already been renamed?"
    exit 1
fi

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# --- 1. Rename directories -------------------------------------------------------------------
log "Renaming directories"
mv "Sources/$OLD_NAME"          "Sources/$NEW_NAME"
mv "Sources/${OLD_NAME}Core"    "Sources/${NEW_NAME}Core"
mv "Tests/${OLD_NAME}CoreTests" "Tests/${NEW_NAME}CoreTests"
# App-target test dir is optional (a user may delete it); rename it only if present.
[[ -d "Tests/${OLD_NAME}Tests" ]] && mv "Tests/${OLD_NAME}Tests" "Tests/${NEW_NAME}Tests"

# --- 2. Rename files that contain the old name in their filename -----------------------------
# Skip the AI-tool meta dirs (.opencode/.cursor/.claude/.grok) — their files reference the
# template's original "AppTemplate" name as a detection marker and must stay frozen
# (see docs/FINALIZE.md).
log "Renaming files"
while IFS= read -r -d '' f; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    newbase=${base//"$OLD_NAME"/"$NEW_NAME"}
    [[ "$base" != "$newbase" ]] && mv "$f" "$dir/$newbase"
done < <(find . -path ./.git -prune -o -path ./.build -prune -o \
              -path ./.opencode -prune -o -path ./.cursor -prune -o -path ./.claude -prune -o \
              -path ./.grok -prune -o \
              -type f -name "*$OLD_NAME*" -print0)

# --- 3. Find-replace text in all text files --------------------------------------------------
# Skip: this script, build/git dirs, and the AI-tool meta files + docs/FINALIZE.md + CLAUDE.md,
# which carry template-identity markers (AppTemplate/com.example) used to detect a fresh clone.
log "Replacing placeholders in file contents"

META_EXCLUDES=(
    --exclude-dir=.git --exclude-dir=.build --exclude-dir=.swiftpm
    --exclude-dir=.opencode --exclude-dir=.cursor --exclude-dir=.claude
    --exclude-dir=.grok
    --exclude=rename.sh --exclude=FINALIZE.md --exclude=CLAUDE.md
)

replace_in_files() {
    local old="$1" new="$2"
    local files
    files=$(grep -rlI "${META_EXCLUDES[@]}" "$old" . || true)
    [[ -z "$files" ]] && return 0
    while IFS= read -r f; do
        sed -i '' "s|$old|$new|g" "$f"
    done <<< "$files"
}

replace_in_files "$OLD_BUNDLE_PREFIX" "$NEW_BUNDLE_PREFIX"
replace_in_files "$OLD_NAME" "$NEW_NAME"

# --- Done ------------------------------------------------------------------------------------
echo
log "Rebrand complete: $OLD_NAME -> $NEW_NAME  ($OLD_BUNDLE_PREFIX -> $NEW_BUNDLE_PREFIX)"
echo "Next steps:"
echo "  swift build          # verify it compiles"
echo "  swift test           # verify tests pass"
echo "  git diff             # review the changes"
echo "  git add -A && git commit -m \"Rebrand template to $NEW_NAME\""
echo
echo "You can delete Scripts/rename.sh now, or keep it. Update NOTICE/LICENSE copyright to taste."
