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
node "$project_root/scripts/check_config_migrations.js"
python3 "$project_root/scripts/check_architecture.py"
node "$project_root/scripts/check_arch_menu.js"
node "$project_root/scripts/check_session_actions.js"
node "$project_root/scripts/check_application_launch.js"
node "$project_root/scripts/check_application_visibility.js"
node "$project_root/scripts/check_lunar.js"
node "$project_root/scripts/check_spotlight.js"
node "$project_root/scripts/check_clipboard_history.js"
node "$project_root/scripts/check_clipboard_access.js"

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
