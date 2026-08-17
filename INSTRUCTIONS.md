# Start your own app from this template

A newcomer's guide: clone the template, run one script, and you have your own app in your own
GitHub repo. The whole thing takes a couple of minutes.

## Prerequisites

- An **Apple Silicon** Mac on **macOS 14 Sonoma+** with **Xcode 26+** (Swift 6.2 toolchain).
- Optional: the **GitHub CLI** (`gh`, authenticated with `gh auth login`) if you want the script to
  create and push to your GitHub repo for you.

## Step 1 — Clone the template (you do this)

Clone it into a folder named after your app, and `cd` in:

```bash
git clone https://github.com/ethancooke/GradleLens.git MyApp
cd MyApp
```

> The clone still points at the template's repository. **Step 2 replaces that** with a fresh history
> and your own remote — you never push back to the template.

## Step 2 — Run the setup script

```bash
Scripts/setup.sh
```

It asks a few questions (press Enter to accept a default):

| Question | Example | Notes |
|---|---|---|
| App name | `MyApp` | A Swift identifier — becomes the target, module, and `.app` name. |
| Bundle ID prefix | `com.myco` | Reverse-DNS. Final bundle id = `com.myco.MyApp`. |
| Description | `A native macOS notes app.` | One line; used in the README. |
| App Store category | `public.app-category.productivity` | Defaults to Utilities. |
| Distribution | `direct` or `appstore` | Direct = notarized Developer ID; App Store = sandboxed. |
| Copyright holder | `Your Name` | Defaults to `<App> contributors`. |
| GitHub `owner/repo` | `you/MyApp` | Where it will live. Leave blank to set up git later. |

Then it:

1. **Rebrands** everything (`rename.sh` + `finalize.sh`): targets, modules, bundle id, app/DMG name,
   repo URLs in the docs, category, and copyright.
2. **Verifies** the rebranded project builds and tests pass.
3. **Offers to remove the template scaffolding** (the rename/finalize/setup scripts, `FINALIZE.md`,
   and the AI entry points). Say yes for a clean repo, or no to keep them.
4. **Starts a fresh git history** — discards the template's history and makes your initial commit.
5. **Offers to create your GitHub repo and push** (if you gave an `owner/repo` and have `gh`).

Every destructive or outward-facing step asks for confirmation first — nothing happens silently.

## If you skipped the GitHub step

If you left the repo blank or don't use `gh`, the script still makes your initial commit locally.
Create a repo on GitHub, then point at it and push:

```bash
git remote add origin git@github.com:you/MyApp.git
git push -u origin main
```

Double-check the remote is yours, not the template's:

```bash
git remote -v   # should show you/MyApp
```

## After setup

- **Run it:** `swift run MyApp` (or `xed .` to open in Xcode).
- **Add a permission** when you need one: `Scripts/add-permission.sh camera "Why MyApp needs it."`
- **Start building:** see [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md) and
  [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). Product decisions follow
  [`docs/PRINCIPLES.md`](docs/PRINCIPLES.md).
- **Release later:** see [`docs/RELEASING.md`](docs/RELEASING.md).

## Prefer to let an AI do it?

Open the freshly cloned folder in Claude Code, Cursor, Grok, or opencode and say *"set up this template."*
The bundled finalize skill asks the same questions and runs the same scripts. The canonical workflow
is in [`docs/FINALIZE.md`](docs/FINALIZE.md).

## Doing it by hand instead

The script just wraps these — run them yourself if you prefer full control:

```bash
Scripts/rename.sh "MyApp" "com.myco"
Scripts/finalize.sh --app "MyApp" --repo "you/MyApp" \
  --category "public.app-category.productivity" --copyright "Your Name" --distribution direct
rm -rf .git && git init && git add -A && git commit -m "Initial commit: MyApp"
gh repo create you/MyApp --private --source . --remote origin --push   # or add the remote manually
```
