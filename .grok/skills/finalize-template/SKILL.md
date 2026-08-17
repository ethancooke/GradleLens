---
name: finalize-template
description: Use when the AppleFactory macOS app template has been freshly cloned or copied and needs to be rebranded and finalized into a new app. Triggers on phrases like "set up this template", "rebrand the template", "finalize the clone", "I just cloned AppleFactory", or when Sources/AppTemplate/ still exists alongside Scripts/rename.sh. Asks a few questions (app name, bundle ID, description, category, distribution, permissions, copyright, repo URL), then runs rename.sh + finalize.sh and makes the targeted edits in docs/FINALIZE.md.
---

# Finalize a freshly cloned AppleFactory template

This skill rebrands a just-cloned AppleFactory template into a real app in one guided pass. The
canonical workflow — the questions, the script arguments, the permission/category tables, and every
step — lives in **[`docs/FINALIZE.md`](docs/FINALIZE.md)**. Read it first, then execute it.

## When to trigger

Trigger when the repo is still in its un-rebranded state. Detection signals (any one is enough):

- `Scripts/rename.sh` exists **and** `Sources/AppTemplate/` still exists (not yet renamed).
- `Resources/Info.plist` contains `com.example.AppTemplate`.
- The sample `Greeting` / `GreetingService` code exists in `Sources/AppTemplateCore/`.

If `Sources/AppTemplate/` has already been renamed away, the template is already finalized — do not
run this skill. If the user explicitly asks to re-run finalization, confirm with them first.

## How to run it

1. **Ask the questions.** Use `ask_user_question` to ask all of them in as few calls as possible
   (batch independent questions together). The full question list, with options and tables, is in
   `docs/FINALIZE.md` § Step 1. The required ones: app name, bundle ID prefix, one-line description,
   app category, distribution channel. Optional: permissions (multi-select), copyright holder,
   GitHub owner/repo, keep sample code.

   For free-text answers (app name, bundle ID, description, copyright, repo), offer a couple of
   example options but rely on the user's typed answer. For category and distribution, offer the
   enumerated options from the table in `docs/FINALIZE.md`. For permissions, use a multi-select.

2. **Run the scripts** (`docs/FINALIZE.md` § Step 2):
   ```bash
   Scripts/rename.sh "<App name>" "<Bundle ID prefix>"
   Scripts/finalize.sh --app "<App name>" --repo "<owner/repo>" \
     --category "<category>" [--copyright "<holder>"] [--distribution direct|appstore]
   ```
   Run `rename.sh` before `finalize.sh`. Use `run_terminal_command` for both.

3. **Make the semantic edits** (`docs/FINALIZE.md` § Step 3): rewrite the README description and
   AGENTS.md project summary with the user's one-line description; add `NS*UsageDescription` keys to
   `Resources/Info.plist` and matching entitlements to `Resources/Entitlements.plist` for each
   chosen permission; update PRIVACY.md and SECURITY.md if relevant; delete the sample code if the
   user asked. **Never add XML comments to `Entitlements.plist`** — `codesign` rejects them.

4. **Verify** (`docs/FINALIZE.md` § Step 4): run `swift build && swift build -c release && swift test`
   with `run_terminal_command`. Fix any failures before handing off.

5. **Hand off**: tell the user to `git diff`, then commit. Mention they can delete
   `Scripts/rename.sh`, `Scripts/finalize.sh`, `docs/FINALIZE.md`, and the `.opencode/`/`.cursor/`/
   `.grok/`/`CLAUDE.md` tool files once they're done.

## Key rules

- Ask all questions before changing anything, so the scripts run once with the correct args.
- Do not paraphrase the user's permission usage-description strings — add them verbatim.
- Keep `Entitlements.plist` comment-free.
- If the user picks App Store distribution, `finalize.sh` enables App Sandbox; remind them to drop
  notarization from the release pipeline (see `docs/RELEASING.md`).
- After the scripts run, the source dirs are renamed (`Sources/<App>/`, `Sources/<App>Core/`), so
  use the new paths for any further edits.
