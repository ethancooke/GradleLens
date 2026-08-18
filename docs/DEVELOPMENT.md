# Development recipes

How to add to GradleLens so the result matches the architecture on the first try. Pairs with
[`ARCHITECTURE.md`](ARCHITECTURE.md) (the why) and [`AGENTS.md`](../AGENTS.md) (the conventions).
For product/design judgment, see [`PRINCIPLES.md`](PRINCIPLES.md). Do not add network access.

## Where things go

| You're adding… | Put it in… | Notes |
|---|---|---|
| A domain type / data model | `Sources/GradleLensCore/Models/` | `Sendable` `struct`/`enum`. No `SwiftUI`/`AppKit`. |
| Business logic / stateful service | `Sources/GradleLensCore/Services/` | `actor` if it owns mutable state; otherwise a plain type. |
| A view / screen | `Sources/GradleLens/` (or a `Views/` subfolder) | SwiftUI. May import `AppKit` only where SwiftUI can't. |
| A view model | `Sources/GradleLens/ViewModels/` | `@MainActor @Observable final class`, service injected via `init`. |
| App-lifecycle / AppKit glue | `Sources/GradleLens/Support/` | e.g. the app delegate. |
| Core logic tests | `Tests/GradleLensCoreTests/` | Swift Testing. |
| View-model / app-target tests | `Tests/GradleLensTests/` | Swift Testing; `@MainActor` where the type is. |

**The load-bearing rule:** `GradleLensCore` never imports `SwiftUI`/`AppKit`. Logic that would
force such an import belongs in the app target, not the core.

## Recipes

### Add a model
Create a `Sendable` value type in `Core/Models/`. It crosses actor boundaries freely.

### Add a service
Create it in `Core/Services/`. Use an `actor` when it holds mutable state (Swift 6 then guarantees
no data races); use a plain `struct`/`enum` when it's stateless. Expose `async` methods.

### Add a screen and its view model
1. `@MainActor @Observable final class FooViewModel` in `ViewModels/`, taking its dependencies via
   `init(service: …)` (see `AppViewModel` for the pattern — inject, don't hardcode). The app
   target already defaults to `@MainActor`; keep the annotation so the isolation is obvious.
2. A SwiftUI `FooView` that holds `@State private var viewModel = FooViewModel()` and calls into it.
3. Never mutate UI state off the main actor; bridge async core results through the view model.

### Add a dependency to a view model
Inject it through `init` and default it
(`init(store: BuildHistoryStore? = nil, …)`) so production stays terse and tests can pass an
in-memory store or a stub.

### Add an SPM package dependency
Add it under `dependencies:` in `Package.swift`, then to the target's `dependencies:`. Commit the
updated `Package.resolved`, and list the dependency + its license in [`NOTICE`](../NOTICE). Fewer
dependencies = smaller attack surface (see PRINCIPLES §6).

### Add a system permission
Run `Scripts/add-permission.sh <permission> "<why>"` — it writes the `NS*UsageDescription` and the
matching entitlement from a baked-in table. **Do not hand-edit the plists** (the script guards
against the codesign no-comments footgun). Then disclose it in [`PRIVACY.md`](../PRIVACY.md) if it
touches user data or the network.

### Add tests
Mirror the target under `Tests/`. Use Swift Testing (`@Test`, `#expect`, `@Suite`). For
`@MainActor` types, mark the suite/test `@MainActor`.

## Definition of done

- `Scripts/verify.sh` passes (debug build + release build + tests, clean under Swift 6 strict
  concurrency).
- New behavior has a test.
- Any new permission/network/persistence is reflected in `PRIVACY.md` and follows `PRINCIPLES.md`
  (opt-in, disclosed, least data).
- Optional: `Scripts/format.sh` for consistent formatting (not a gate).

## Anti-patterns (don't)

- **Don't import `SwiftUI`/`AppKit` in `GradleLensCore`.** Keep the core UI-agnostic.
- **Don't use `ObservableObject`/`@Published`.** Use the `@Observable` macro (macOS 14+).
- **Don't introduce global mutable state or singletons.** Inject dependencies.
- **Don't hand-edit `Info.plist`/`Entitlements.plist` for permissions.** Use `add-permission.sh`.
- **Don't put XML comments in `Entitlements.plist`.** `codesign` rejects them.
- **Don't add network calls, telemetry, or invoke `./gradlew`.** GradleLens is offline-only
  (PRINCIPLES §1). Persistence belongs in Application Support and must stay local. The optional
  capture init script is user-installed and still writes only local files.
- **Don't leave the build with warnings.** Fix deprecations as they appear.
- **Don't add comments that restate the code.** Comment only non-obvious *why*.
