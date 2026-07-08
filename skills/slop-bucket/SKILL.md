---
name: slop-bucket
description: Two-tier catalog for throwaway helpers you write for yourself — INCLUDING ad-hoc inline shell one-liners (curl/HTTP probes, git/jq/node one-liners, syntax/type checks, log greps), not just saved scripts. If you ran a shell command to answer "did this work / what does this look like", it is slop — capture it on FIRST use, proactively and without being asked: auto-save a generalized form to `.local/agent-slop-bucket.md` (tracks an inline `Accessed` count) and reuse cataloged helpers instead of rewriting one-offs. Every 3rd access — or when the user asks, often indirectly ("slop-bucket it", "toss it in the bucket", "another one for the slop pile", "great, more slop") — offer to promote an entry into the curated `.local/slop-bucket.md`, and from there export to a real script or the repo. If a slop/bucket mention is ambiguous, ask "is this one for the slop bucket, dave?". Agent-bucket writes are automatic; promotion is always user-gated.
---

# Slop bucket

Helpers you write for *yourself* — inspection one-liners, transforms, scratch `git`/`curl`/`jq` — are normally written once, hardcoded, thrown away, and rewritten next session. The slop bucket catalogs them for reuse across turns and sessions.

## Two buckets, one funnel

    helper you write  →  .local/agent-slop-bucket.md   (auto — never ask)
                      →  .local/slop-bucket.md         (tier 1: ask, every 3rd access)
                      →  real script / repo            (tier 2: ask, Path A/B)

- **`.local/agent-slop-bucket.md`** — your scratchpad. Auto-save every helper here; terse and rough is fine.
- **`.local/slop-bucket.md`** — curated, human-readable. Entries arrive only via user-confirmed promotion.

**Only the agent-bucket write is automatic. Every promotion needs the user's yes.**

## What counts as slop

Any command run to answer "did this work?" or "what does this look like?" — inline invocations count exactly like saved scripts:

- **Verification / smoke tests** — curl/HTTP probes, "start a server, hit it, kill it", asserting a response field.
- **Inspection one-liners** — `git diff … | wc -l`, `jq`/`node -e` field extraction, log greps, ref comparisons.
- **Transform / check scaffolding** — syntax checks (`bash -n`, `node --check`), scoped type-checks, patch generation, bulk renames.

Capture on **first use**, mid-task, without being asked — generalizing as you copy it in. Don't wait until you've retyped it three times.

## Workflow

1. **Before writing a helper**, read `.local/agent-slop-bucket.md` (if it exists). Reuse or extend a close-enough entry; only add a new one when nothing fits.
2. **On each reuse**, bump that entry's `Accessed: N` and save. New entries start at `Accessed: 0`; the creating write doesn't count.
3. **When N lands on a multiple of 3**, ask to promote — e.g. "`json-diff` has earned its keep (3×) — promote it to the slop bucket?" Declined → keep counting, ask again at the next multiple.

Promotion asks are often **sarcastic or indirect**: "another one for the slop pile", "great, more slop", "toss it in the bucket", "bucket it", any wry slop/bucket/pile reference aimed at a helper. If it could just be idle grumbling, ask exactly:

> is this one for the slop bucket, dave?

Never guess and silently promote.

## Generalize before storing

Required before an entry enters the curated bucket; ideally done as you write:

- **Parameterize inputs** — args, flags, or env vars; never hardcode the current task's paths/hosts/names. Provide sane defaults.
- **Idempotent and safe** — no destructive side effects without an explicit flag.
- **No secrets, no machine-specific paths.**
- **Fail loudly** — `set -euo pipefail`, validate required args, print usage.
- **Name it for what it does**, not the task at hand.

## Storage format

Both files are flat catalogs, one section per script:

    ## <script-name>

    Accessed: <N>

    One line: what it does and when to reach for it.

    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    # ... generic, parameterized implementation ...
    ```

    Usage: `<script-name> <args...>` — plus a concrete example.

The agent bucket may skip the description/usage and stay rough; the curated bucket must read cleanly. The `Accessed: <N>` line is required in both.

Editing rules: **update in place** (preserve `Accessed` across edits); **merge duplicates** into one general tool (sum their counts); **catalog, not changelog** — no dated entries.

## Tier 1 — promote into `.local/slop-bucket.md`

Triggered by a 3rd-access ask or a user request. On a yes:

1. Clean it up per *Generalize before storing*; add the one-line description and usage example.
2. Add it to `.local/slop-bucket.md`, **carrying over its `Accessed` count**.
3. Remove it from the agent bucket, unless the user wants the scratch copy kept.

## Tier 2 — export out of `.local/slop-bucket.md`

**Only on request** ("review the bucket", "graduate/export a helper", "promote the slop"). You may point out a high-count candidate, but never export unprompted, and **always confirm destination and name first**.

**Reviewing:** list entries by `Accessed`, highest first. Recommend the top 3 but offer more or all; if the bucket holds ≤3 entries, offer them all.

**Docs written on export are brief and visual:** mermaid for flow/structure, arrows for pipelines (`stdin → jq → table`), bullets for args/flags — minimal prose, scannable in seconds.

### Path A — export to a file

For general-purpose helpers:

1. Confirm the name (suggest the entry's slug) and location (default `~/.local/bin/`).
2. Ask which format:
   - **Source file** (default) — keep shebang, `chmod +x`; ask whether inline comments are wanted.
   - **Markdown** — `<dir>/<name>.md`, concise notes interleaved between the code blocks.
3. Report the path and how to run or read it.

### Path B — wire into this chezmoi repo

For helpers that belong to the dotfiles repo, use the repo's own skills instead of dropping a loose script:

- Tool install/update, distro package, or download → **`add-tool-installer`**
- Alias, function, PATH/env in rc files → **`add-shell-fragment`**
- Distro desktop app → **`add-distro-app`**; setup step → **`add-chezmoiscript-step`**

Then run **`validate-scripts`** and, for wiring changes, **`code-review`**.

After export, remove the entry from `.local/slop-bucket.md` unless the user wants it kept. Never delete an entry the user hasn't agreed to promote.

## Housekeeping

- Both files live under `.local/` at the working-directory root; create the directory on first save.
- In a git repo, ensure `.gitignore` contains a `.local/` line (check before adding; don't duplicate). Outside a repo, just create the files.
