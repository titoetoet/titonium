#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"

before_live="$(sha256sum -- "$live_hypr")"
before_dotfiles="$(sha256sum -- "$dotfiles_hypr")"

if rg -n 'Process\s*\{|Timer\s*\{' \
    "$project_root/Titonium/Bar/widgets/InputMethod.qml" \
    "$project_root/Titonium/Services/InputMethod/InputMethodService.qml"; then
    echo "FAIL Input Method owns a Process or Timer" >&2
    exit 1
fi

"$project_root/scripts/spotlight_acceptance.sh"
"$project_root/scripts/dock_acceptance.sh"
"$project_root/scripts/bluetooth_acceptance.sh"
"$project_root/scripts/wifi_acceptance.sh"
"$project_root/scripts/window_switcher_acceptance.sh"
"$project_root/scripts/workspace_interactions_acceptance.sh"
"$project_root/scripts/notifications_acceptance.sh"
"$project_root/scripts/center_attention_acceptance.sh"
"$project_root/scripts/settings_acceptance.sh"

after_live="$(sha256sum -- "$live_hypr")"
after_dotfiles="$(sha256sum -- "$dotfiles_hypr")"

if [[ "$after_live" != "$before_live" || "$after_dotfiles" != "$before_dotfiles" ]]; then
    echo "FAIL protected acceptance changed a Hyprland configuration" >&2
    exit 1
fi

echo "PASS protected Spotlight, Input Method, Dock, Bluetooth, Wi-Fi, Window Switcher, workspace, notification, Center attention and Settings acceptance"
