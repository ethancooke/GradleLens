# Getting started

A fast walkthrough for building and running **GradleLens**.

## Requirements

- **Apple Silicon** Mac (arm64).
- **macOS 14 Sonoma+**.
- **Xcode 26+** (Swift 6.2 toolchain).

## 1. Build & run

```bash
swift build          # build all targets (debug)
swift test           # run the unit tests
swift run GradleLens # launch the GUI
```

Open in Xcode:

```bash
xed .
```

> **Note:** `swift run` launches the SwiftUI app as a bare executable (not a `.app` bundle). The
> `AppDelegate` sets a regular activation policy so the window comes to the front. To produce a
> real, signed, distributable `.app`, use the release script below.

## 2. Use it

1. On first launch, GradleLens imports Gradle projects from Android Studio /
   IntelliJ recent-project lists if any exist.
2. **Open** a project root (a folder with `settings.gradle(.kts)` or
   `build.gradle(.kts)`), or **Scan** a parent folder.
3. Select a project. GradleLens indexes `build/reports/profile/profile-*.html`
   into the local SQLite history.
4. Select a build to see phases, a slowest-task timeline, and the task table.
5. The inspector shows git status, modules, and the local build cache.

If a project has no profile reports yet:

```bash
cd /path/to/project
./gradlew --profile <tasks>
```

Then click **Refresh** in GradleLens (⌘R).

History is stored at `~/Library/Application Support/GradleLens/history.sqlite`.
Removing a project from the sidebar deletes only the index entry, not the project
on disk.

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the layering rules and [`AGENTS.md`](../AGENTS.md) for
the conventions (Swift 6 strict concurrency, `@Observable`, no comments in source).

## 3. Release

```bash
# ad-hoc (local testing only — Gatekeeper blocks it elsewhere):
bash Scripts/release.sh

# signed + notarized + stapled (distributable):
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_KEYCHAIN_PROFILE="gradlelens-notary" \
bash Scripts/release.sh
```

Artifacts land in `dist/` (`GradleLens-<version>.dmg` + `.zip` + checksums). For CI release setup and
the full signing/notarization guide, see [`RELEASING.md`](RELEASING.md).
