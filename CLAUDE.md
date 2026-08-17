# CLAUDE.md

Guidance for Claude Code working in this repository.

## Fresh-clone finalization

If this repo is a freshly cloned **GradleLens** template (signals: `Scripts/rename.sh` exists
**and** `Sources/AppTemplate/` still exists, or `Resources/Info.plist` contains
`com.example.AppTemplate`), follow the canonical workflow in
**[`docs/FINALIZE.md`](docs/FINALIZE.md)** to rebrand it into a real app before doing anything else.

The workflow: ask the user a few questions (app name, bundle ID, description, category,
distribution, permissions, copyright, repo URL), run `Scripts/rename.sh` + `Scripts/finalize.sh`,
make the targeted edits the scripts can't (README description, Info.plist usage descriptions,
Entitlements.plist entitlements), then verify with `swift build && swift test`. Full question list,
permission/category tables, and step-by-step in `docs/FINALIZE.md`.

If `Sources/AppTemplate/` has already been renamed away, the template is already finalized — skip
this and proceed with normal development.

## Everyday commands & conventions

See [`AGENTS.md`](AGENTS.md) for build/test commands, Swift 6 strict-concurrency conventions, the
UI-agnostic core rule, and the layout cheat sheet. When adding features, follow the recipes and
anti-patterns in [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

When making product/design decisions on an app built from this template — anything touching
privacy, permissions, networking, data persistence, or destructive actions — follow the compass in
[`docs/PRINCIPLES.md`](docs/PRINCIPLES.md) (privacy-first, offline-by-default, least privilege,
safe-by-default). Deviate from a default only deliberately, minimally, and with disclosed user consent.
