# GradleLens Architecture

A native macOS (Apple Silicon, macOS 14+) app. Swift 6 strict concurrency. SwiftUI-first
UI; AppKit only where SwiftUI is insufficient (app delegate, file panels, Finder reveal).

GradleLens is **offline by default**. Domain services read local files and run local
`git` commands. They never open a network connection.

## Layers

```
┌──────────────────────────────────────────────────────────────────────────┐
│ GradleLens  (executable — SwiftUI + AppKit)                              │
│   GradleLensApp · ContentView                                            │
│   Views: sidebar, build list, detail, timeline, inspector                │
│   ViewModels: AppViewModel (@Observable, @MainActor)                     │
│   Support: AppDelegate, FolderPicker, WorkspaceOpener                    │
└────────────────────────────────▲─────────────────────────────────────────┘
                                 │  async calls + Sendable value types
┌────────────────────────────────┴─────────────────────────────────────────┐
│ GradleLensCore  (library — UI-agnostic, no SwiftUI/AppKit)               │
│   Models:  GradleProject, BuildRecord, ProfileReport, GitContext, …      │
│   Actors:  BuildHistoryStore, ProjectDiscoveryService, BuildIndexer,     │
│            BuildCacheInspector, GitService                               │
│   Parsers: ProfileReportParser, ProjectStructureReader,                  │
│            IDERecentProjectsReader, GradleProjectDetector                │
│   Persistence: system SQLite 3 (Application Support/GradleLens)          │
└──────────────────────────────────────────────────────────────────────────┘
```

The split is load-bearing:

- **`GradleLensCore`** has no UI dependencies, so it is unit-testable in isolation.
  All file-system, git, Gradle, cache, and SQLite work lives here.
- **`GradleLens`** is the only target that imports `SwiftUI`/`AppKit`. It injects
  core actors into `AppViewModel` and renders the results.

## Why I/O services are actors

Approachable Concurrency (`NonisolatedNonsendingByDefault`) makes a `nonisolated async`
method inherit the caller's actor. If file I/O lived on a plain struct, a `@MainActor`
view model would run that I/O on the main thread.

Stateful and I/O-bound services are therefore `actor`s. Awaiting them from the view
model hops off the main actor. Stateless parsers (`ProfileReportParser`,
`ProjectStructureReader`) are structs and are only called from those actors.

## Local data sources (v1)

| Feature | Source | Notes |
|---|---|---|
| Recent projects | App SQLite + Android Studio / IntelliJ `recentProjects.xml` | `$USER_HOME$` expanded locally |
| Build history | `<project>/build/reports/profile/profile-*.html` plus `build/reports/gradlelens/scan-*.json` | HTML is the fallback; scan JSON is preferred when both exist |
| Build compare | Two `BuildDetail` values | Duration / phase / task deltas, cache flips, appeared/disappeared |
| Trends | Same command key + date range over local history | Duration chart, outcome strip, median / p95 / fail rate |
| Cache overview | `$GRADLE_USER_HOME/caches/build-cache-1` (default `~/.gradle/…`) | Metadata only; blobs are not parsed |
| Project structure | `settings.gradle(.kts)` + module `build.gradle(.kts)` | No Tooling API / no `./gradlew` |
| Gradle version | `gradle/wrapper/gradle-wrapper.properties` | Parsed as text; never downloaded |
| Git | `/usr/bin/git` (`rev-parse`, `status`, `log`) | `GIT_TERMINAL_PROMPT=0`; no fetch/push |

The Gradle Tooling API is a JVM library. Invoking it (or the wrapper) is avoided
so the app cannot trigger a distribution download. Richer capture comes from the
optional init script at `Sources/GradleLensCore/Resources/gradlelens.init.gradle.kts`
(`Scripts/install-capture.sh` copies it to `~/.gradle/init.d`). It writes local
JSON only. The indexer pairs a scan with a `--profile` HTML file when their
start times are within 30 seconds.

## Persistence

`BuildHistoryStore` owns a single SQLite connection (system `libsqlite3`, no SPM
dependency) at:

```
~/Library/Application Support/GradleLens/history.sqlite
```

Tables: `projects` (keyed by absolute path) and `builds` (unique on `profile_path`
so re-indexing is idempotent). Removing a project from the list deletes only the
index row (cascade); user files are never touched.

## Concurrency model

- **The app target defaults to `@MainActor` isolation** (Swift 6.2 `defaultIsolation`).
  `GradleLensCore` stays nonisolated.
- **Approachable Concurrency** is on for every target.
- **Actors own mutable state** (the SQLite handle, in-flight I/O).
- **Models are `Sendable` value types.**
- **View models are `@MainActor @Observable`.** Dependencies are injected via `init`.
- **No global mutable state.** No singletons.

## Distribution shape

The shipped app is **non-sandboxed + hardened runtime**, signed with a Developer ID
and notarized for direct distribution. `Scripts/release.sh` builds the release
binary, hand-assembles the `.app`, signs it, and packages a `.dmg`/`.zip`. See
[RELEASING.md](RELEASING.md).

Non-sandboxing is required for v1 so the app can read `~/.gradle` and arbitrary
project trees the user opens, without a network entitlement.

## Extension points

- Richer local scan files from a companion Gradle plugin (write JSON next to
  profile reports; extend `BuildIndexer` to ingest them).
- File-system watchers for live profile import.
- Configuration-cache / build-operation traces as additional local artifacts.
- Extra library targets beside `GradleLensCore` if a subsystem grows; keep them
  UI-agnostic.
