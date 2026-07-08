---
name: slop-bucket
description: Two-tier catalog for throwaway helpers you write for yourself — INCLUDING ad-hoc inline shell one-liners (curl/HTTP probes, git/jq/node one-liners, syntax/type checks, log greps), not just saved scripts. If you ran a shell command to answer "did this work / what does this look like", it is slop — capture it on FIRST use, proactively and without being asked: auto-save a generalized form to `.local/.agents/slop-bucket.md` (tracks an inline `Accessed` count) and reuse cataloged helpers instead of rewriting one-offs. Once an entry is accessed more than once, automatically promote it into the curated `.local/slop-bucket.md` — no asking. Export from there to a real script only when the user asks. Run this workflow on every prompt — capture, reuse, and auto-promote proactively — until the user says to stop. Agent-bucket writes and promotion are automatic; only export is user-gated.
---

# Slop bucket

Helpers you write for *yourself* — inspection one-liners, transforms, scratch `git`/`curl`/`jq` — are normally written once, hardcoded, thrown away, and rewritten next session. The slop bucket catalogs them for reuse across turns and sessions.

**Run this on every prompt** — capture new slop, reuse cataloged helpers, and auto-promote earners — proactively and without being asked, until the user tells you to stop.

**When you finish working a problem, print the bucket.** Once you've wrapped up the task at hand, output a simple markdown table of the entries in `.local/slop-bucket.md`:

| Name | Summary | Accessed |
| --- | --- | --- |
| json-probe | curl a URL and pretty-print the JSON body | 2 |

One row per curated entry, using its one-line description as the summary and its `Accessed` count. Skip the table if the curated bucket is empty.

## Two buckets, one funnel

    helper you write  →  .local/.agents/slop-bucket.md   (auto — never ask)
                      →  .local/slop-bucket.md           (auto — after >1 access)
                      →  real script                     (on request)

- **`.local/.agents/slop-bucket.md`** — your scratchpad. Auto-save every helper here; terse and rough is fine.
- **`.local/slop-bucket.md`** — curated, human-readable. Entries arrive automatically once they've earned it.

**Agent-bucket writes and promotion are automatic. Only export needs the user's yes.**

## What counts as slop

Any command run to answer "did this work?" or "what does this look like?" — inline invocations count exactly like saved scripts:

- **Verification / smoke tests** — curl/HTTP probes, "start a server, hit it, kill it", asserting a response field.
- **Inspection one-liners** — `git diff … | wc -l`, `jq`/`node -e` field extraction, log greps, ref comparisons.
- **Transform / check scaffolding** — syntax checks (`bash -n`, `node --check`), scoped type-checks, patch generation, bulk renames.

Capture on **first use**, mid-task, without being asked — generalizing as you copy it in. Don't wait until you've retyped it three times.

## Workflow

1. **Before writing a helper**, read `.local/.agents/slop-bucket.md` (if it exists). Reuse or extend a close-enough entry; only add a new one when nothing fits.
2. **On each reuse**, bump that entry's `Accessed: N` and save. New entries start at `Accessed: 0`; the creating write doesn't count.
3. **When `Accessed` passes 1** (its second access, i.e. accessed more than once), **automatically** promote it into `.local/slop-bucket.md`. Don't ask — just do it, cleaning it up per *Generalize before storing* on the way in.

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

**Triggered automatically when an entry's `Accessed` count exceeds 1 (its second access):**

1. Clean it up per *Generalize before storing*; add the one-line description and usage example.
2. Add it to `.local/slop-bucket.md`, **carrying over its `Accessed` count**.
3. Remove it from the agent bucket, unless the user wants the scratch copy kept.

## Tier 2 — export out of `.local/slop-bucket.md`

**Only on request** ("review the bucket", "graduate/export a helper", "promote the slop"). You may point out a high-count candidate, but never export unprompted, and **always confirm destination and name first**.

**Reviewing:** list entries by `Accessed`, highest first. Recommend the top 3 but offer more or all; if the bucket holds ≤3 entries, offer them all.

**Docs written on export are brief and visual:** mermaid for flow/structure, arrows for pipelines (`stdin → jq → table`), bullets for args/flags — minimal prose, scannable in seconds.

**Export to a file:**

1. Confirm the name (suggest the entry's slug) and location (default `~/.local/bin/`).
2. Ask which format:
   - **Source file** (default) — keep shebang, `chmod +x`; ask whether inline comments are wanted.
   - **Markdown** — `<dir>/<name>.md`, concise notes interleaved between the code blocks.
3. Report the path and how to run or read it.

After export, remove the entry from `.local/slop-bucket.md` unless the user wants it kept. Never delete an entry the user hasn't agreed to export.

## Housekeeping

- The agent scratchpad lives at `.local/.agents/slop-bucket.md` and the curated bucket at `.local/slop-bucket.md`, both under `.local/` at the working-directory root; create the `.local/` and `.local/.agents/` directories on first save.
- In a git repo, ensure `.gitignore` contains a `.local/` line (check before adding; don't duplicate) — it covers the nested `.agents/` dir too. Outside a repo, just create the files.
