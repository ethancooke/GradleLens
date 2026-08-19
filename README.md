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

Use it by generating a normal Gradle profile, then opening the project:

```bash
./gradlew --profile assemble
swift run GradleLens -- --open /path/to/project
```

No extra Gradle plugin or init script is required. Reports land in `build/reports/profile/`. GradleLens never invokes the wrapper.

On first launch you can optionally turn on **richer capture** (also in Settings). That only writes extra local reports when you run Gradle; the app works the same without it.

Select two builds and choose **Compare** (or Compare with previous) to see duration deltas, cache flips, and tasks that appeared or disappeared.

**Trends** groups the same Gradle command and charts duration and outcomes over a range you pick (24 hours through all history, or custom dates).

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

## Releases

Local first, GitHub Actions second. Details: [`docs/RELEASING.md`](docs/RELEASING.md).

```bash
# 1. Ad-hoc .app + .dmg on this Mac (Gatekeeper-blocked elsewhere)
bash Scripts/release.sh

# 2. After a Developer ID cert + notarytool profile exist:
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_KEYCHAIN_PROFILE="gradlelens-notary" \
bash Scripts/release.sh

# 3. Then enable signing secrets on the repo and:
git tag v0.1.0 && git push origin v0.1.0
```

CI already drafts a GitHub release from `v*` tags. Leave `SIGNING_ENABLED` unset until local notarization works.

---

## License

[Apache License 2.0](LICENSE) — use, modify, and share freely, including in commercial products;
include the license and NOTICE, and Apache’s patent grant applies. Contributions are under the
same terms ([`CONTRIBUTING.md`](CONTRIBUTING.md)). Security reports: [`SECURITY.md`](SECURITY.md).
