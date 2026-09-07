# Source cleanup — 2026-09-06

User-approved housekeeping and legacy-source removal. Renderer lazy loading and performance measurement remain separate work.

## Result

Removed 20 source, module, test and asset files (57,278 bytes), 12 generated Python cache files (89,287 bytes), and empty assets/icons, assets and .worktrees directories. Gross removed size: 146,565 bytes (143.1 KiB); documentation/test edits affect the net size. The deleted AgentApproval directory was also removed after its five files were retired.

No retained runtime QML/JS component was edited by this cleanup; runtime module metadata was pruned. Existing user changes were preserved. Active mascot files, test fixtures and font assets were compared byte-for-byte with the pre-cleanup snapshot. Historical plans and design evidence were retained.

## Removed files

- `assets/icons/archlinux.svg`
- `Titonium/Bar/notch/CenterStyleProfile.js`
- `Titonium/Bar/islands/CenterActivationRules.js`
- `scripts/check_center_activation_rules.js`
- `Titonium/Bar/islands/CenterPigMascot.qml`
- `Titonium/Shared/EdgePillShape.qml`
- `Titonium/Bar/center/CenterSecondaryPill.qml`
- `Titonium/Notifications/NotificationPanel.qml`
- `Titonium/Bar/center/presentations/Classic/ClassicProfile.js`
- `Titonium/Bar/center/presentations/Connected/ConnectedProfile.js`
- `Titonium/Bar/center/presentations/Notch/NotchProfile.js`
- `Titonium/Bar/center/presentations/Pill/PillProfile.js`
- `Titonium/AgentApproval/qmldir`
- `Titonium/AgentApproval/AgentApprovalHost.qml`
- `Titonium/AgentApproval/AgentApprovalWindow.qml`
- `Titonium/AgentApproval/AgentApprovalCard.qml`
- `Titonium/AgentApproval/AgentApprovalToastCard.qml`
- `Titonium/Overlays/Audio/AudioPopupSurface.qml`
- `Titonium/Overlays/Bluetooth/BluetoothPopupSurface.qml`
- `Titonium/Overlays/Network/NetworkPopupSurface.qml`

## Validation

- Full `scripts/check.sh` passed before cleanup and after source/test changes, including QML component tests and the qmllint allowlist gate.
- Remaining qmldir file exports resolve. No removed component has a runtime name reference in the remaining production source; remaining test mentions are negative assertions.
- Audio geometry and Wi-Fi/Bluetooth contracts now inspect the routed Classic surfaces. Connected content coverage remains. Wi-Fi password tests retain both active styles. Bluetooth checks validate delayed, guarded focus return and reject deliberately broken lifecycle examples. Assertions requiring the disconnected secondary-pill component were removed; active Center and notification-domain checks remain.
- `git diff --check` passed.
- Foreground smoke could not validate: an instance of the configuration is already running.
- Protected acceptance ran with temporary XDG data/state/cache directories and failed because this sandbox cannot connect to Wayland/X11. Normal runtime history was not targeted.
- `hyprctl configerrors` could not access the compositor socket (Couldn't set socket timeout).

Live behavior is not certified by this pass. Re-run the live gates in the desktop session before integrating the cleanup. No speed or memory improvement is claimed.

## Recovery

Pre-cleanup snapshot (including uncommitted source): `/tmp/titonium-before-cleanup.tar.gz`. This is temporary local recovery, not a durable backup. Restore individual files selectively to avoid overwriting subsequent changes. Full removal/cache manifest: `/tmp/titonium-cleanup-summary.json`. Logs: `/tmp/titonium-cleanup-{baseline,check,smoke,protected,hypr}.log`. No commit or reset was performed.
