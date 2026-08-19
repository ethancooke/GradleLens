# GradleLens

<p align="center">
  <img src="Resources/AppIcon-source-1024.png" width="128" height="128" alt="GradleLens">
</p>

A **local-only** native macOS app for inspecting Gradle builds on your machine: `--profile` timelines, task outcomes, the local build cache, project structure, and git context.

Nothing is uploaded. There is no server. GradleLens never runs `./gradlew`.

[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](#install)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-orange?logo=apple)](#install)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)](Package.swift)
[![Build](https://github.com/ethancooke/GradleLens/actions/workflows/build.yml/badge.svg)](https://github.com/ethancooke/GradleLens/actions/workflows/build.yml)

---

## Install

Requires an **Apple Silicon** Mac running **macOS 14** or later.

1. Download the latest notarized `.dmg` from [Releases](https://github.com/ethancooke/GradleLens/releases).
2. Open it and drag **GradleLens** to Applications.
3. Launch GradleLens. Gatekeeper should accept it (Developer ID + notarized).

## What it does

GradleLens reads artifacts that are already on disk and indexes them in a local SQLite database.

- **Project picker** — open a Gradle root, scan a folder, or import Android Studio / IntelliJ recent projects
- **Local build history** — indexed from `build/reports/profile/profile-*.html` (`gradle --profile`)
- **Build detail** — phase breakdown, slowest-task timeline, searchable task table
- **Compare** — duration deltas, cache flips, tasks that appeared or disappeared
- **Trends** — chart one Gradle command over 24 hours through all history, or a custom date range
- **Local build cache** — size, entry count, newest/oldest, largest blobs in `~/.gradle/caches/build-cache-1`
- **Project structure** — modules and included builds from `settings.gradle` / `settings.gradle.kts`
- **Git context** — current branch, dirty status, recent commits (local `git` only; never fetch/push)

## What it is not

- Not Develocity, and not a Gradle Build Scan viewer
- Not a CI visibility product
- It does not run Gradle, invoke `./gradlew`, or download a distribution
- It does not talk to a remote cache or the network
- Intel Macs are not supported

## Use it

Generate a normal Gradle profile, then open the project:

```bash
./gradlew --profile assemble
```

In GradleLens, **Open** the project root (or **Scan** a parent folder) and select a build.

No extra Gradle plugin or init script is required. Reports land in `build/reports/profile/`.

On first launch you can optionally turn on **richer capture** (also in Settings). That only writes extra local JSON when you run Gradle yourself. The app works the same without it.

## Building from source

Apple Silicon, macOS 14+, Xcode 26+ (Swift 6.2 toolchain).

```bash
git clone https://github.com/ethancooke/GradleLens.git
cd GradleLens
swift build            # debug
swift test             # unit tests
swift run GradleLens   # launch the GUI (not a .app bundle)
xed .                  # open in Xcode
```

To produce a signed, notarized `.app` / `.dmg`, see [`docs/RELEASING.md`](docs/RELEASING.md).

Walkthrough: [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md). Feature recipes: [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## How it stays local

- Reads project files, `--profile` HTML, `~/.gradle/caches/build-cache-1`, wrapper properties, and local git metadata
- Stores history in `~/Library/Application Support/GradleLens/history.sqlite`
- Adds no network entitlement and makes no `URLSession` calls
- Links only Apple system frameworks and the system SQLite library

See [`PRIVACY.md`](PRIVACY.md).

## Releases

Pushing a `v*` tag runs GitHub Actions: it builds, Developer ID-signs, notarizes, and opens a **draft** GitHub release. Publish the draft after you review it.

Maintainer setup: [`docs/RELEASING.md`](docs/RELEASING.md).

## License

[Apache License 2.0](LICENSE) — use, modify, and share freely, including in commercial products; include the license and NOTICE. Contributions are under the same terms ([`CONTRIBUTING.md`](CONTRIBUTING.md)). Security reports: [`SECURITY.md`](SECURITY.md).
