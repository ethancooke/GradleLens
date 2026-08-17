# Security Policy

GradleLens is a local-only macOS app. It reads Gradle artifacts and git metadata on the
machine it runs on and stores an index in Application Support. It does not listen on the
network and does not upload data.

## Reporting a vulnerability

Please use GitHub's **private vulnerability reporting** (the repository's **Security** tab →
**"Report a vulnerability"**) rather than opening a public issue. This keeps details private until
a fix is available.

## Scope

- Weaknesses in [`Scripts/release.sh`](Scripts/release.sh) or
  [`.github/workflows/release.yml`](.github/workflows/release.yml) that could produce a mis-signed
  or mis-notarized bundle.
- Incorrect entitlements or hardened-runtime configuration that weakens the shipping posture.
- Path-handling or SQLite issues that could read or write outside the user's intended projects
  or the Application Support database.
- Anything that would cause GradleLens to contact the network or invoke the Gradle wrapper
  (which can download a distribution).

## Out of scope

- Security of Gradle itself, of projects GradleLens inspects, or of the local git repository.
- Issues that require the user to open a malicious project file they already have on disk,
  unless GradleLens mishandles that file (for example by executing it).

## Supported versions

As a small project there is no guaranteed response time, and only the **latest** commit is
supported with fixes.
