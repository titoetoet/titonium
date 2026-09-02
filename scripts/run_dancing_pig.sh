#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QML_FILE="$DIR/demos/dancing_pig/main.qml"

if ! command -v qml6 &>/dev/null; then
    echo "Error: qml6 is not installed."
    exit 1
fi

echo "🐷 Đang khởi chạy Piggy Disco: $QML_FILE ..."
exec qml6 "$QML_FILE"
