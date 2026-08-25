#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$project_root/scripts/validate_config.py"
python3 "$project_root/scripts/check_architecture.py"

mapfile -d '' qml_files < <(find "$project_root" -type f -name '*.qml' -print0 | sort -z)
qml_output="$(/usr/lib/qt6/bin/qmllint -I "$project_root" "${qml_files[@]}" 2>&1)"
printf '%s\n' "$qml_output"

unexpected_warnings="$(printf '%s\n' "$qml_output" \
    | rg '^Warning:' \
    | rg -v -f "$project_root/scripts/qmllint_allowlist.txt" || true)"
if [[ -n "$unexpected_warnings" ]]; then
    printf 'FAIL unexpected qmllint warnings:\n%s\n' "$unexpected_warnings" >&2
    exit 1
fi

echo "PASS qmllint"
