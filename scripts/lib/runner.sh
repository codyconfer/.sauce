#! /bin/bash

command -v log_error >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

_RUNNER_LINE="════════════════════════════════════════════════════"
declare -a _STEP_OK=()
declare -a _STEP_FAIL=()

box() {
    echo
    echo "$_RUNNER_LINE"
    echo "▶️  $*"
    echo "$_RUNNER_LINE"
}

run_step() {
    local label="$1"; shift
    box "$label"
    local rc=0
    "$@" || rc=$?
    if [ "$rc" -eq 0 ]; then
        _STEP_OK+=("$label")
    else
        log_error "$label failed (exit $rc)"
        _STEP_FAIL+=("$label")
    fi
}

# Resolve the selected tool set (chezmoi's `tools` prompt). Prints one tool per line,
# or nothing when the selection can't be determined (caller then runs everything).
#   1. UPDATE_TOOLS env (set — even to "") by the run-updaters wrapper at apply time.
#   2. `chezmoi data` .tools fallback for manual `update-all` runs.
_selected_tools() {
    if [ -n "${UPDATE_TOOLS+x}" ]; then
        printf '%s\n' ${UPDATE_TOOLS:-}
        return 0
    fi
    command -v chezmoi >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 0
    chezmoi data --format json 2>/dev/null | jq -r '.tools[]?' 2>/dev/null || true
}

run_update_scripts() {
    local dir="${1:-$SCRIPT_DIR}" mode="${2:-}" script name tool
    # Only filter when a selection is resolvable; otherwise run every updater
    # (backward-compatible with installs that predate the `tools` prompt).
    local filter=0
    local -A selected=()
    if [ -n "${UPDATE_TOOLS+x}" ]; then
        filter=1
        for tool in $(_selected_tools); do selected["$tool"]=1; done
    else
        local -a sel
        mapfile -t sel < <(_selected_tools)
        if [ "${#sel[@]}" -gt 0 ]; then
            filter=1
            for tool in "${sel[@]}"; do selected["$tool"]=1; done
        fi
    fi

    for script in "$dir"/update-*.sh; do
        name=$(basename "$script")
        [ "$name" = "update-all.sh" ] && continue
        if [ "$filter" -eq 1 ]; then
            tool="${name#update-}"; tool="${tool%.sh}"
            [ -n "${selected[$tool]:-}" ] || continue
        fi
        run_step "$name" bash "$script" ${mode:+"$mode"}
    done
}

print_summary() {
    local n
    echo
    echo "$_RUNNER_LINE"
    echo "📋 Summary"
    echo "$_RUNNER_LINE"
    echo "✅ Succeeded: ${#_STEP_OK[@]}"
    for n in "${_STEP_OK[@]}"; do echo "   • $n"; done
    if [ "${#_STEP_FAIL[@]}" -gt 0 ]; then
        echo "❌ Failed: ${#_STEP_FAIL[@]}"
        for n in "${_STEP_FAIL[@]}"; do echo "   • $n"; done
        return 1
    fi
    echo "🎉 All steps complete!"
}
