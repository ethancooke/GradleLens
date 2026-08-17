# Releasing GradleLens

GradleLens is built from a SwiftPM package (no `.xcodeproj`). [`Scripts/release.sh`](../Scripts/release.sh)
builds the release binary, assembles `GradleLens.app`, signs it, optionally notarizes + staples it,
and packages a `.dmg` and `.zip` with SHA-256 checksums. The same script runs locally and in CI
([`.github/workflows/release.yml`](../.github/workflows/release.yml)).

## Signing posture

The shipped app is **non-sandboxed + hardened runtime**, signed for **direct (non-App-Store)
distribution**. Notarization requires the hardened runtime, not the sandbox, so a non-sandboxed app
notarizes fine. It is signed with [`Resources/Entitlements.plist`](../Resources/Entitlements.plist)
(intentionally minimal — a bare empty `<dict>`). Add entitlements only as your app needs them.

> **Keep `Entitlements.plist` free of XML comments.** `codesign`'s entitlements parser
> (`AMFIUnserializeXML`) rejects `<!-- -->` comments with a syntax error, so the file must contain
> only the plist itself. Put guidance in this file (or `AGENTS.md`), not in the plist.

The script **degrades gracefully**: with no signing identity it ad-hoc signs (runs locally,
Gatekeeper-blocked elsewhere); with a Developer ID identity + notary credentials it produces a
fully notarized, stapled, distributable build.

## Prerequisites (for a distributable build)

- An **Apple Developer Program** membership.
- A **Developer ID Application** certificate installed in your login keychain
  (Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates ▸ + ▸ Developer ID Application, or the
  Apple Developer portal). Find its identity string with:
  ```bash
  security find-identity -v -p codesigning
  # e.g. "Developer ID Application: Your Name (TEAMID)"
  ```
- Notarization credentials — an **app-specific password** (appleid.apple.com ▸ Sign-In & Security
  ▸ App-Specific Passwords). Store them once as a `notarytool` keychain profile:
  ```bash
  xcrun notarytool store-credentials apptemplate-notary \
    --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
  ```

## Local release

```bash
# Ad-hoc (quick local build; not distributable):
bash Scripts/release.sh

# Fully signed + notarized + stapled:
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_KEYCHAIN_PROFILE="apptemplate-notary" \
bash Scripts/release.sh
```

Artifacts land in `dist/`:

```
GradleLens-<version>.dmg   GradleLens-<version>.dmg.sha256
GradleLens-<version>.zip   GradleLens-<version>.zip.sha256
```

Verify a notarized build:

```bash
spctl --assess --type execute -vv dist/GradleLens.app   # should say: accepted, source=Notarized Developer ID
xcrun stapler validate dist/GradleLens-<version>.dmg
```

Useful env vars: `VERSION` (marketing version → `CFBundleShortVersionString`), `BUILD` (build
number → `CFBundleVersion`), `SKIP_TESTS=1` (skip `swift test`), and `NOTARY_APPLE_ID` /
`NOTARY_TEAM_ID` / `NOTARY_PASSWORD` instead of the keychain profile. `VERSION`/`BUILD` are stamped
into the bundle's `Info.plist`; the source `Info.plist` is left untouched.

## CI release (GitHub Actions)

The `Release` workflow runs on a `v*` tag push (or manual dispatch) and uploads a **draft**
GitHub release with the `.dmg` / `.zip` and their checksums. Signing is **opt-in**:

1. Add a repository **variable** `SIGNING_ENABLED` = `true`
   (Settings ▸ Secrets and variables ▸ Actions ▸ Variables).
2. Add these repository **secrets**:
   | Secret | What it is |
   |---|---|
   | `MACOS_CERT_P12_BASE64` | Base64 of your Developer ID Application cert + key, exported from Keychain as a `.p12`: `base64 -i DeveloperID.p12 \| pbcopy` |
   | `MACOS_CERT_PASSWORD` | Password you set when exporting the `.p12` |
   | `NOTARY_APPLE_ID` | Apple ID email for notarization |
   | `NOTARY_TEAM_ID` | Your Developer Team ID |
   | `NOTARY_PASSWORD` | App-specific password |
3. Cut a release:
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```
   CI derives the version from the tag: `CFBundleShortVersionString` becomes the tag minus its
   leading `v` (so `v0.1.0` → `0.1.0`), and `CFBundleVersion` becomes the commit count (a monotonic
   build number). No manual `Info.plist` bump is needed for tagged releases.
4. Review the draft release the workflow creates, then publish it.

Without `SIGNING_ENABLED=true`, the workflow still runs and produces an **ad-hoc** `.dmg`/`.zip`
(handy for smoke-testing the pipeline) — just not a distributable, notarized build.

## Versioning

For **CI releases**, just tag `v<version>` — the workflow stamps the version (from the tag) and
build number (commit count) into the bundle automatically (see the CI section above).

For **local release builds**, the version defaults to `CFBundleShortVersionString` /
`CFBundleVersion` in [`Resources/Info.plist`](../Resources/Info.plist); override per build with the
`VERSION` / `BUILD` env vars. Bump the `Info.plist` values when you want a new local default.

## App Store instead of direct distribution

1. Enable App Sandbox in `Resources/Entitlements.plist` (`com.apple.security.app-sandbox: true`)
   and add any sandbox-compatible entitlements your app needs.
2. Use an Xcode-generated archive / App Store signing instead of `release.sh`'s Developer ID +
   notarization path (the App Store signs for you; notarization is not used).
