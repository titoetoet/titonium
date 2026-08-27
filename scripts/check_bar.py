#!/usr/bin/env python3

import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BAR = ROOT / "Titonium/Bar"
INTERACTION_ACCEPTANCE = ROOT / "scripts/workspace_interactions_acceptance.sh"


def main() -> int:
    errors: list[str] = []
    required = (
        "islands/qmldir",
        "islands/StartIsland.qml",
        "islands/CenterIsland.qml",
        "islands/CenterGroup.qml",
        "islands/EndIsland.qml",
        "islands/ConnectivityPill.qml",
        "islands/StatusPill.qml",
        "widgets/Workspaces.qml",
        "widgets/NotificationBell.qml",
        "BarVisibilityRules.js",
        "notch/qmldir",
        "notch/CenterNotchCoordinator.qml",
        "notch/CenterNotchWindow.qml",
        "notch/CenterNotchSurface.qml",
        "notch/CenterNotch.qml",
        "notch/CenterNotchRail.qml",
        "notch/CenterNotchViewport.qml",
        "notch/OverviewPage.qml",
        "notch/CenterActionButton.qml",
        "notch/ToolsPage.qml",
        "notch/SessionPage.qml",
    )
    for relative in required:
        if not (BAR / relative).is_file():
            errors.append(f"missing Bar island contract: Titonium/Bar/{relative}")

    contracts = {
        "BarHost.qml": (
            "Variants {",
            "model: ScreenPolicy.screens",
            "CenterNotchWindow {",
        ),
        "BarSurface.qml": (
            "PanelWindow {",
            "BarVisibilityRules.exclusiveZone",
            "BarVisibilityRules.shouldReveal",
            "id: edgeReveal",
            "hideDelay.restart()",
            "mask: Region {",
        ),
        "Bar.qml": ("StartIsland {", "CenterGroup {", "EndIsland {",
                    "BarLayout.centerX(root.width, centerGroup.width)",
                    "readonly property alias centerHitbox: centerGroup",
                    "readonly property bool hovered:"),
        "islands/CenterGroup.qml": (
            "CenterIsland {",
            "BarVisibilityState.togglePinned()",
            "menubar.bar_pin.pin",
            "menubar.bar_pin.autohide",
            "id: pinPill",
            "radius: Metrics.radiusLarge",
            "showFocusRing: false",
            "backgroundRadius: Metrics.radiusLarge",
            "spacing: Metrics.spacingSmall",
        ),
        "islands/qmldir": ("CenterGroup 1.0 CenterGroup.qml",),
        "islands/CenterIsland.qml": (
            "CenterNotchCoordinator.toggle",
            "CenterNotchCoordinator.ownerScreenName",
            "HyprlandService.activeWindow",
            "ApplicationService.nameForAppId",
            "CenterActivityRules.label",
            "Math.min(520",
            "Text.ElideRight",
            "maximumLineCount: 1",
            "Shared.SystemIcon",
            "Shared.Surface {",
        ),
        "islands/ConnectivityPill.qml": (
            "readonly property int fullImplicitWidth",
            "radius: Metrics.radiusLarge",
            "spacing: 0",
            "NotificationBell {",
            "id: notificationBell",
        ),
        "islands/EndIsland.qml": (
            "ConnectivityPill {",
            "StatusPill {",
            "connectivity.fullImplicitWidth",
        ),
        "islands/StatusPill.qml": ("InputMethod {",),
        "notch/CenterNotchWindow.qml": (
            "PanelWindow {",
            "Loader {",
            "active: window.ownsNotch",
            "WlrLayershell.exclusionMode: ExclusionMode.Ignore",
            "WlrLayershell.keyboardFocus:",
        ),
        "notch/CenterNotchCoordinator.qml": (
            "property bool pinned: false",
            "function togglePinned(screenName: string): bool",
            "root.pinned = false",
        ),
        "notch/CenterNotchSurface.qml": (
            "CenterNotchCoordinator.close()",
            "!CenterNotchCoordinator.pinned",
            "Keys.onEscapePressed",
            "readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing",
            "anchors.topMargin: root.panelTop",
            "root.height - root.panelTop - Metrics.barPadding",
        ),
        "notch/CenterNotchRail.qml": (
            "width: 48",
            "id: selectionHighlight",
            '"overview"',
            '"tools"',
            '"session"',
            "settingsRequested()",
        ),
        "notch/CenterNotchViewport.qml": (
            "StackView {",
            "stack.replace(",
            "stack.busy",
            "property string pendingPage",
        ),
        "notch/CenterNotch.qml": (
            "CenterNotchRail {",
            "CenterNotchViewport {",
            "Layout.preferredWidth: Metrics.borderWidth",
            "topLeftRadius: 20",
            "topRightRadius: 20",
            "bottomLeftRadius: 20",
            "bottomRightRadius: 20",
        ),
    }
    for filename, fragments in contracts.items():
        path = BAR / filename
        if not path.is_file():
            errors.append(f"missing Bar file: Titonium/Bar/{filename}")
            continue
        source = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in source:
                errors.append(f"{filename} missing direct Bar contract: {fragment}")

    metrics = (ROOT / "Titonium/Theme/Metrics.qml").read_text(encoding="utf-8")
    for fragment in (
        "readonly property int barHeight: 44",
        "readonly property int controlHeight: 36",
        "readonly property int widgetHeight: 36",
    ):
        if fragment not in metrics:
            errors.append(f"TopBar 44px geometry missing metric: {fragment}")

    connectivity = BAR / "islands/ConnectivityPill.qml"
    if connectivity.is_file():
        source = connectivity.read_text(encoding="utf-8")
        for fragment in (
            "readonly property int controlSize: 24",
            "id: networkButton",
            "id: bluetoothButton",
            "id: audioButton",
            "id: notificationBell",
            "width: root.controlSize",
            "height: root.controlSize",
        ):
            if fragment not in source:
                errors.append(f"ConnectivityPill missing aligned-control contract: {fragment}")
        if not (source.find("id: audioButton") < source.find("id: notificationBell")):
            errors.append("Notification Bell must follow Sound inside ConnectivityPill")
        if "id: networkIcon" in source:
            errors.append("ConnectivityPill must not mix a raw Wi-Fi icon with button-sized controls")

    status_pill = BAR / "islands/StatusPill.qml"
    if status_pill.is_file() and "Clock {" in status_pill.read_text(encoding="utf-8"):
        errors.append("StatusPill must keep Clock temporarily disabled")

    workspaces = BAR / "widgets/Workspaces.qml"
    if workspaces.is_file():
        source = workspaces.read_text(encoding="utf-8")
        for fragment in (
            "property int count: 5",
            "readonly property int emptySlotWidth: 24",
            "readonly property int appIconSize: 17",
            "readonly property int appSpacing: 3",
            "Math.max(36,",
            "height: workspaceItem.modelData.active ? 26 : 20",
            "opacity: workspaceItem.modelData.active ? 1.0 : 0.62",
            "Shared.SystemIcon",
            "modelData.apps",
            "workspaceColor",
            "? workspaceItem.occupiedWidth",
            "WheelHandler",
            "HyprlandService.activateWorkspace",
            "Motion.fast",
        ):
            if fragment not in source:
                errors.append(f"Workspaces missing grouped-view contract: {fragment}")
        for forbidden in (
            "Timer {", "Animation.Infinite", "loops: Animation.Infinite",
            "import Quickshell.Hyprland", "Hyprland.workspaces", "ToplevelManager",
        ):
            if forbidden in source:
                errors.append(f"Workspaces has forbidden ownership/animation: {forbidden}")
        if 'text: String(workspaceItem.modelData.id)' in source:
            errors.append("Workspaces must use dots and app icons instead of visible numbers")
        if "Theme.focus" in source:
            errors.append("Active workspace must not use the global blue focus border")

    center_group = BAR / "islands/CenterGroup.qml"
    if center_group.is_file():
        source = center_group.read_text(encoding="utf-8")
        if not (0 <= source.find("id: pinPill") < source.find("CenterIsland {")):
            errors.append("TopBar Pin must be a separate pill left of Titonium Center")
        if source.count("Shared.Surface {") != 1:
            errors.append("CenterGroup must give the detached Pin exactly one rounded surface")
        if "implicitWidth: centerRow.implicitWidth +" in source:
            errors.append("Center hover controls must meet the outer pill edge without inset padding")

    shared_button = (ROOT / "Titonium/Shared/Button.qml").read_text(encoding="utf-8")
    for fragment in (
        "property int backgroundRadius: Metrics.radiusSmall",
        "radius: root.backgroundRadius",
    ):
        if fragment not in shared_button:
            errors.append(f"Shared Button missing configurable rounded hover contract: {fragment}")

    input_method = BAR / "widgets/InputMethod.qml"
    if input_method.is_file() and "Shared.Surface" in input_method.read_text(encoding="utf-8"):
        errors.append("Input Method must not draw a nested outlined surface inside StatusPill")
    protected_hashes = {
        BAR / "widgets/InputMethod.qml": "cf88d46b009efa2748b03970a7b0e8f586b9167d95687b33cdccfbeb4ff6be61",
        ROOT / "Titonium/Services/InputMethod/InputMethodService.qml": "cb7eb04be9d6898f2b641f0b4e791e48b146b18bcb9ab8aa3c17188c29144126",
    }
    for path, expected_hash in protected_hashes.items():
        if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() != expected_hash:
            errors.append(f"notification batch changed protected Input Method: {path.relative_to(ROOT)}")

    center_island = BAR / "islands/CenterIsland.qml"
    if center_island.is_file() and center_island.read_text(encoding="utf-8").count("Shared.Surface {") != 1:
        errors.append("Titonium Center must own one rounded surface after Pin is detached")

    for relative in (
        "Overlays/Audio/AudioPopupSurface.qml",
        "Overlays/Bluetooth/BluetoothPopupSurface.qml",
        "Overlays/Network/NetworkPopupSurface.qml",
    ):
        source = (ROOT / "Titonium" / relative).read_text(encoding="utf-8")
        if "readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing" not in source:
            errors.append(f"{relative} must follow the shared TopBar height")

    for relative in ("islands/StartIsland.qml", "islands/StatusPill.qml"):
        path = BAR / relative
        if path.is_file() and "radius: Metrics.radiusLarge" not in path.read_text(encoding="utf-8"):
            errors.append(f"{relative} must use Dock-like rounded group geometry")

    if BAR.exists():
        feature = "\n".join(path.read_text(encoding="utf-8") for path in BAR.rglob("*.qml"))
        for forbidden in (
            "WidgetRegistry",
            "LayoutRenderer",
            "ConfigStore",
            "layout.json",
            "Process {",
            "Quickshell.execDetached",
            "MultiEffect",
            "ShaderEffect",
            "loops: Animation.Infinite",
            "qs.modules.",
        ):
            if forbidden in feature:
                errors.append(f"direct Bar contains forbidden dependency: {forbidden}")
        for path in BAR.rglob("*.qml"):
            source = path.read_text(encoding="utf-8")
            if "Timer {" in source and path.name != "BarSurface.qml":
                errors.append(f"direct Bar contains timer outside auto-hide boundary: {path.name}")
            if path.name == "BarSurface.qml" and "repeat: true" in source:
                errors.append("TopBar auto-hide delay must never poll")

    notch_dir = BAR / "notch"
    if notch_dir.exists():
        notch_sources = {
            path.name: path.read_text(encoding="utf-8") for path in notch_dir.rglob("*.qml")
        }
        notch_feature = "\n".join(notch_sources.values())
        if re.search(
            r"^\s*import\s+qs\.Titonium\.Services\.(Audio|Bluetooth|Network)",
            notch_feature,
            re.MULTILINE,
        ):
            errors.append("Center Notch imports a future connectivity service")
        for filename, source in notch_sources.items():
            if filename != "CenterNotchWindow.qml" and "Loader {" in source:
                errors.append(f"{filename} contains an always-resident notch Loader boundary")

    protected_acceptance = (ROOT / "scripts/protected_acceptance.sh").read_text(encoding="utf-8")
    for path_fragment in (
        "Titonium/Bar/widgets/InputMethod.qml",
        "Titonium/Services/InputMethod/InputMethodService.qml",
    ):
        if path_fragment not in protected_acceptance:
            errors.append(f"protected acceptance does not inspect new Input Method path: {path_fragment}")

    required_i18n = {
        "menubar.center_notch.accessible",
        "menubar.center_pin.open",
        "menubar.center_pin.close",
        "menubar.bar_pin.pin",
        "menubar.bar_pin.autohide",
        "menubar.connectivity.network_planned",
        "menubar.connectivity.bluetooth_planned",
        "menubar.connectivity.audio_planned",
        "notification.bell.none",
        "notification.bell.unread",
        "center_notch.title",
        "center_notch.tab.overview",
        "center_notch.tab.tools",
        "center_notch.tab.session",
        "center_notch.tab.settings",
        "center_notch.settings.unavailable",
        "center_notch.overview.description",
        "center_notch.overview.layout",
        "center_notch.overview.keyboard",
        "center_notch.overview.lazy",
        "center_notch.overview.solid",
        "center_notch.action.unavailable",
        "center_notch.tools.title",
        "center_notch.session.title",
    }
    required_i18n.update({
        "center_notch.action." + action_id for action_id in (
            "screenshot", "screen-recording", "color-picker", "ocr", "qr-scan",
            "camera-mirror", "night-mode", "more-tools", "lock", "logout",
            "sleep", "hibernate", "restart", "shutdown",
        )
    })
    for locale in ("en", "vi"):
        catalog = json.loads((ROOT / f"config/i18n/{locale}.json").read_text(encoding="utf-8"))
        missing = sorted(required_i18n - set(catalog.get("strings", {})))
        for key in missing:
            errors.append(f"{locale} catalog missing Bar key: {key}")

    for relative in ("notch/ToolsPage.qml", "notch/SessionPage.qml"):
        path = BAR / relative
        if not path.is_file():
            continue
        source = path.read_text(encoding="utf-8")
        for forbidden in ("Process", "execDetached", "FileView", "callback", "executable"):
            if forbidden in source:
                errors.append(f"{relative} contains executable mock boundary: {forbidden}")
        if re.search(r"\b(command|process|script)\s*:", source, re.IGNORECASE):
            errors.append(f"{relative} contains command-like property")
        if re.search(r"^\s*import\s+qs\.Titonium\.Services", source, re.MULTILINE):
            errors.append(f"{relative} imports a service from a mock page")

    app_path = ROOT / "Titonium/App.qml"
    if app_path.is_file():
        app_source = app_path.read_text(encoding="utf-8")
        for fragment in (
            'target: "centerNotch"',
            "CenterNotchCoordinator.close()",
            "function open(page: string): string",
            "function page(page: string): string",
            "function close(): string",
            "function state(): string",
        ):
            if fragment not in app_source:
                errors.append(f"App missing Center Notch lifecycle contract: {fragment}")

    check_sh = (ROOT / "scripts/check.sh").read_text(encoding="utf-8")
    protected_source = (ROOT / "scripts/protected_acceptance.sh").read_text(encoding="utf-8")
    acceptance_registration = 'bash -n "$project_root/scripts/workspace_interactions_acceptance.sh"'
    if acceptance_registration not in check_sh:
        errors.append("check.sh missing workspace interaction acceptance syntax gate")
    if '"$project_root/scripts/workspace_interactions_acceptance.sh"' not in protected_source:
        errors.append("protected acceptance missing workspace interaction gate")
    if not INTERACTION_ACCEPTANCE.is_file():
        errors.append("missing scripts/workspace_interactions_acceptance.sh")
    else:
        acceptance_source = INTERACTION_ACCEPTANCE.read_text(encoding="utf-8")
        for fragment in (
            "Configuration Loaded",
            "Illegal method name",
            "Type .* unavailable",
            "hyprctl -j layers",
            "centerNotch open overview",
            "centerNotch close",
            "window-switcher state",
            "dock state",
        ):
            if fragment not in acceptance_source:
                errors.append(f"workspace acceptance missing contract: {fragment}")
        for forbidden in (
            "bluetoothctl", "wpctl set", "clipboard set", "application launch",
            "window-switcher accept", "activateWorkspace",
        ):
            if forbidden in acceptance_source:
                errors.append(f"workspace acceptance contains mutating boundary: {forbidden}")

    if errors:
        print("FAIL direct Bar contract")
        print("\n".join(errors))
        return 1
    print("PASS direct Bar contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
