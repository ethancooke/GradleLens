# Design principles — the decision compass

Guidance for anyone — human or AI — building an app on this template. When a design or
implementation choice is ambiguous, this is how to decide. The goal is trustworthy software:
**privacy, user control, safety, transparency, and minimal footprint come before features,
convenience, or performance.**

## How to use this

These principles describe the app's **default posture**. Read them as a compass, not a cage:

- The **ends** — privacy, safety, transparency, user control — are non-negotiable.
- The **defaults** that serve them (offline-only, no network, no persistence beyond what's needed)
  are strong starting points, not prohibitions.
- When a feature genuinely requires crossing a default — a weather app needs the network, a sync
  feature needs a server — **don't abandon the principle; satisfy it.** Make the capability
  **opt-in and off by default**, disclose exactly *what* data, *why*, and *to where*, request the
  **least** data for the shortest time, keep it **revocable**, and **document it**. A crossing is a
  conscious, visible decision — never a silent one.

When two options are otherwise close, pick the more conservative, more user-respecting one.

## 1. Privacy & offline by default

- No telemetry, analytics, crash reporting, or network calls unless the app's purpose requires them.
  Core functionality should work fully offline.
- Process user data **locally**. Nothing leaves the device without specific, informed, revocable
  consent for a stated purpose.
- **In practice:** keep [`PRIVACY.md`](../PRIVACY.md) honest — update it the moment you add network
  access or data collection. The template's [`Entitlements.plist`](../Resources/Entitlements.plist)
  ships with no network entitlement; adding one (under App Sandbox) is a deliberate, disclosed step.

## 2. Minimal footprint

- Persist only what the app needs to function. Prefer in-memory work; don't write to disk what you
  can recompute or hold in RAM.
- When you do persist, use the standard macOS locations via `FileManager` (Application Support for
  user data, Caches for regenerable data, the temporary directory for scratch). **Clean up
  temporary files** on completion, error, and exit. Leave nothing scattered on the user's system.

## 3. Safety & explicit consent for destructive actions

- Never delete, overwrite, move, or destructively modify a user's files, data, or settings without
  **review of the affected items** and **affirmative confirmation**. Offer per-item selection where
  practical.
- The default removal action is **recoverable** — move to Trash (`FileManager.trashItem`), not
  unlink. Permanent/secure deletion is a separate, explicit choice with a clear irreversibility
  warning.
- Before any operation that scans, imports, exports, modifies, or removes user data, explain in
  plain language **what will happen and any realistic risks** — then act.

## 4. Least privilege & graceful degradation

- Request the **minimum** permissions the feature needs. Add each one deliberately via
  [`Scripts/add-permission.sh`](../Scripts/add-permission.sh) with a plain-language usage
  description that states *why* — never a vague placeholder.
- If a permission is denied, **degrade gracefully**: adapt the UI, keep the rest of the app working,
  explain what's unavailable and how to enable it. Never crash or punish the user for saying no.

## 5. Native experience & accessibility

- Follow Apple's **Human Interface Guidelines**. Prefer native SwiftUI/AppKit components and
  platform-standard affordances over custom reinventions.
- Build **accessibility in from the start**, not as a retrofit: VoiceOver labels, full keyboard
  navigation, Dynamic Type / scaling, sufficient contrast, and meaningful semantics.

## 6. Open, auditable & secure

- The template ships as open source (Apache 2.0) and assumes **auditable** behavior: no hidden
  capabilities, no undisclosed data flows. If you build a closed-source app, the transparency and
  no-hidden-behavior standards still apply.
- Keep dependencies **license-clean and privacy-respecting**, and list each one in
  [`NOTICE`](../NOTICE). Fewer dependencies = smaller attack surface.
- **Security by design:** validate input, fail closed, prefer secure defaults, and keep the
  hardened-runtime posture the template ships with (see [`RELEASING.md`](RELEASING.md)).

## The decision rule

> For any design choice, default to the most conservative, user-respecting option. Privacy, safety,
> transparency, offline capability, and minimal footprint take priority. If a feature needs to cross
> one of these defaults, do it openly, minimally, and with the user's informed, revocable consent —
> and write it down. Re-check each proposal against these principles before shipping it.
