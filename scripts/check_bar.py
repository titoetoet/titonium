#!/usr/bin/env python3

import hashlib
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BAR = ROOT / "Titonium/Bar"
INTERACTION_ACCEPTANCE = ROOT / "scripts/workspace_interactions_acceptance.sh"


def main() -> int:
    errors: list[str] = []
    required = (
        "islands/qmldir",
        "islands/StartIsland.qml",
        "islands/ArchLogo.qml",
        "assets/arch-prism.svg",
        "islands/ActiveWindowPill.qml",
        "islands/CenterIsland.qml",
        "islands/CenterGroup.qml",
        "islands/TopbarPin.qml",
        "islands/EndIsland.qml",
        "islands/NotificationPill.qml",
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
        "notch/CenterNotchViewport.qml",
        "notch/OverviewPage.qml",
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
            "Region { item: bar.notificationHitbox }",
        ),
        "Bar.qml": ("StartIsland {", "CenterGroup {", "EndIsland {",
                    "NotificationPill {", "id: notificationPill",
                    "x: centerGroup.x + centerGroup.width + Metrics.spacingSmall",
                    "BarLayout.centerX(root.width, centerGroup.width)",
                    "readonly property alias centerHitbox: centerGroup",
                    "readonly property alias notificationHitbox: notificationPill",
                    "signal centerRequested(var screen)",
                    "readonly property bool hovered:"),
        "islands/CenterGroup.qml": (
            "CenterIsland {",
            "id: centerIsland",
            "signal notchRequested(var screen)",
            "onNotchRequested: screen => root.notchRequested(screen)",
        ),
        "islands/CenterIsland.qml": (
            "CenterFocusStore.text",
            'I18n.tr("menubar.center.focus_fallback")',
            "strong: true",
            "Behavior on implicitWidth",
            "Behavior on implicitHeight",
            "easing.bezierCurve: [0.34, 1.22, 0.64, 1, 1, 1]",
            "readonly property string presentationKey:",
            "const fullTransition = root.displayedPresentationKey !== root.presentationKey",
            "root.sizeMorphEnabled = fullTransition && !Motion.reduced",
            "id: presentationFade",
            "duration: 160",
            "scale: root.notchOpen ? 0.97 : 1",
        ),
        "islands/TopbarPin.qml": (
            "BarVisibilityState.togglePinned()",
            "menubar.bar_pin.pin", "menubar.bar_pin.autohide",
            "radius: Metrics.radiusLarge", "showFocusRing: false",
            "backgroundRadius: Metrics.radiusLarge",
        ),
        "islands/qmldir": (
            "ArchLogo 1.0 ArchLogo.qml",
            "ActiveWindowPill 1.0 ActiveWindowPill.qml",
            "CenterIsland 1.0 CenterIsland.qml",
            "CenterGroup 1.0 CenterGroup.qml",
            "TopbarPin 1.0 TopbarPin.qml",
            "NotificationPill 1.0 NotificationPill.qml",
        ),
        "islands/ActiveWindowPill.qml": (
            "CenterNotchCoordinator.toggle",
            "CenterNotchCoordinator.ownerScreenName",
            "HyprlandService.activeWindow",
            "ApplicationService.nameForAppId",
            "ActiveWindowRules.label",
            "implicitWidth: Math.min(520",
            "activityRow.implicitWidth",
            "readonly property var presentation:",
            "id: appNameLabel",
            "Layout.maximumWidth: 120",
            "id: activityDot",
            'text: "·"',
            "id: titleLabel",
            "outlined: false",
            "Text.ElideRight",
            "maximumLineCount: 1",
            "Shared.SystemIcon",
            "Shared.Surface {",
        ),
        "islands/ConnectivityPill.qml": (
            "readonly property int fullImplicitWidth",
            "radius: Metrics.radiusLarge",
            "spacing: 0",
        ),
        "islands/NotificationPill.qml": (
            "NotificationBell {",
            "id: notificationBell",
            "Shared.Surface {",
            "radius: Metrics.radiusLarge",
            "implicitHeight: Metrics.widgetHeight",
            "visible: NotificationService.hasUnread",
            "signal notificationsRequested()",
        ),
        "islands/EndIsland.qml": (
            "TopbarPin {",
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
            "readonly property bool dismissing:",
            "active: window.ownsNotch || window.dismissing",
            "closeRequested: window.dismissing",
            "Region { item: activeInputRegion }",
            "width: window.ownsNotch ? window.width : 0",
        ),
        "notch/CenterNotchCoordinator.qml": (
            "property bool pinned: false",
            "property string exitingScreenName:",
            "function finishClose(screenName: string): void",
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
            "id: notchEntrance",
            "Approved cubic baseline (2026-09-03)",
            "from: 0.93",
            "from: -14",
            "PauseAnimation { duration: 30 }",
            "id: notchExit",
            "onFinished: root.closeAnimationFinished()",
        ),
        "notch/CenterNotch.qml": (
            "CenterNotchViewport {",
            "requestedPage: CenterNotchCoordinator.requestedPage",
            "topLeftRadius: 20",
            "topRightRadius: 20",
            "bottomLeftRadius: 20",
            "bottomRightRadius: 20",
            "property bool entranceRequested:",
            "id: contentEntranceOffset",
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
            "width: root.controlSize",
            "height: root.controlSize",
        ):
            if fragment not in source:
                errors.append(f"ConnectivityPill missing aligned-control contract: {fragment}")
        if "NotificationBell {" in source or "notificationBell" in source:
            errors.append("Notification Bell must live in its own pill outside ConnectivityPill")
        if "id: networkIcon" in source:
            errors.append("ConnectivityPill must not mix a raw Wi-Fi icon with button-sized controls")
        if source.count("showFocusRing: false") != 3:
            errors.append("Connectivity controls must not retain a blue focus ring after pointer activation")

    end_island = BAR / "islands/EndIsland.qml"
    if end_island.is_file():
        source = end_island.read_text(encoding="utf-8")
        pin_index = source.find("TopbarPin {")
        connectivity_index = source.find("ConnectivityPill {")
        status_index = source.find("StatusPill {")
        if not (0 <= pin_index < connectivity_index < status_index):
            errors.append("EndIsland order must be Pin, Connectivity, then Input")

    status_pill = BAR / "islands/StatusPill.qml"
    if status_pill.is_file() and "Clock {" in status_pill.read_text(encoding="utf-8"):
        errors.append("StatusPill must keep Clock temporarily disabled")

    workspaces = BAR / "widgets/Workspaces.qml"
    if workspaces.is_file():
        source = workspaces.read_text(encoding="utf-8")
        for fragment in (
            "readonly property int count: Preferences.bar.workspaceCount",
            "readonly property int emptySlotWidth: 24",
            "readonly property int appIconSize: 17",
            "readonly property int appSpacing: 3",
            "WorkspaceVisualRules.occupiedWidth",
            "WorkspaceVisualRules.pillHeight",
            "WorkspaceVisualRules.slotHeight",
            "Theme.workspacePalette",
            "Theme.workspaceActivePalette[0]",
            "opacity: workspaceItem.modelData.active ? 1.0 : 0.76",
            "Shared.SystemIcon",
            "modelData.apps",
            "workspaceColor",
            "? workspaceItem.occupiedWidth",
            "WheelHandler",
            "HyprlandService.activateWorkspace",
            "Motion.fast",
            "hoverHandler.hovered",
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

    active_window_pill = BAR / "islands/ActiveWindowPill.qml"
    if active_window_pill.is_file():
        source = active_window_pill.read_text(encoding="utf-8")
        if "implicitWidth: 420" in source:
            errors.append("Active Window must size naturally instead of retaining a fixed width")
        if "id: activitySeparator" in source or "Layout.preferredWidth: 120" in source:
            errors.append("Center app content must sit naturally beside its title without a divider gap")

    start_island = BAR / "islands/StartIsland.qml"
    if start_island.is_file():
        source = start_island.read_text(encoding="utf-8")
        if not (0 <= source.find("ArchLogo {") < source.find("Workspaces {")
                < source.find("ActiveWindowPill {")):
            errors.append("Arch logo, Workspaces and Active Window must retain StartIsland order")
        if "CenterIsland {" in source:
            errors.append("StartIsland must not use CenterIsland for Active Window")
        if "count: 5" in source:
            errors.append("StartIsland must not override the effective workspace count")

    arch_logo = BAR / "islands/ArchLogo.qml"
    arch_asset = BAR / "assets/arch-prism.svg"
    if arch_logo.is_file():
        source = arch_logo.read_text(encoding="utf-8")
        for fragment in ("Image {", "arch-prism.svg", "width: Metrics.widgetHeight"):
            if fragment not in source:
                errors.append(f"ArchLogo missing visual contract: {fragment}")
        for forbidden in ("MouseArea", "TapHandler", "onClicked"):
            if forbidden in source:
                errors.append(f"decorative ArchLogo owns interaction: {forbidden}")
    if arch_asset.is_file():
        try:
            svg_root = ET.parse(arch_asset).getroot()
            if svg_root.attrib.get("viewBox") != "0 0 64 64":
                errors.append("Arch Prism SVG must use the canonical 64px vector viewBox")
        except ET.ParseError as error:
            errors.append(f"Arch Prism SVG is invalid XML: {error}")

    center_group = BAR / "islands/CenterGroup.qml"
    if center_group.is_file():
        source = center_group.read_text(encoding="utf-8")
        for forbidden in ("BarVisibilityState", "pinPill", "keep_off", "menubar.bar_pin"):
            if forbidden in source:
                errors.append(f"CenterGroup must not own detached Pin behavior: {forbidden}")

    center_island = BAR / "islands/CenterIsland.qml"
    if center_island.is_file():
        source = center_island.read_text(encoding="utf-8")
        for fragment in (
            "CenterAttentionService.presentation",
            "CenterFocusStore.text",
            'I18n.tr("menubar.center.focus_fallback")',
            "signal notchRequested(var screen)",
            "Text.ElideRight",
            "maximumLineCount: 1",
            "Layout.maximumWidth: 320",
            "implicitHeight: Metrics.controlHeight",
            "Shared.Surface {",
            "CenterPresentationRules.leadingIcon(",
            "readonly property string leadingIcon:",
            "TapHandler {",
            "menubar.center_notch.accessible",
        ):
            if fragment not in source:
                errors.append(f"CenterIsland missing attention-view contract: {fragment}")
        for forbidden in (
            "HyprlandService",
            "ApplicationService",
            "NotificationService",
            "AudioService",
            "activeWindow",
            "window.title",
            "Timer {",
            "Process {",
            "FileView {",
            "ShaderEffect",
            "loops: Animation.Infinite",
            "CenterFocusStore.openScratchpad()",
        ):
            if forbidden in source:
                errors.append(f"CenterIsland has forbidden ownership: {forbidden}")

    shared_button = (ROOT / "Titonium/Shared/Button.qml").read_text(encoding="utf-8")
    for fragment in (
        "property int backgroundRadius: Metrics.radiusSmall",
        "radius: root.backgroundRadius",
    ):
        if fragment not in shared_button:
            errors.append(f"Shared Button missing configurable rounded hover contract: {fragment}")

    input_method = BAR / "widgets/InputMethod.qml"
    if input_method.is_file():
        input_source = input_method.read_text(encoding="utf-8")
        if "Shared.Surface" in input_source:
            errors.append("Input Method must not draw a nested outlined surface inside StatusPill")
        for fragment in (
            "readonly property string keyboardIcon:",
            "InputMethodService.vietnamese",
            '"local_florist"',
            "InputMethodService.english",
            '"keyboard_off"',
            "name: root.keyboardIcon",
        ):
            if fragment not in input_source:
                errors.append(f"Input Method missing icon-only language contract: {fragment}")
        if "Shared.TextLabel" in input_source or "InputMethodService.shortLabel" in input_source:
            errors.append("Input Method must not retain a visible VI/EN text label")
    protected_hashes = {
        ROOT / "Titonium/Services/InputMethod/InputMethodService.qml": "40b22ba52162342aa4cbd0e00a17f90879c1c8446149fb15f5f90d417010e8cb",
    }
    for path, expected_hash in protected_hashes.items():
        if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() != expected_hash:
            errors.append(f"notification batch changed protected Input Method: {path.relative_to(ROOT)}")

    active_window_pill = BAR / "islands/ActiveWindowPill.qml"
    if active_window_pill.is_file() and active_window_pill.read_text(encoding="utf-8").count("Shared.Surface {") != 1:
        errors.append("Active Window must own one rounded surface after Pin is detached")

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
        "menubar.center_notch.active",
        "menubar.center_notch.desktop",
        "menubar.center_pin.open",
        "menubar.center_pin.close",
        "menubar.bar_pin.pin",
        "menubar.bar_pin.autohide",
        "menubar.center.focus_fallback",
        "menubar.center.accessible",
        "menubar.center.scratchpad_open_failed",
        "menubar.center.indicator.media",
        "menubar.center.indicator.timer",
        "menubar.center.indicator.jobs",
        "menubar.connectivity.network_planned",
        "menubar.connectivity.bluetooth_planned",
        "menubar.connectivity.audio_planned",
        "notification.bell.none",
        "notification.bell.unread",
        "center_notch.title",
        "center_notch.tab.overview",
        "center_notch.overview.description",
        "center_notch.overview.daily_focus",
        "center_notch.overview.daily_focus.open",
        "center_notch.overview.layout",
        "center_notch.overview.keyboard",
        "center_notch.overview.lazy",
        "center_notch.overview.solid",
    }
    for locale in ("en", "vi"):
        catalog = json.loads((ROOT / f"config/i18n/{locale}.json").read_text(encoding="utf-8"))
        missing = sorted(required_i18n - set(catalog.get("strings", {})))
        for key in missing:
            errors.append(f"{locale} catalog missing Bar key: {key}")

    notch_contracts = (
        (ROOT / "Titonium/Orchestration/SurfaceRouter.qml", (
            "function openCenterNotch(requestedScreen: var, pageId: string): string",
            "SettingsCoordinator.forceCancelAndClose()",
            "CenterNotchCoordinator.close()",
        )),
        (ROOT / "Titonium/App.qml", (
            "onCenterRequested: screen => router.openCenterNotch(screen, \"overview\")",
        )),
        (ROOT / "Titonium/Ipc/CoreIpc.qml", (
            'target: "centerNotch"',
            "function open(page: string): string",
            "function page(page: string): string",
            "function close(): string",
            "function state(): string",
        )),
    )
    for path, fragments in notch_contracts:
        source = path.read_text(encoding="utf-8") if path.is_file() else ""
        for fragment in fragments:
            if fragment not in source:
                errors.append(f"Center Notch owner missing contract: {path.relative_to(ROOT)}: {fragment}")

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
