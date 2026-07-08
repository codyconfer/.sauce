---
name: slop-bucket
description: Save the throwaway helper scripts you write for yourself as generic, reusable tools in a `.slop-bucket.md` catalog at the working-directory root, and reuse them later instead of rewriting one-offs. Use when the user asks — directly ("add this to the slop bucket", "check the slop bucket", "slop-bucket it") OR sarcastically/indirectly ("another one for the slop pile", "toss it in the bucket", "into the slop it goes", "great, more slop"). If a mention of slop/the bucket is ambiguous, ask "is this one for the slop bucket, dave?" before acting. Do NOT apply automatically to every helper script.
---

# Slop bucket

A **slop bucket** is a single `.slop-bucket.md` file at the root of the working
directory that collects the little helper scripts you write for *yourself* while
working a task — inspection one-liners, data transforms, log parsers, repetitive
`git`/`curl`/`jq` invocations, scratch automation. Left alone these are disposable:
written once, hardcoded to the moment, thrown away, then rewritten from scratch the
next time. The slop bucket turns them into a growing catalog of generic tools you can
find and reuse across turns and sessions.

**This skill is opt-in.** Only engage it when the user asks. Do not silently rewrite
or catalog every helper you happen to write.

Read the request generously — the ask is often **sarcastic or indirect**, not a clean
command. Treat these as invocations too:

- "another one for the slop pile", "great, more slop", "add it to the pile"
- "toss it in the bucket", "into the slop it goes", "bucket it"
- any wry reference to *slop*, *the bucket*, or *the pile* pointed at a helper you just
  wrote or are about to write.

**When unsure, ask.** If a mention of slop / the bucket / the pile is ambiguous — could
be idle grumbling rather than a request to catalog the script — ask before doing
anything, using exactly this line:

> is this one for the slop bucket, dave?

Don't guess and silently write the file.

## On invocation, check the bucket first

Before writing a new helper, read `.slop-bucket.md` (if it exists) and look for an
entry that already does the job or is close enough to adapt. Reuse or extend an
existing script rather than adding a near-duplicate. Only add a new entry when nothing
there fits.

**When you reuse an entry, bump its access count.** Each entry carries an `Accessed: N`
marker (see Storage format). Every time you run or adapt that helper to do real work,
increment `N` by one and save the file. A new entry starts at `Accessed: 0`; the write
that *creates* it does not count as an access. The count is how the bucket surfaces
which slop has earned graduation into a real script or into this repo (see Promoting a
helper).

## Generalize before storing

A script only earns a place in the bucket if it is reusable. Before saving, lift it out
of the one-off:

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

`.slop-bucket.md` is a flat catalog — one section per script:

    ## <script-name>

    Accessed: <N>

    One line: what it does and when to reach for it.

    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    # ... generic, parameterized implementation ...
    ```

    Usage: `<script-name> <args...>` — plus a concrete example.

The `Accessed: <N>` line is required and lives directly under the heading. It starts at
`0` when the entry is created and is incremented each time the helper is reused (see
"On invocation" above).

Rules for editing the file:

- **Update in place.** If you improved or generalized an existing entry, edit that
  section — don't append a second copy. Preserve its `Accessed` count across edits.
- **Deduplicate.** Merge overlapping helpers into one more-general tool; when merging,
  sum their access counts into the surviving entry.
- **Keep it a catalog, not a changelog.** No dated entries or history; each section is
  the current best version of that tool.

## Promoting a helper out of the bucket

The bucket is a staging area, not a permanent home. A helper with a high `Accessed`
count is slop that has proven itself and should graduate. When the user asks to
"review the bucket", "export/graduate a helper", or "promote the slop" — or when you
notice a frequently-accessed entry — offer the two paths below. **Always confirm the
destination and name with the user before writing anything outside `.slop-bucket.md`.**

### Reviewing

List the entries with their `Accessed` counts, highest first, so the user can see what
has earned promotion (e.g. "`git-prune-merged` — accessed 7×; `json-diff` — accessed
5×").

**Recommend exporting the top three** entries by access count as the default, but
**offer to do more or all** — e.g. "I'd start with the top 3 (`git-prune-merged`,
`json-diff`, `log-tail`). Want those, more, or the whole bucket?" Let the user pick the
scope before you export anything. If the bucket holds three or fewer entries, just offer
them all.

### Path A — export to a standalone script file

For a general-purpose helper not specific to this repo:

1. **Prompt for a name** — suggest the entry's slug (`git-prune-merged`), but ask the
   user to confirm or override, and ask where it should live (default `~/.local/bin/`
   so it lands on `PATH`).
2. Write the code block from the entry to `<dir>/<name>`, keep the shebang, and
   `chmod +x` it.
3. Report the path and how to run it.

### Path B — promote into chezmoi / this repo

When the helper belongs to *this* dotfiles repo (it manages a tool, shell config, or
setup step), don't just drop a loose script — wire it into the chezmoi framework using
the repo's own skills:

- A tool install/update, a distro package, or a download → **`add-tool-installer`**.
- Shell config — an alias, a function, PATH/env in the rc files → **`add-shell-fragment`**.
- A distro desktop app → **`add-distro-app`**; a setup step → **`add-chezmoiscript-step`**.

Follow the chosen skill to place the code correctly (source `scripts/lib/common.sh`
helpers, add the `tools`/`distroApps` prompt entry, gate PATH, etc.), then run
**`validate-scripts`** and, for wiring changes, **`code-review`**.

### After promoting

Once a helper is exported or wired into the repo, **remove its entry from
`.slop-bucket.md`** (it now lives somewhere real) — unless the user wants to keep the
scratch copy around. Never delete an entry the user hasn't agreed to promote.

## Housekeeping

- Create `.slop-bucket.md` at the working-directory root if it doesn't exist yet.
- Whether to commit `.slop-bucket.md` or add it to `.gitignore` is the user's call —
  don't decide it for them or enforce either way unless asked.
