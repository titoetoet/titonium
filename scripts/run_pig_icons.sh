#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
qml_file="$project_root/demos/pig_icons/main.qml"

if ! command -v qml6 >/dev/null 2>&1; then
    echo "Error: qml6 not found in PATH" >&2
    exit 1
fi

exec qml6 "$qml_file" "$@"
