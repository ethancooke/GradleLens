# Privacy

**GradleLens collects nothing and uploads nothing.** It is a fully offline, local-only
developer tool. It has no accounts, no telemetry, no analytics, no crash reporting,
and it makes **no network connections**.

## What the app reads (all on this Mac)

- Gradle project files you open or that appear in Android Studio / IntelliJ recent-project
  lists (`settings.gradle`, `settings.gradle.kts`, `build.gradle`, `build.gradle.kts`,
  wrapper properties)
- Existing `--profile` HTML reports under `build/reports/profile/`
- Local Gradle build-cache metadata under `~/.gradle/caches/build-cache-1`
  (or `$GRADLE_USER_HOME/caches/build-cache-1`)
- Local git metadata for the selected project (`branch`, `HEAD`, dirty file count,
  recent commit subjects) via `/usr/bin/git`. GradleLens never runs `fetch`, `pull`,
  `push`, or any other network git command.

## What the app stores

Build-history metadata is written to a SQLite database at:

```
~/Library/Application Support/GradleLens/history.sqlite
```

That file stays on your Mac. Removing a project from the sidebar deletes only the
index entry, not the project on disk.

The last-selected project path is stored in `UserDefaults` on this Mac.

## What the app does not do

- No URLSession, no telemetry endpoints, no crash reporters
- No remote build cache
- No Develocity / Build Scan upload
- No invocation of `./gradlew` (which could download a Gradle distribution)

The hardened-runtime entitlements file ships **empty**: no network client
entitlement, no sandbox file-access prompts. The app is distributed as a
non-sandboxed Developer ID binary so it can read the local Gradle home and
projects you choose.

## Third-party SDKs

None. GradleLens links only Apple system frameworks and the system SQLite library.
See [`NOTICE`](NOTICE).
