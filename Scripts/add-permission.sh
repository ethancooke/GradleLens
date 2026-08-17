#!/usr/bin/env bash
#
# Add a macOS permission to the app: writes the NS*UsageDescription into Resources/Info.plist
# and the matching entitlement into Resources/Entitlements.plist, deterministically.
#
# The permission -> plist-key mapping is the table from docs/FINALIZE.md, baked in here so an
# AI (or a human) never has to re-derive it, and so Entitlements.plist stays comment-free
# (codesign's entitlements parser rejects XML comments).
#
# Usage:
#   Scripts/add-permission.sh <permission> ["one-sentence reason"]
#   Scripts/add-permission.sh --list
#
#   <permission>  one of the slugs listed by --list (e.g. camera, microphone, location).
#   reason        the usage-description sentence — REQUIRED for permissions that have an
#                 NS*UsageDescription key; ignored for entitlement-only permissions.
#
# Idempotent: re-running updates the reason and leaves a single entitlement entry.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO="$ROOT/Resources/Info.plist"
ENT="$ROOT/Resources/Entitlements.plist"
PB=/usr/libexec/PlistBuddy

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
err() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }

# permission slug -> "NS_KEY|ENTITLEMENT_KEY|note"  (empty NS_KEY = entitlement-only)
mapping_for() {
    case "$1" in
        camera)        echo "NSCameraUsageDescription|com.apple.security.device.camera|";;
        microphone)    echo "NSMicrophoneUsageDescription|com.apple.security.device.audio-input|";;
        system-audio)  echo "NSAudioCaptureUsageDescription|com.apple.security.device.audio-input|";;
        location)      echo "NSLocationUsageDescription|com.apple.security.personal-information.location|";;
        contacts)      echo "NSContactsUsageDescription|com.apple.security.personal-information.addressbook|";;
        calendars)     echo "NSCalendarsUsageDescription|com.apple.security.personal-information.calendars|";;
        reminders)     echo "NSRemindersUsageDescription|com.apple.security.personal-information.reminders|";;
        photos)        echo "NSPhotoLibraryUsageDescription|com.apple.security.assets.photos.read-write|sandbox";;
        bluetooth)     echo "NSBluetoothAlwaysUsageDescription|com.apple.security.device.bluetooth|";;
        usb)           echo "|com.apple.security.device.usb|";;
        files-read-write) echo "|com.apple.security.files.user-selected.read-write|";;
        network-client)   echo "|com.apple.security.network.client|sandbox";;
        *) return 1;;
    esac
}

PERMISSIONS="camera microphone system-audio location contacts calendars reminders photos bluetooth usb files-read-write network-client"

usage() {
    echo "usage: Scripts/add-permission.sh <permission> [\"one-sentence reason\"]"
    echo "       Scripts/add-permission.sh --list"
}

list() {
    printf '%-18s %-34s %s\n' "PERMISSION" "Info.plist key" "Entitlement"
    for p in $PERMISSIONS; do
        IFS='|' read -r ns ent note <<< "$(mapping_for "$p")"
        printf '%-18s %-34s %s%s\n' "$p" "${ns:-—}" "$ent" "${note:+  ($note-only)}"
    done
}

# --- Parse args ------------------------------------------------------------------------------
[[ $# -eq 0 ]] && { usage; exit 2; }
case "$1" in
    -h|--help) usage; exit 0;;
    --list)    list; exit 0;;
esac

PERM="$1"; REASON="${2:-}"
if ! MAP="$(mapping_for "$PERM")"; then
    err "unknown permission: \"$PERM\""
    echo "Run 'Scripts/add-permission.sh --list' to see valid permissions." >&2
    exit 1
fi
IFS='|' read -r NS_KEY ENT_KEY NOTE <<< "$MAP"

[[ -f "$INFO" ]] || { err "$INFO not found — run from the repo root."; exit 1; }
[[ -f "$ENT"  ]] || { err "$ENT not found — run from the repo root."; exit 1; }

# Guard: codesign rejects XML comments in the entitlements file. Refuse to touch a commented one.
if grep -q '<!--' "$ENT"; then
    err "Resources/Entitlements.plist contains an XML comment. codesign's parser rejects comments;"
    err "remove them before adding entitlements (put guidance in docs/RELEASING.md, not the plist)."
    exit 1
fi

# --- Info.plist: NS*UsageDescription --------------------------------------------------------
if [[ -n "$NS_KEY" ]]; then
    if [[ -z "$REASON" ]]; then
        err "\"$PERM\" needs a usage-description reason."
        echo "  e.g. Scripts/add-permission.sh $PERM \"MyApp uses the camera to scan documents.\"" >&2
        exit 2
    fi
    if "$PB" -c "Add :$NS_KEY string $REASON" "$INFO" 2>/dev/null; then
        log "Info.plist: added $NS_KEY"
    else
        "$PB" -c "Set :$NS_KEY $REASON" "$INFO"
        log "Info.plist: updated $NS_KEY"
    fi
fi

# --- Entitlements.plist: entitlement key -----------------------------------------------------
if "$PB" -c "Add :$ENT_KEY bool true" "$ENT" 2>/dev/null; then
    log "Entitlements.plist: added $ENT_KEY"
else
    "$PB" -c "Set :$ENT_KEY true" "$ENT"
    log "Entitlements.plist: already present ($ENT_KEY)"
fi

[[ -n "$NOTE" ]] && echo "  NOTE: $ENT_KEY is only meaningful under the App Sandbox ($NOTE distribution)."

echo
log "Done. Review with: git diff Resources/"
