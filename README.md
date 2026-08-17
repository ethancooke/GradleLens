# GradleLens

A **local-only** native macOS developer tool that gives you deep visibility into Gradle builds on your machine: profile timelines, task outcomes, the local build cache, project structure, and git context. Nothing is uploaded. There is no server.

[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](#building-from-source)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-orange?logo=apple)](#building-from-source)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)](Package.swift)

---

## What it does

GradleLens is for individual developer machines and large monorepos. It reads artifacts that are already on disk and indexes them in a local SQLite database.

- **Project picker** — open a Gradle root, scan a folder, or import Android Studio / IntelliJ recent projects
- **Local build history** — indexed from `build/reports/profile/profile-*.html` (`gradle --profile`)
- **Build detail** — phase breakdown, slowest-task timeline, searchable task table
- **Local build cache** — size, entry count, newest/oldest, largest blobs in `~/.gradle/caches/build-cache-1`
- **Project structure** — modules and included builds from `settings.gradle` / `settings.gradle.kts`, plus inferred tasks from build files
- **Git context** — current branch, dirty status, recent commits (local `git` only; never fetch/push)

### Out of scope (v1)

No network access, no remote build cache, no CI visibility, no Develocity / Build Scan upload, no AI features, no multi-build-system support.

To capture richer builds, run Gradle with `--profile`:

```bash
./gradlew --profile assemble
```

Reports land in `build/reports/profile/`. GradleLens never invokes the Gradle wrapper, so it cannot trigger a distribution download.

---

## Run it

Requires an Apple Silicon Mac, macOS 14+, and Xcode 26+ (Swift 6.2 toolchain).

```bash
swift build
swift test
swift run GradleLens
```

Open in Xcode with `xed .`.

`swift run` launches the SwiftUI app as a bare executable. The app delegate sets a regular activation policy so the window comes forward. For a signed `.app` / `.dmg`, use [`Scripts/release.sh`](Scripts/release.sh) — see [`docs/RELEASING.md`](docs/RELEASING.md).

---

## How it stays local

- Reads project files, `--profile` HTML, `~/.gradle/caches/build-cache-1`, wrapper properties, and local git metadata
- Stores build history in `~/Library/Application Support/GradleLens/history.sqlite`
- Adds no network entitlement and makes no URLSession calls
- Uses the system SQLite library (no third-party packages)

See [`PRIVACY.md`](PRIVACY.md).

---

## Architecture

Two SwiftPM targets, following the AppleFactory conventions:

| Target | Role |
|---|---|
| **GradleLensCore** | Models, parsers, Gradle/cache/git inspection, SQLite persistence. No SwiftUI/AppKit. |
| **GradleLens** | SwiftUI views, `@Observable` view models, AppKit file panels. |

Details: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). Design compass: [`docs/PRINCIPLES.md`](docs/PRINCIPLES.md).

---

## Repository layout

```
GradleLens/
├── Package.swift
├── README.md  PRIVACY.md  SECURITY.md  CONTRIBUTING.md  AGENTS.md
├── LICENSE  NOTICE
├── Resources/                   # Info.plist, entitlements, app icon
├── Scripts/                     # verify, release (sign+notarize), format, …
├── Sources/
│   ├── GradleLens/              # @main SwiftUI app
│   └── GradleLensCore/          # UI-agnostic domain library
├── Tests/
│   ├── GradleLensCoreTests/
│   └── GradleLensTests/
└── docs/                        # architecture, development, releasing
```

The sign + notarize pipeline, CI (`.github/workflows/`), and community files come from the [AppleFactory](https://github.com/ethancooke/AppleFactory) template and are kept intact.

---

## Building from source

```bash
swift build            # debug
swift build -c release # release
swift test             # unit tests
swift run GradleLens   # launch the GUI
Scripts/verify.sh      # debug + release + tests (quiet)
```

---

## License

[Apache License 2.0](LICENSE).
