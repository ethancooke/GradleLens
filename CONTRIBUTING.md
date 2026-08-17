# Contributing to GradleLens

Thanks for your interest. GradleLens is a local-only macOS developer tool for inspecting Gradle
builds. Changes should make the app more correct, more useful for local observability, or easier
to extend — without adding network access or a server.

## Code of Conduct

Be respectful, be specific, and argue from evidence (a failing test, a build error, a spec
citation) rather than preference. Assume good faith and leave the project more correct than you
found it.

## Getting started

Requirements:

- **Apple Silicon** Mac (arm64).
- **macOS 14 Sonoma+**.
- **Xcode 26+** (Swift 6.2 toolchain).

```bash
git clone https://github.com/ethancooke/GradleLens.git
cd GradleLens
swift build          # build all targets
swift test           # run the unit tests
swift run GradleLens # launch the GUI
```

Before writing code, skim [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (layering + concurrency
model) and [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md).

## Quality gates (pre-PR checklist)

Run these locally before opening a PR — CI runs the same:

```bash
swift build                 # must compile clean under Swift 6 strict concurrency
swift build -c release      # release config must also compile clean
swift test                  # all suites must pass
```

There is no linter; the Swift 6 compiler in strict-concurrency mode is the gate.

## Branching & PRs

- Work on short-lived feature branches off `main`; never commit directly to `main`.
- Give the PR a descriptive title and explain **what changed and why**.
- Keep PRs focused. Open an issue first for anything non-trivial or architecture-touching.

## Commit messages

Write imperative, specific subjects that describe the effect, e.g.:

```
Add camera entitlement + capture usage description
Drop macOS 13 fallback now that @Observable is required
Fix release.sh arm64 check for arm64e slices
```

## Style & conventions

- **Swift 6 strict concurrency.** Prefer `actor` for mutable state; make model types `Sendable`
  value types. No global mutable state.
- **No comments unless they explain non-obvious *why*.** No emoji in source. Match the density and
  idiom of the surrounding code.
- **UI uses the `@Observable` macro** (macOS 14+), not `ObservableObject`/`@Published`.
- **Keep the core UI-agnostic.** `GradleLensCore` must not import `SwiftUI`/`AppKit`. UI lives only
  in the `GradleLens` executable target.

## Attribution

If you adapt a technique or code from another project, cite the source in the PR and, where
appropriate, in [`NOTICE`](NOTICE).

By contributing, you agree your contributions are licensed under the project's
[Apache 2.0 license](LICENSE).
