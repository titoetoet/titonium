#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QML_FILE="$DIR/main.qml"

if ! command -v qml6 &>/dev/null; then
    echo "Lỗi: Không tìm thấy qml6 trên hệ thống."
    exit 1
fi

echo "🐷 Đang khởi chạy Bộ sưu tập Mẫu Linh vật Heo: $QML_FILE ..."
exec qml6 "$QML_FILE"
