#!/usr/bin/env bash
#
# Remove the template's finalize scaffolding and rewrite the artifacts that reference it, leaving a
# clean app repo. This is the single source of truth for post-finalize cleanup:
#   - Scripts/setup.sh calls it (when the user opts to remove scaffolding), and
#   - Scripts/test-rename.sh calls it, then asserts no operational file still points at a removed
#     one — so a broken reference (e.g. a CI job calling a deleted script) can't ship again.
#
# Run AFTER rename.sh + finalize.sh. Deterministic cleanup only; prose docs (README/AGENTS) are
# tidied by the AI during finalization (see docs/FINALIZE.md).
#
# Usage: Scripts/strip-scaffolding.sh "<AppName>"
#
set -euo pipefail

APP="${1:?usage: Scripts/strip-scaffolding.sh <AppName>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# 1. Slim CLAUDE.md — the template's is about finalizing; that's done now.
log "Rewriting CLAUDE.md as ongoing project instructions"
cat > CLAUDE.md <<CLAUDE
# CLAUDE.md

Guidance for Claude Code working on **$APP**.

- Build/test commands, Swift 6 conventions, and the layout cheat sheet: [AGENTS.md](AGENTS.md).
- How to add features (recipes + anti-patterns): [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
- Product/design decisions (privacy-first, least privilege, safe-by-default): [docs/PRINCIPLES.md](docs/PRINCIPLES.md).

Run \`Scripts/verify.sh\` (build + release build + tests) before finishing a task.
CLAUDE

# 2. Strip the "this is a template / run rename.sh" banner from Package.swift.
log "Cleaning the Package.swift header"
sed -i '' \
    -e 's| app template\.| app.|' \
    -e '/^\/\/ This is a TEMPLATE: clone, then run/d' \
    -e '/^\/\/ every target, module, and bundle identifier in one step\.$/d' \
    -e '/^\/\/$/d' \
    Package.swift

# 3. Scrub allow-list entries for the smoke-test script from the agent configs.
log "Scrubbing removed-script entries from agent configs"
for cfg in opencode.json .claude/settings.json; do
    [[ -f "$cfg" ]] || continue
    sed -i '' '/test-rename\.sh/d' "$cfg"
    if command -v python3 >/dev/null 2>&1; then
        python3 -m json.tool "$cfg" >/dev/null \
            || { echo "ERROR: $cfg became invalid JSON after scrubbing" >&2; exit 1; }
    fi
done

# 4. Slim agent docs — drop the finalize workflow; keep ongoing conventions.
log "Rewriting AGENTS.md as ongoing project instructions"
cat > AGENTS.md <<AGENTS
# AGENTS.md — guidance for AI coding agents (opencode, etc.)

## Project

$APP is a **native macOS app** (Apple Silicon, macOS 14+). Swift 6 strict concurrency.
SwiftUI-first. Swift Package Manager layout.

## Commands

- Build (debug): \`swift build\`
- Build (release): \`swift build -c release\`
- Run the GUI: \`swift run $APP\`
- Run all tests: \`swift test\`
- Run a single suite: \`swift test --filter ${APP}CoreTests\`
- Open in Xcode: \`xed .\`
- Verify (build + release build + test, quiet): \`Scripts/verify.sh\` (\`--quick\` skips the release build)
- Maintenance audit (deprecations, stale CI/actions, toolchain drift): \`Scripts/check-updates.sh\` (see [\`docs/MAINTAINING.md\`](docs/MAINTAINING.md))
- Add a permission (Info.plist + entitlement, from a baked-in table): \`Scripts/add-permission.sh <permission> "<reason>"\` (\`--list\` shows slugs)
- Format Swift (optional, not a gate): \`Scripts/format.sh\` (\`--lint\` to check only)
- Ad-hoc release build: \`bash Scripts/release.sh\`

The only hard gate is the Swift 6 compiler in strict concurrency mode (\`swift build\`) — there is no
lint gate. Formatting via \`Scripts/format.sh\` (toolchain \`swift format\`, config \`.swift-format\`) is
available but optional and not enforced by CI. Always ensure \`swift build\` and \`swift test\` pass
before finishing a task.

## Conventions

- **Swift 6 strict concurrency**: prefer \`actor\` for mutable state; make model types \`Sendable\`
  structs/enums. No global mutable state. The app target defaults to \`@MainActor\` isolation
  (Xcode 26 / Swift 6.2); \`${APP}Core\` stays nonisolated.
- **UI uses the \`@Observable\` macro** (macOS 14+) — not \`ObservableObject\`/\`@Published\`.
- **No comments in source unless they explain non-obvious *why*.** No emoji in source.
- **Keep the core UI-agnostic**: \`${APP}Core\` must not import \`SwiftUI\`/\`AppKit\`. UI lives only
  in the \`$APP\` executable target.
- Match the density and idiom of the surrounding code.
- **Adding a feature?** See [\`docs/DEVELOPMENT.md\`](docs/DEVELOPMENT.md) for where things go, worked
  recipes (model / service / screen / dependency / permission / test), the definition of done, and
  the anti-patterns to avoid.
- **Product/design decisions** (privacy, permissions, networking, persistence, destructive actions)
  follow the compass in [\`docs/PRINCIPLES.md\`](docs/PRINCIPLES.md): privacy-first, offline-by-default,
  least privilege, safe-by-default. Cross a default only deliberately, minimally, and with disclosed consent.

## Layout cheat sheet

- \`Sources/$APP\` — \`@main\` SwiftUI app + views + \`@Observable\` view model + app delegate.
- \`Sources/${APP}Core\` — UI-agnostic models + actor-isolated services (no \`SwiftUI\`/\`AppKit\`).
- \`Tests/${APP}CoreTests\` — Swift Testing suites for the core library.
- \`Tests/${APP}Tests\` — Swift Testing suites for the app target (e.g. the \`@MainActor\` view model).
- \`Resources/\` — \`Info.plist\`, \`Entitlements.plist\`, app icon for the hand-assembled \`.app\`.
- \`Scripts/\` — \`add-permission.sh\` (Info.plist + entitlement from a table), \`verify.sh\`
  (quiet build+test gate), \`format.sh\` (optional Swift formatting), \`check-updates.sh\`
  (maintenance audit), and \`release.sh\` (distributable build).
- \`docs/\` — architecture, development (recipes), releasing, getting started, maintaining, principles (design compass).

## Distribution

The shipped app is **non-sandboxed + hardened runtime**, signed with a Developer ID and notarized
for direct (non-App-Store) distribution. \`Scripts/release.sh\` assembles the \`.app\` from the SPM
release binary, signs it, optionally notarizes + staples, and packages a \`.dmg\`/\`.zip\`. It degrades
to ad-hoc signing when no credentials are set. See [\`docs/RELEASING.md\`](docs/RELEASING.md).

## When extending

- Add SPM dependencies in \`Package.swift\` and list their licenses in \`NOTICE\`.
- Add new library targets beside \`${APP}Core\` and keep them UI-agnostic.
- Add usage-description keys to \`Resources/Info.plist\` for any permissioned API (camera, mic,
  location, etc.) and the matching entitlements in \`Resources/Entitlements.plist\`.
- If you target the App Store instead of direct distribution, enable App Sandbox in
  \`Entitlements.plist\` and drop the notarization step from the release pipeline.
AGENTS

# 5. Replace the template README with a minimal app README (prose can be expanded later).
log "Rewriting README.md as a minimal app README"
README_DESC="$(sed -n '3p' README.md 2>/dev/null || true)"
[[ -z "$README_DESC" || "$README_DESC" == *template* ]] && README_DESC="A native macOS app."
cat > README.md <<README
# $APP

$README_DESC

[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](#building-from-source)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-orange?logo=apple)](#building-from-source)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)](Package.swift)

---

## Screenshot

_Drop a screenshot or GIF of your app here:_

<!-- ![$APP](docs/screenshot.png) -->

---

## Building from source

Requires an Apple Silicon Mac, macOS 14+, and Xcode 26+ (Swift 6.2 toolchain).

\`\`\`bash
swift build            # debug
swift build -c release # release
swift test             # unit tests
swift run $APP         # launch the GUI (CLI-built; not a .app bundle)
xed .                  # open in Xcode
\`\`\`

To produce a distributable, signed, notarized \`.app\`/\`.dmg\`, run
[\`Scripts/release.sh\`](Scripts/release.sh) — see [\`docs/RELEASING.md\`](docs/RELEASING.md).

See [\`docs/GETTING_STARTED.md\`](docs/GETTING_STARTED.md) for a fuller walkthrough and
[\`docs/DEVELOPMENT.md\`](docs/DEVELOPMENT.md) for feature recipes.

## License

[Apache License 2.0](LICENSE).
README

# 6. Trim the clone-and-rebrand walkthrough — finalization is done.
log "Rewriting docs/GETTING_STARTED.md for an app repo"
cat > docs/GETTING_STARTED.md <<GETTING
# Getting started

A fast walkthrough for building and running **$APP**.

## Requirements

- **Apple Silicon** Mac (arm64).
- **macOS 14 Sonoma+**.
- **Xcode 26+** (Swift 6.2 toolchain).

## 1. Build & run

\`\`\`bash
swift build          # build all targets (debug)
swift test           # run the unit tests
swift run $APP       # launch the GUI
\`\`\`

Open in Xcode:

\`\`\`bash
xed .
\`\`\`

> **Note:** \`swift run\` launches the SwiftUI app as a bare executable (not a \`.app\` bundle). The
> \`AppDelegate\` sets a regular activation policy so the window comes to the front. To produce a
> real, signed, distributable \`.app\`, use the release script below.

## 2. Write your app

- Replace the sample \`Greeting\` model and \`GreetingService\` actor in
  \`Sources/${APP}Core/\` with your real domain types.
- Replace \`ContentView\` and \`AppViewModel\` in \`Sources/$APP/\` with your UI.
- Add \`NS*UsageDescription\` keys to \`Resources/Info.plist\` for any permissioned API (camera, mic,
  location, …) and the matching entitlements in \`Resources/Entitlements.plist\`.
- Add SPM dependencies in \`Package.swift\` and list their licenses in \`NOTICE\`.
- Add more library targets beside \`${APP}Core\` for larger subsystems; keep them UI-agnostic.

See [\`ARCHITECTURE.md\`](ARCHITECTURE.md) for the layering rules and [\`AGENTS.md\`](../AGENTS.md) for
the conventions (Swift 6 strict concurrency, \`@Observable\`, no comments in source).

## 3. Release

\`\`\`bash
# ad-hoc (local testing only — Gatekeeper blocks it elsewhere):
bash Scripts/release.sh

# signed + notarized + stapled (distributable):
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \\
NOTARY_KEYCHAIN_PROFILE="myapp-notary" \\
bash Scripts/release.sh
\`\`\`

Artifacts land in \`dist/\` (\`$APP-<version>.dmg\` + \`.zip\` + checksums). For CI release setup and
the full signing/notarization guide, see [\`RELEASING.md\`](RELEASING.md).
GETTING

# 7. Repoint comments that still name the removed FINALIZE.md workflow doc.
log "Scrubbing FINALIZE.md references from surviving scripts and docs"
sed -i '' 's|table from docs/FINALIZE\.md, ||' Scripts/add-permission.sh
sed -i '' \
    -e 's|^# Maintaining the template|# Maintaining '"$APP"'|' \
    -e 's|How to keep .* current|How to keep '"$APP"' current|' \
    -e 's|the template still reflects|the project still reflects|' \
    docs/MAINTAINING.md

# 8. Remove the finalize-only files (this script last — nothing runs after).
log "Removing finalize scaffolding — $APP is now a clean app repo"
rm -rf .opencode .cursor .grok
rm -f \
    docs/FINALIZE.md INSTRUCTIONS.md \
    .github/workflows/rebrand-smoke.yml \
    Scripts/rename.sh Scripts/finalize.sh Scripts/setup.sh Scripts/test-rename.sh \
    Scripts/strip-scaffolding.sh
