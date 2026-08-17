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
- **Project structure** — modules and included builds from `settings.gradle` / `settings.gradle.kts`
- **Git context** — current branch, dirty status, recent commits (local `git` only; never fetch/push)

To capture richer builds, run Gradle with `--profile`:

```bash
./gradlew --profile assemble
```

Reports land in `build/reports/profile/`. GradleLens never invokes the Gradle wrapper, so it cannot trigger a distribution download.

---

## Building from source

Requires an Apple Silicon Mac, macOS 14+, and Xcode 26+ (Swift 6.2 toolchain).

```bash
swift build            # debug
swift build -c release # release
swift test             # unit tests
swift run GradleLens   # launch the GUI (CLI-built; not a .app bundle)
xed .                  # open in Xcode
```

To produce a distributable, signed, notarized `.app`/`.dmg`, run
[`Scripts/release.sh`](Scripts/release.sh) — see [`docs/RELEASING.md`](docs/RELEASING.md).

See [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md) for a fuller walkthrough and
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) for feature recipes.

---

## How it stays local

- Reads project files, `--profile` HTML, `~/.gradle/caches/build-cache-1`, wrapper properties, and local git metadata
- Stores build history in `~/Library/Application Support/GradleLens/history.sqlite`
- Adds no network entitlement and makes no URLSession calls
- Uses the system SQLite library (no third-party packages)

See [`PRIVACY.md`](PRIVACY.md).

---

## License

[Apache License 2.0](LICENSE).
