#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
user_home="$(getent passwd "$(id -u)" | cut -d: -f6)"
data_root="${XDG_DATA_HOME:-$user_home/.local/share}"
runtime_dir="$data_root/titonium"
runtime_layout="$runtime_dir/layout.json"
backup_dir="$(mktemp -d --tmpdir titonium-runtime-backup.XXXXXX)"
had_layout=false

mkdir -p -- "$runtime_dir"
if [[ -f "$runtime_layout" ]]; then
    cp -- "$runtime_layout" "$backup_dir/layout.json"
    had_layout=true
fi

restore_runtime() {
    if [[ $had_layout == true ]]; then
        cp -- "$backup_dir/layout.json" "$runtime_layout"
        rm -f -- "$backup_dir/layout.json"
    else
        rm -f -- "$runtime_layout"
    fi
    rmdir -- "$backup_dir"
}
trap restore_runtime EXIT

run_case() {
    local case_name="$1"
    local expected_pattern="$2"
    local log_file
    local status
    log_file="$(mktemp --tmpdir "titonium-$case_name.XXXXXX.log")"

    set +e
    timeout --signal=TERM 8s qs -n -p "$project_root" >"$log_file" 2>&1
    status=$?
    set -e

    if [[ $status -ne 0 && $status -ne 124 ]]; then
        sed -n '1,240p' "$log_file" >&2
        rm -f -- "$log_file"
        return 1
    fi
    if ! rg -q 'Configuration Loaded' "$log_file" || ! rg -q "$expected_pattern" "$log_file"; then
        sed -n '1,240p' "$log_file" >&2
        rm -f -- "$log_file"
        return 1
    fi
    if rg -i '\b(ERROR|TypeError|duplicate id|missing method)\b' "$log_file"; then
        sed -n '1,240p' "$log_file" >&2
        rm -f -- "$log_file"
        return 1
    fi

    rm -f -- "$log_file"
    echo "PASS $case_name"
}

cp -- "$project_root/tests/fixtures/layout.invalid-type.json" "$runtime_layout"
run_case "invalid-runtime-fallback" 'runtime layout rejected'

cp -- "$project_root/tests/fixtures/layout.valid.json" "$runtime_layout"
run_case "unknown-widget-fallback" 'unknown widget type: unknown.fixture'
