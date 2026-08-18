# Maintaining GradleLens

How to keep GradleLens current — latest toolchain, CI, dependencies, and Apple guidance.

Most version churn is **automated**: Dependabot (`.github/dependabot.yml`) opens grouped PRs for
GitHub Actions and SwiftPM major bumps weekly, and resolves minor/patch silently. This doc covers
the periodic **audit** and the **judgment calls** Dependabot can't make.

## Cadence

Run a maintenance pass **each Xcode major release** (or quarterly, whichever comes first), and
whenever CI starts warning. It's a 15-minute pass, not a rewrite.

## 1. Run the audit (mechanical)

```bash
Scripts/check-updates.sh   # report-only; never mutates the repo
```

It surfaces what Dependabot can't see: SDK **deprecation warnings**, the **CI runner label**, the
**toolchain/deployment target** in use, whether pinned Actions have a newer **major**, and build
health. Act on each flagged item using the sections below, then re-verify:

```bash
Scripts/verify.sh          # build + release build + test
```

## 2. Merge Dependabot PRs

Review its grouped Actions/SwiftPM PRs; merge once CI is green. Major bumps may have breaking
notes — skim the action's release notes before merging.

## 3. Judgment calls (do these by hand or with an AI)

- **CI runner image** (`runs-on: macos-NN` in `.github/workflows/*`). Dependabot never bumps this.
  Move to the next image once it's the stable default (see
  [actions/runner-images](https://github.com/actions/runner-images)); confirm CI stays green — a
  newer image ships a newer Xcode/Swift, which can introduce new warnings or deprecations.
- **Swift tools version & language mode** (`swift-tools-version`, `.swiftLanguageMode(.v6)` in
  `Package.swift`). Raise with new Swift majors, and when a new tools-version unlocks settings the
  project should adopt (6.2 added `.defaultIsolation` and `.strictMemorySafety`). Watch for
  tightened strict-concurrency diagnostics that a newer compiler may surface. The app target
  already matches Xcode 26's Approachable Concurrency defaults; don't flip those off without a
  reason.
- **macOS deployment target** (`.macOS(.v14)`). Raising it **drops support for older macOS** — a
  deliberate product decision, not routine maintenance. Only raise it to adopt an API you actually
  need, and update `LSMinimumSystemVersion` in `Resources/Info.plist` and the README badge to match.
- **Deprecations.** Fix each one the audit/build reports by moving to Apple's recommended
  replacement (e.g. an AppKit call deprecated in a new SDK). Keep the build warning-free.
- **Apple guidance drift.** Periodically confirm the project still reflects current best practice:
  the `@Observable` macro over `ObservableObject`, Swift Testing over XCTest, and any changes to
  **notarization / hardened-runtime / signing** requirements (`notarytool`, entitlements, App
  Sandbox rules) that affect `Scripts/release.sh` and `docs/RELEASING.md`. Sources: Apple developer
  release notes and WWDC sessions.

## 4. Commit

Keep maintenance changes in a focused branch/PR (e.g. `chore: bump CI to macos-NN, Swift 6.x`) with
a one-line note on what moved and why. Re-run `Scripts/verify.sh` before opening it.
