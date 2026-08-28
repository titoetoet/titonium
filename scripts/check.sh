#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
qml_import_root="$(mktemp -d --tmpdir titonium-qml-import.XXXXXX)"
trap 'rm -f -- "$qml_import_root/qs"; rmdir -- "$qml_import_root"' EXIT
ln -s -- "$project_root" "$qml_import_root/qs"

python3 "$project_root/scripts/validate_config.py"
python3 "$project_root/scripts/check_protected_contract.py"
python3 "$project_root/scripts/check_skeleton.py"
python3 "$project_root/scripts/check_services.py"
python3 "$project_root/scripts/check_shared_controls.py"
python3 "$project_root/scripts/check_audio.py"
python3 "$project_root/scripts/check_bar.py"
node "$project_root/scripts/check_bar_layout.js"
node "$project_root/scripts/check_bar_visibility.js"
node "$project_root/scripts/check_center_notch.js"
node "$project_root/scripts/check_center_actions.js"
node "$project_root/scripts/check_audio_rules.js"
node "$project_root/scripts/check_audio_geometry.js"
node "$project_root/scripts/check_dock_rules.js"
python3 "$project_root/scripts/check_dock_store.py"
python3 "$project_root/scripts/check_dock.py"
node "$project_root/scripts/check_dock_layout.js"
node "$project_root/scripts/check_windows.js"
node "$project_root/scripts/check_active_window.js"
node "$project_root/scripts/check_center_attention_rules.js"
node "$project_root/scripts/check_notifications_rules.js"
python3 "$project_root/scripts/check_notifications.py"
node "$project_root/scripts/check_workspaces.js"
node "$project_root/scripts/check_workspace_colors.js"
node "$project_root/scripts/check_window_switcher_rules.js"
python3 "$project_root/scripts/check_window_switcher.py"
python3 "$project_root/scripts/check_surface_passthrough.py"
node "$project_root/scripts/check_bluetooth_rules.js"
python3 "$project_root/scripts/check_bluetooth.py"
node "$project_root/scripts/check_wifi_rules.js"
python3 "$project_root/scripts/check_wifi.py"
node "$project_root/scripts/check_screen_policy.js"
node "$project_root/scripts/check_preferences.js"
node "$project_root/scripts/check_typography.js"
node "$project_root/scripts/check_application_launch.js"
node "$project_root/scripts/check_application_visibility.js"
node "$project_root/scripts/check_spotlight.js"
node "$project_root/scripts/check_clipboard_history.js"
node "$project_root/scripts/check_clipboard_access.js"
bash -n "$project_root/scripts/center_notch_acceptance.sh"
bash -n "$project_root/scripts/audio_acceptance.sh"
bash -n "$project_root/scripts/dock_acceptance.sh"
bash -n "$project_root/scripts/bluetooth_acceptance.sh"
bash -n "$project_root/scripts/wifi_acceptance.sh"
bash -n "$project_root/scripts/window_switcher_acceptance.sh"
bash -n "$project_root/scripts/workspace_interactions_acceptance.sh"
bash -n "$project_root/scripts/notifications_acceptance.sh"
bash -n "$project_root/scripts/protected_acceptance.sh"

mapfile -d '' qml_files < <(find "$project_root" -type f -name '*.qml' -print0 | sort -z)
qml_output="$(/usr/lib/qt6/bin/qmllint -I "$qml_import_root" "${qml_files[@]}" 2>&1)"
printf '%s\n' "$qml_output"

unexpected_warnings="$(printf '%s\n' "$qml_output" \
    | rg '^Warning:' \
    | rg -v -f "$project_root/scripts/qmllint_allowlist.txt" || true)"
if [[ -n "$unexpected_warnings" ]]; then
    printf 'FAIL unexpected qmllint warnings:\n%s\n' "$unexpected_warnings" >&2
    exit 1
fi

echo "PASS qmllint"
