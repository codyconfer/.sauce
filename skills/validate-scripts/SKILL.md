---
name: validate-scripts
description: Validate the chezmoi-managed ~/.sauce dotfiles before committing — render templates, dry-run apply, and syntax-check the shell files and rc configs. Use when asked to "validate/check the scripts", "lint the shell scripts", "did I break the zshrc/bashrc", or "check the chezmoi templates".
---

# Validate `~/.sauce`

Run these from the repo root. They are fast, read-only, and catch the most common
breakage (template errors, syntax slips) before a commit. They assume `chezmoi` is
installed; if it isn't, run the shell checks (steps 3–4) and say chezmoi was skipped.

## 1. Render the templates

```bash
chezmoi execute-template --init < home/.chezmoi.toml.tmpl
for t in home/dot_config/nvim/lua/sauce/generated.lua.tmpl \
         home/.chezmoiexternal.toml.tmpl \
         home/.chezmoiscripts/*.tmpl; do
  echo "== $t =="
  chezmoi execute-template < "$t" >/dev/null || echo "TEMPLATE ERROR: $t"
done
```

A template error aborts `chezmoi apply` on every machine, so this is the highest-value check.

## 2. Dry-run apply

```bash
chezmoi apply --source="$PWD" --dry-run --verbose 2>&1 | head -50
```

Inspect the planned file writes, run-script order, and external downloads. Nothing
is written to `$HOME`. (Add `--refresh-externals` only when you want to test the
download URLs.)

## 3. Syntax-check the shell files

```bash
for f in scripts/*.sh scripts/lib/*.sh bootstrap.sh; do
  bash -n "$f" || echo "SYNTAX ERROR: $f"
done
# rc files (rendered output shells sourced on every machine)
zsh -ln home/dot_zshrc 2>/dev/null || bash -n home/dot_zshrc
bash -n home/dot_bashrc
command -v fish >/dev/null 2>&1 && fish --no-execute home/dot_config/fish/config.fish
```

`bash -n` parses without executing. A clean run prints nothing.

## 4. shellcheck (if available)

```bash
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck scripts/*.sh scripts/lib/*.sh bootstrap.sh
else
  echo "shellcheck not installed — skipping lint (syntax checks above still ran)."
fi
```

## Reporting

Summarize which checks passed/failed. If everything is clean, say so plainly. Do
not claim chezmoi or shellcheck passed if they were skipped.
