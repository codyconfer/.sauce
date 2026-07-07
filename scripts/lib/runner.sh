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

run_update_scripts() {
    local dir="${1:-$SCRIPT_DIR}" script name
    for script in "$dir"/update-*.sh; do
        name=$(basename "$script")
        [ "$name" = "update-all.sh" ] && continue
        run_step "$name" bash "$script"
    done
}

run_install_scripts() {
    local dir="${1:-$SCRIPT_DIR}" script name
    for script in "$dir"/install-*.sh; do
        [ -e "$script" ] || continue
        name=$(basename "$script")
        [ "$name" = "install-base.sh" ] && continue
        run_step "$name" bash "$script"
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
