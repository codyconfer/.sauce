---
name: validate-scripts
description: Syntax-check the shell scripts and rc templates in the ~/.sauce toolkit before committing. Use when asked to "validate/check the scripts", "lint the shell scripts", or "did I break the zshrc/bashrc".
---

# Validate `~/.sauce` scripts

Run these checks from the repo root. They are fast, read-only, and catch the
most common breakage (syntax errors, unbalanced heredocs) before a commit.

## 1. Syntax-check bash scripts

```bash
for f in scripts/*.sh scripts/lib/*.sh; do
  bash -n "$f" || echo "SYNTAX ERROR: $f"
done
```

`bash -n` parses without executing. A clean run prints nothing.

## 2. Syntax-check the rc files

```bash
zsh -n  stow/zsh/.zshrc
bash -n stow/bash/.bashrc
command -v fish >/dev/null && fish --no-execute stow/fish/.config/fish/config.fish
```

These are the real files stow symlinks into `$HOME`, so a syntax slip here breaks
`~/.zshrc` / `~/.bashrc` / `~/.config/fish/config.fish` on every machine.

## 3. shellcheck (if available)

```bash
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck scripts/*.sh scripts/lib/*.sh
else
  echo "shellcheck not installed — skipping lint (syntax checks above still ran)."
fi
```

shellcheck catches quoting bugs, unused vars, and unsafe patterns that `bash -n`
won't. If it isn't installed, report that rather than claiming a clean lint.

## Reporting

Summarize which files passed/failed. If everything is clean, say so plainly. Do
not claim shellcheck passed if it was skipped.
