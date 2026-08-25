#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
user_home="$(getent passwd "$(id -u)" | cut -d: -f6)"
data_root="${XDG_DATA_HOME:-$user_home/.local/share}"
runtime_dir="$data_root/titonium"
runtime_settings="$runtime_dir/settings.json"
runtime_layout="$runtime_dir/layout.json"
backup_dir="$(mktemp -d --tmpdir titonium-settings-acceptance.XXXXXX)"
log_file="$backup_dir/shell.log"
had_settings=false
had_layout=false
shell_pid=""

mkdir -p -- "$runtime_dir"
if [[ -f "$runtime_settings" ]]; then
    cp -- "$runtime_settings" "$backup_dir/settings.json"
    had_settings=true
fi
if [[ -f "$runtime_layout" ]]; then
    cp -- "$runtime_layout" "$backup_dir/layout.json"
    had_layout=true
fi

restore_runtime() {
    if [[ -n "$shell_pid" ]] && kill -0 "$shell_pid" 2>/dev/null; then
        kill "$shell_pid" 2>/dev/null || true
        wait "$shell_pid" 2>/dev/null || true
    fi
    if [[ $had_settings == true ]]; then
        cp -- "$backup_dir/settings.json" "$runtime_settings"
    else
        rm -f -- "$runtime_settings"
    fi
    if [[ $had_layout == true ]]; then
        cp -- "$backup_dir/layout.json" "$runtime_layout"
    else
        rm -f -- "$runtime_layout"
    fi
    rm -f -- "$backup_dir/settings.json" "$backup_dir/layout.json" "$log_file"
    rmdir -- "$backup_dir"
}
trap restore_runtime EXIT

call_ipc() {
    qs -p "$project_root" ipc call "$@"
}

before_git="$(git -C "$project_root" status --porcelain=v1)"
live_lua="$user_home/.config/hypr/hyprland.lua"
dotfiles_lua="$project_root/../titonium-hyprland/config/hypr/hyprland.lua"
before_live_hash="$(sha256sum "$live_lua" | cut -d' ' -f1)"
before_dotfiles_hash="$(sha256sum "$dotfiles_lua" | cut -d' ' -f1)"

qs -p "$project_root" --no-color >"$log_file" 2>&1 &
shell_pid=$!

ready=false
for _ in {1..40}; do
    if [[ "$(call_ipc app status 2>/dev/null || true)" == *ready* ]]; then
        ready=true
        break
    fi
    sleep 0.1
done
if [[ $ready != true ]]; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Settings acceptance shell did not become ready" >&2
    exit 1
fi

original_settings="$(call_ipc config settingsDocument)"
original_layout="$(call_ipc config layoutDocument)"

call_ipc config beginPreview >/dev/null
[[ "$(call_ipc config previewTheme titonium-hybrid-glass)" == *true* ]]
[[ "$(call_ipc config previewMaterialBackend qml)" == *true* ]]
preview_material="$(call_ipc config materialState)"
[[ "$preview_material" == *'"themeId":"titonium-hybrid-glass"'* ]]
[[ "$preview_material" == *'"resolved":"qml"'* ]]
call_ipc config cancel >/dev/null
[[ "$(call_ipc config settingsDocument)" == "$original_settings" ]]
[[ "$(call_ipc config layoutDocument)" == "$original_layout" ]]
echo "PASS Preview and Cancel restore exact settings/layout documents"

call_ipc config beginPreview >/dev/null
call_ipc config previewTheme titonium-hybrid-glass >/dev/null
call_ipc config previewMaterialBackend auto >/dev/null
auto_material="$(call_ipc config materialState)"
[[ "$auto_material" == *'"resolved":"qml"'* || "$auto_material" == *'"resolved":"native"'* ]]
[[ "$(call_ipc config apply)" == *true* ]]
applied=false
for _ in {1..40}; do
    if [[ -f "$runtime_settings" ]] && [[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["appearance"]["themeId"])' "$runtime_settings")" == "titonium-hybrid-glass" ]]; then
        applied=true
        break
    fi
    sleep 0.05
done
[[ $applied == true ]]
[[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["appearance"]["themeId"])' "$runtime_settings")" == "titonium-hybrid-glass" ]]
echo "PASS Apply writes hybrid appearance atomically outside the repository"

committed_nonappearance="$(call_ipc config committedSettingsDocument | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({k:d[k] for k in ("locale","accessibility","modules")},sort_keys=True))')"
call_ipc config beginPreview >/dev/null
[[ "$(call_ipc config restoreAppearance)" == *true* ]]
restored_appearance="$(call_ipc config appearanceState)"
[[ "$restored_appearance" == *'"themeId":"titonium-neutral"'* ]]
[[ "$restored_appearance" == *'"mode":"dark"'* ]]
[[ "$restored_appearance" == *'"density":"comfortable"'* ]]
[[ "$restored_appearance" == *'"overrides":{}'* ]]
restored_nonappearance="$(call_ipc config settingsDocument | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({k:d[k] for k in ("locale","accessibility","modules")},sort_keys=True))')"
[[ "$restored_nonappearance" == "$committed_nonappearance" ]]
[[ "$(call_ipc config layoutDocument)" == "$original_layout" ]]
call_ipc config cancel >/dev/null
echo "PASS Restore Appearance returns Neutral dark/solid and preserves non-appearance state"

[[ "$(git -C "$project_root" status --porcelain=v1)" == "$before_git" ]]
[[ "$(sha256sum "$live_lua" | cut -d' ' -f1)" == "$before_live_hash" ]]
[[ "$(sha256sum "$dotfiles_lua" | cut -d' ' -f1)" == "$before_dotfiles_hash" ]]
if rg -i '\b(ERROR|TypeError|duplicate id|missing method)\b' "$log_file"; then
    echo "FAIL runtime error found" >&2
    exit 1
fi
echo "PASS repository and both hyprland.lua hashes remain unchanged"
echo "PASS Settings and hybrid material acceptance"
