#!/usr/bin/env bash
#
# Builds, signs, notarizes, and packages the app into a .dmg and .zip.
#
# This is a SwiftPM package (no .xcodeproj), so we build the release binary with
# `swift build -c release` and assemble the .app bundle by hand, then sign / notarize / staple
# / package. The shipped app is NON-SANDBOXED + hardened runtime (notarizable for direct
# distribution outside the App Store). See docs/RELEASING.md.
#
# Signing is OPT-IN and degrades gracefully:
#   - No SIGN_IDENTITY (default "-")  -> ad-hoc signed. Builds and runs locally, but Gatekeeper
#                                        blocks it on other Macs. Notarization is skipped.
#   - SIGN_IDENTITY set + notary creds -> Developer ID signed, hardened runtime, notarized,
#                                         stapled, and Gatekeeper-assessed.
#
# Environment:
#   SIGN_IDENTITY            Developer ID Application identity, or "-" for ad-hoc (default "-").
#   NOTARY_KEYCHAIN_PROFILE  `notarytool store-credentials` profile (preferred for local use).
#   NOTARY_APPLE_ID          Apple ID for notarization (alternative to the profile).
#   NOTARY_TEAM_ID           Developer Team ID (with NOTARY_APPLE_ID).
#   NOTARY_PASSWORD          App-specific password (with NOTARY_APPLE_ID).
#   VERSION                  Override the marketing version (default: Info.plist CFBundleShortVersionString).
#                            Stamped into the bundle as CFBundleShortVersionString.
#   BUILD                    Override the build number (default: Info.plist CFBundleVersion).
#                            Stamped into the bundle as CFBundleVersion; should increase per build.
#   SKIP_TESTS               Set to 1 to skip `swift test`.
#   REQUIRE_NOTARY           Set to 1 to fail if the build is not Developer ID signed + notarized.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="GradleLens"
EXECUTABLE="GradleLens"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="-"
fi
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
ENTITLEMENTS="$ROOT/Resources/Entitlements.plist"
ICON="$ROOT/Resources/AppIcon.icns"

VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/Resources/Info.plist")}"
BUILD="${BUILD:-$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$ROOT/Resources/Info.plist")}"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
ZIP="$DIST/$APP_NAME-$VERSION.zip"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# --- Notarization helper (profile takes precedence over Apple ID credentials) ----------------
notarize() {
    local artifact="$1"
    if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
        xcrun notarytool submit "$artifact" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
    elif [[ -n "${NOTARY_APPLE_ID:-}" && -n "${NOTARY_TEAM_ID:-}" && -n "${NOTARY_PASSWORD:-}" ]]; then
        xcrun notarytool submit "$artifact" \
            --apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" \
            --password "$NOTARY_PASSWORD" --wait
    else
        return 1
    fi
}
have_notary_creds() {
    [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]] || \
    [[ -n "${NOTARY_APPLE_ID:-}" && -n "${NOTARY_TEAM_ID:-}" && -n "${NOTARY_PASSWORD:-}" ]]
}

# --- Build -----------------------------------------------------------------------------------
if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
    log "Running tests"
    swift test
fi

log "Building release ($APP_NAME $VERSION)"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/$EXECUTABLE"

log "Verifying the binary is arm64-only"
file "$BIN" | grep -q 'arm64' || { echo "ERROR: $EXECUTABLE is not arm64"; exit 1; }
file "$BIN" | grep -q 'x86_64' && { echo "ERROR: $EXECUTABLE contains an x86_64 slice"; exit 1; }

# --- Assemble the .app bundle ----------------------------------------------------------------
log "Assembling $APP_NAME.app"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXECUTABLE"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# Stamp the version/build into the bundle (the source Info.plist stays untouched).
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"
if [[ -f "$ICON" ]]; then
    cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
else
    echo "NOTE: $ICON not found — the bundle will have no app icon."
fi

# Copy SwiftPM resource bundles into Contents/Resources.
# Do NOT place them at the .app root — codesign rejects unsealed root contents.
# SwiftPM's generated Bundle.module looks at Bundle.main.bundleURL/<Package>_<Target>.bundle
# (the .app root) and fatalErrors on a miss, so production code must not use Bundle.module.
# Drop the capture script as a loose Resources file for Bundle.main.url(forResource:).
shopt -s nullglob
BUNDLES=("$BIN_DIR"/*.bundle)
shopt -u nullglob
if (( ${#BUNDLES[@]} )); then
    log "Copying ${#BUNDLES[@]} resource bundle(s) into the app"
    for b in "${BUNDLES[@]}"; do
        cp -R "$b" "$APP/Contents/Resources/"
        if [[ -f "$b/gradlelens.init.gradle.kts" ]]; then
            cp "$b/gradlelens.init.gradle.kts" "$APP/Contents/Resources/"
        fi
    done
fi
if [[ ! -f "$APP/Contents/Resources/gradlelens.init.gradle.kts" ]]; then
    echo "ERROR: capture script missing from $APP/Contents/Resources"
    exit 1
fi

xattr -cr "$APP"

# --- Sign ------------------------------------------------------------------------------------
# Secure timestamps are REQUIRED for notarization but unsupported for ad-hoc signatures.
TIMESTAMP_FLAG=""
[[ "$SIGN_IDENTITY" != "-" ]] && TIMESTAMP_FLAG="--timestamp"

log "Signing with identity: $SIGN_IDENTITY (hardened runtime)"
codesign --force --options runtime $TIMESTAMP_FLAG \
    --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

# --- Notarize the app (only when really signed + creds present) ------------------------------
NOTARIZED=0
if [[ "$SIGN_IDENTITY" != "-" ]] && have_notary_creds; then
    log "Notarizing the app"
    APPZIP="$DIST/$APP_NAME-notarize.zip"
    ditto -c -k --keepParent "$APP" "$APPZIP"
    notarize "$APPZIP"
    rm -f "$APPZIP"
    log "Stapling the app"
    xcrun stapler staple "$APP"
    spctl --assess --type execute -vv "$APP" || true
    NOTARIZED=1
fi

# --- Package: .dmg + .zip --------------------------------------------------------------------
log "Building $(basename "$DMG")"
DMG_STAGE="$DIST/dmg"
mkdir -p "$DMG_STAGE"
cp -R "$APP" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$DMG_STAGE/"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$DMG_STAGE"

if [[ "$NOTARIZED" == "1" ]]; then
    log "Signing + notarizing the .dmg"
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
    notarize "$DMG"
    xcrun stapler staple "$DMG"
fi

log "Building $(basename "$ZIP")"
ditto -c -k --keepParent "$APP" "$ZIP"

# --- Checksums -------------------------------------------------------------------------------
( cd "$DIST" && shasum -a 256 "$(basename "$DMG")" | tee "$(basename "$DMG").sha256" )
( cd "$DIST" && shasum -a 256 "$(basename "$ZIP")" | tee "$(basename "$ZIP").sha256" )

echo
log "Done. Artifacts in dist/:"
ls -1 "$DIST"
if [[ "${REQUIRE_NOTARY:-0}" == "1" && "$NOTARIZED" != "1" ]]; then
    echo
    echo "ERROR: REQUIRE_NOTARY=1 but the build was not notarized."
    echo "       Set SIGN_IDENTITY to a Developer ID Application identity and provide"
    echo "       NOTARY_KEYCHAIN_PROFILE or NOTARY_APPLE_ID + NOTARY_TEAM_ID + NOTARY_PASSWORD."
    exit 1
fi
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo
    echo "NOTE: ad-hoc signed — fine on this Mac, but Gatekeeper will block it elsewhere."
    echo "      Set SIGN_IDENTITY + notarization credentials for a distributable build (see docs/RELEASING.md)."
elif [[ "$NOTARIZED" != "1" ]]; then
    echo
    echo "NOTE: Developer ID signed but NOT notarized (no notary credentials provided)."
    echo "      Gatekeeper may still warn on first launch. See docs/RELEASING.md."
fi
