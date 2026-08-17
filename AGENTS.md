# AGENTS.md — guidance for AI coding agents (opencode, etc.)

## Project

GradleLens is a **local-only macOS developer tool** (Apple Silicon, macOS 14+) that inspects
Gradle builds, the local build cache, project structure, and git status on this machine. Swift 6
strict concurrency. SwiftUI-first. Swift Package Manager layout. No network, no server.

## Commands

- Build (debug): `swift build`
- Build (release): `swift build -c release`
- Run the GUI: `swift run GradleLens`
- Run all tests: `swift test`
- Run a single suite: `swift test --filter GradleLensCoreTests`
- Open in Xcode: `xed .`
- Verify (build + release build + test, quiet): `Scripts/verify.sh` (`--quick` skips the release build)
- Maintenance audit (deprecations, stale CI/actions, toolchain drift): `Scripts/check-updates.sh` (see [`docs/MAINTAINING.md`](docs/MAINTAINING.md))
- Add a permission (Info.plist + entitlement, from a baked-in table): `Scripts/add-permission.sh <permission> "<reason>"` (`--list` shows slugs)
- Format Swift (optional, not a gate): `Scripts/format.sh` (`--lint` to check only)
- Ad-hoc release build: `bash Scripts/release.sh`

The only hard gate is the Swift 6 compiler in strict concurrency mode (`swift build`) — there is no
lint gate. Formatting via `Scripts/format.sh` (toolchain `swift format`, config `.swift-format`) is
available but optional and not enforced by CI. Always ensure `swift build` and `swift test` pass
before finishing a task.

## Conventions

- **Swift 6 strict concurrency**: prefer `actor` for mutable state; make model types `Sendable`
  structs/enums. No global mutable state. The app target defaults to `@MainActor` isolation
  (Xcode 26 / Swift 6.2); `GradleLensCore` stays nonisolated.
- **UI uses the `@Observable` macro** (macOS 14+) — not `ObservableObject`/`@Published`.
- **No comments in source unless they explain non-obvious *why*.** No emoji in source.
- **Keep the core UI-agnostic**: `GradleLensCore` must not import `SwiftUI`/`AppKit`. UI lives only
  in the `GradleLens` executable target.
- Match the density and idiom of the surrounding code.
- **Adding a feature?** See [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) for where things go, worked
  recipes (model / service / screen / dependency / permission / test), the definition of done, and
  the anti-patterns to avoid.
- **Product/design decisions** (privacy, permissions, networking, persistence, destructive actions)
  follow the compass in [`docs/PRINCIPLES.md`](docs/PRINCIPLES.md): privacy-first, offline-by-default,
  least privilege, safe-by-default. Cross a default only deliberately, minimally, and with disclosed consent.

## Layout cheat sheet

- `Sources/GradleLens` — `@main` SwiftUI app + views + `@Observable` view model + app delegate.
- `Sources/GradleLensCore` — UI-agnostic models + actor-isolated services (no `SwiftUI`/`AppKit`).
- `Tests/GradleLensCoreTests` — Swift Testing suites for the core library.
- `Tests/GradleLensTests` — Swift Testing suites for the app target (e.g. the `@MainActor` view model).
- `Resources/` — `Info.plist`, `Entitlements.plist`, app icon for the hand-assembled `.app`.
- `Scripts/` — `add-permission.sh` (Info.plist + entitlement from a table), `verify.sh`
  (quiet build+test gate), `format.sh` (optional Swift formatting), `check-updates.sh`
  (maintenance audit), and `release.sh` (distributable build).
- `docs/` — architecture, development (recipes), releasing, getting started, maintaining, principles (design compass).

## Distribution

The shipped app is **non-sandboxed + hardened runtime**, signed with a Developer ID and notarized
for direct (non-App-Store) distribution. `Scripts/release.sh` assembles the `.app` from the SPM
release binary, signs it, optionally notarizes + staples, and packages a `.dmg`/`.zip`. It degrades
to ad-hoc signing when no credentials are set. See [`docs/RELEASING.md`](docs/RELEASING.md).

## When extending

- Add SPM dependencies in `Package.swift` and list their licenses in `NOTICE`.
- Add new library targets beside `GradleLensCore` and keep them UI-agnostic.
- Add usage-description keys to `Resources/Info.plist` for any permissioned API (camera, mic,
  location, etc.) and the matching entitlements in `Resources/Entitlements.plist`.
- If you target the App Store instead of direct distribution, enable App Sandbox in
  `Entitlements.plist` and drop the notarization step from the release pipeline.
