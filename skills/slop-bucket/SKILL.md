---
name: slop-bucket
description: Two-tier catalog for the throwaway helper scripts you write for yourself. Auto-save every helper to a private `.local/agent-slop-bucket.md` scratchpad (tracks an `Accessed` count inline); reuse cataloged helpers instead of rewriting one-offs. On every 3rd access — or when the user asks — offer to promote an entry into the curated, human-readable `.local/slop-bucket.md`, and from there export it to a real script or wire it into the repo. Promotion is user-gated and the ask is often indirect ("slop-bucket it", "check the slop bucket", "another one for the slop pile", "toss it in the bucket", "great, more slop"); if a slop/bucket mention is ambiguous, ask "is this one for the slop bucket, dave?". Writing to .local/agent-slop-bucket.md is automatic; do NOT auto-promote into .local/slop-bucket.md.
---

# Slop bucket

A **slop bucket** collects the little helper scripts you write for *yourself* while
working a task — inspection one-liners, data transforms, log parsers, repetitive
`git`/`curl`/`jq` invocations, scratch automation. Left alone these are disposable:
written once, hardcoded to the moment, thrown away, then rewritten from scratch the
next time. The slop bucket turns them into a growing catalog of generic tools you can
find and reuse across turns and sessions.

## Two buckets

There are **two** files, both kept under `.local/` at the working-directory root:

- **`.local/agent-slop-bucket.md`** — *your* scratchpad. **Automatically save every helper
  script you write for yourself here — no need to ask.** It doesn't have to be
  human-readable; it's a terse working store. It still tracks an `Accessed: N` count per
  entry.
- **`.local/slop-bucket.md`** — the **curated, human-readable** catalog. Entries land here
  only by being **promoted** from the agent bucket, through a user-confirmed gate. This
  is the file a human reads.

The flow is a two-tier funnel — each promotion tier is user-gated:

    helper you write  →  .local/agent-slop-bucket.md   (auto, no ask)
                      →  .local/slop-bucket.md         (promote: ask, every 3rd access)
                      →  real script / repo            (export: ask, Path A/B)

**Writing to `.local/agent-slop-bucket.md` is automatic and needs no invocation.** Everything
below about being *opt-in* and *asking first* governs **promotion** — graduating slop
from the agent bucket into `.local/slop-bucket.md`, and out of `.local/slop-bucket.md` into a real
home. Never promote without the user's say-so.

Read a promotion request generously — the ask is often **sarcastic or indirect**, not a
clean command. Treat these as promotion invocations too:

- "another one for the slop pile", "great, more slop", "add it to the pile"
- "toss it in the bucket", "into the slop it goes", "bucket it"
- any wry reference to *slop*, *the bucket*, or *the pile* pointed at a helper you just
  wrote or are about to write.

**When unsure, ask.** If a mention of slop / the bucket / the pile is ambiguous — could
be idle grumbling rather than a request to promote a script — ask before promoting
anything, using exactly this line:

> is this one for the slop bucket, dave?

Don't guess and silently promote into `.local/slop-bucket.md`.

## Before writing a helper, check the agent bucket

Before writing a new helper, read `.local/agent-slop-bucket.md` (if it exists) and look for an
entry that already does the job or is close enough to adapt. Reuse or extend an existing
script rather than adding a near-duplicate; only add a new entry when nothing fits. New
helpers you write for yourself go into `.local/agent-slop-bucket.md` **automatically**.

**When you reuse an entry, bump its access count.** Each entry carries an `Accessed: N`
marker (see Storage format). Every time you run or adapt that helper to do real work,
increment `N` by one and save the file. A new entry starts at `Accessed: 0`; the write
that *creates* it does not count as an access.

**Every 3rd access, offer to promote.** Whenever bumping a count in
`.local/agent-slop-bucket.md` lands it on a multiple of 3 (`Accessed: 3`, `6`, `9`, …), the
script has proven itself — **ask the user** whether to promote it into the curated
`.local/slop-bucket.md` (see "Promoting from the agent bucket"). The 3rd-access ask *is* the
gate; never promote unprompted. If the user declines, keep counting and ask again at the
next multiple of 3.

## Generalize before storing

The agent bucket can hold rough, task-shaped scratch. But a script only earns a place in
the **curated** `.local/slop-bucket.md` if it's reusable — so before promoting (and, ideally,
as you write it), lift it out of the one-off:

- **Parameterize inputs.** Take paths, hosts, names, and values as arguments, flags, or
  environment variables — never hardcode the specifics of the current task.
- **Provide sane defaults** where a reasonable one exists, so the common case is a bare
  invocation.
- **Make it idempotent and safe to re-run.** No destructive side effects without an
  explicit flag; prefer read-only or additive behavior by default.
- **No secrets, no machine-specific assumptions.** No embedded tokens, absolute
  `/home/<user>/...` paths, or "works only on my box" details.
- **Fail loudly.** For bash use `set -euo pipefail`; validate required args and print a
  short usage message when they're missing.
- **Name it for what it does**, not for the task you happened to be doing.

## Storage format

Both buckets are flat catalogs — one section per script, in the same shape:

    ## <script-name>

    Accessed: <N>

    One line: what it does and when to reach for it.

    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    # ... generic, parameterized implementation ...
    ```

    Usage: `<script-name> <args...>` — plus a concrete example.

`.local/agent-slop-bucket.md` uses this same layout but may be **terser** — it's your
scratchpad, so the one-line description and usage example are optional and the code can
stay rough. `.local/slop-bucket.md` entries should read cleanly for a human. Both files require
the `Accessed: <N>` line directly under the heading; it starts at `0` when the entry is
created and increments on each reuse (see "Before writing a helper, check the agent
bucket" above).

Rules for editing the file:

- **Update in place.** If you improved or generalized an existing entry, edit that
  section — don't append a second copy. Preserve its `Accessed` count across edits.
- **Deduplicate.** Merge overlapping helpers into one more-general tool; when merging,
  sum their access counts into the surviving entry.
- **Keep it a catalog, not a changelog.** No dated entries or history; each section is
  the current best version of that tool.

## Promoting from the agent bucket to `.local/slop-bucket.md`

This is **tier 1** of promotion — graduating proven scratch into the curated catalog. Do
it when a `.local/agent-slop-bucket.md` entry hits a **3rd access** (`Accessed: 3`, `6`, `9`,
…) or when the user asks (including the indirect phrasings above).

**It is user-gated.** Never move an entry into `.local/slop-bucket.md` without confirmation. On
the 3rd-access trigger, ask something like: "`json-diff` has earned its keep (3×) —
promote it to the slop bucket?" If the user declines, leave it in the agent bucket and
ask again at the next multiple of 3.

On a yes:

1. **Clean it up for humans** — apply *Generalize before storing*: parameterize inputs,
   add the one-line description and a concrete usage example.
2. **Add it to `.local/slop-bucket.md`** as a new section, **carrying over its `Accessed`
   count** so the tier-2 export threshold still reflects real usage.
3. **Remove it from `.local/agent-slop-bucket.md`** — it now lives in the curated catalog —
   unless the user wants to keep the scratch copy.

## Promoting out of `.local/slop-bucket.md`

This is **tier 2** — graduating a curated helper into a real home. The curated bucket is
still a staging area, not a permanent home. A helper with a high `Accessed` count is slop
that has proven itself and should graduate. When the user asks to "review the bucket",
"export/graduate a helper", or "promote the slop" — or when you notice a
frequently-accessed entry — offer the two paths below. **Always confirm the destination
and name with the user before writing anything outside `.local/slop-bucket.md`.**

### Reviewing

List the entries with their `Accessed` counts, highest first, so the user can see what
has earned promotion (e.g. "`git-prune-merged` — accessed 7×; `json-diff` — accessed
5×").

**Recommend exporting the top three** entries by access count as the default, but
**offer to do more or all** — e.g. "I'd start with the top 3 (`git-prune-merged`,
`json-diff`, `log-tail`). Want those, more, or the whole bucket?" Let the user pick the
scope before you export anything. If the bucket holds three or fewer entries, just offer
them all.

### Document concisely on export

Any documentation you write while exporting — a `.md` doc, a source-file header, or
notes for a repo wiring — must be **brief and scannable**. Lead with visuals, not prose:

- **Mermaid** diagrams for flow/structure.
- **Arrows** for pipelines and data flow (e.g. `stdin → jq filter → sorted table`).
- **Bulleted lists** for args, flags, and steps.
- Keep prose minimal — the whole doc should scan in seconds.

### Path A — export to a file

For a general-purpose helper not specific to this repo:

1. **Prompt for a name** — suggest the entry's slug (`git-prune-merged`), but ask the
   user to confirm or override, and ask where it should live (default `~/.local/bin/`
   so it lands on `PATH`).
2. **Ask which format** to export:
   - **Source file** (default) — write the code block to `<dir>/<name>`, keep the
     shebang, and `chmod +x` it. **Ask whether inline comments are wanted:** if yes,
     add brief comments on the non-obvious steps; if no, export the code clean.
   - **Markdown (`.md`)** — write `<dir>/<name>.md` as a documented walkthrough:
     concise explanations (mermaid / arrows / bullets, per the brevity note above)
     sitting *between* the fenced code blocks, rather than one raw script.
3. Report the path and how to run or read it.

### Path B — promote into chezmoi / this repo

When the helper belongs to *this* dotfiles repo (it manages a tool, shell config, or
setup step), don't just drop a loose script — wire it into the chezmoi framework using
the repo's own skills:

- A tool install/update, a distro package, or a download → **`add-tool-installer`**.
- Shell config — an alias, a function, PATH/env in the rc files → **`add-shell-fragment`**.
- A distro desktop app → **`add-distro-app`**; a setup step → **`add-chezmoiscript-step`**.

Follow the chosen skill to place the code correctly (source `scripts/lib/common.sh`
helpers, add the `tools`/`distroApps` prompt entry, gate PATH, etc.), then run
**`validate-scripts`** and, for wiring changes, **`code-review`**. Keep any README or
comments you add brief and visual (see the brevity note above).

### After promoting

Once a helper is exported or wired into the repo, **remove its entry from
`.local/slop-bucket.md`** (it now lives somewhere real) — unless the user wants to keep the
scratch copy around. Never delete an entry the user hasn't agreed to promote.

## Housekeeping

- Both buckets live under `.local/` at the working-directory root:
  `.local/agent-slop-bucket.md` (created on the first auto-save) and
  `.local/slop-bucket.md` (created on the first promotion). Create the `.local/`
  directory if it doesn't exist yet.
- **In a git repo, keep `.local/` out of version control.** If it isn't already
  git-ignored, create or append to `.gitignore` at the repo root:

      .local/

  (Check whether the line is present before adding it; don't duplicate entries.)
- Outside a git repo there's nothing to ignore — just create the files.
