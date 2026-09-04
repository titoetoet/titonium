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
        "islands/TopbarPin.qml",
        "islands/EndIsland.qml",
        "islands/ConnectivityPill.qml",
        "islands/StatusPill.qml",
        "widgets/Workspaces.qml",
        "BarVisibilityRules.js",
        "notch/qmldir",
        "notch/CenterNotchCoordinator.qml",
        "notch/CenterPillWindow.qml",
        "notch/CenterNotchSurface.qml",
        "notch/CenterNotch.qml",
        "right/RightPillCoordinator.qml",
        "right/EdgeMenuWindow.qml",
        "right/EdgeMenuSurface.qml",
    )
    for relative in required:
        if not (BAR / relative).is_file():
            errors.append(f"missing Bar island contract: Titonium/Bar/{relative}")

    contracts = {
        "BarHost.qml": (
            "Variants {",
            "model: ScreenPolicy.screens",
            "CenterPillWindow {",
            "EdgeMenuWindow {",
        ),
        "BarSurface.qml": (
            "PanelWindow {",
            "BarVisibilityRules.exclusiveZone",
            "BarVisibilityRules.shouldReveal",
            "id: edgeReveal",
            "hideDelay.restart()",
            "mask: Region {",
            "Region { item: root.connectedLeftHitbox }",
            "Region { item: root.connectedRightHitbox }",
            "Region { item: root.classicArchHitbox }",
            "Region { item: root.classicWorkspaceHitbox }",
            "Region { item: root.classicActiveWindowHitbox }",
            "Region { item: root.classicPinHitbox }",
            "Region { item: root.classicConnectivityHitbox }",
            "Region { item: root.classicStatusHitbox }",
            "active: RightPillCoordinator.presentedStyle === \"connected\"",
            "active: RightPillCoordinator.presentedStyle === \"classic\"",
            "CenterNotchCoordinator.active",
        ),
        "Bar.qml": ("id: leftReservation", "id: rightReservation",
                    "readonly property alias leftHitbox:",
                    "readonly property alias rightHitbox:",
                    "StartIsland {", "EndIsland {",
                    "RightPillCoordinator.leftCompactWidth",
                    "RightPillCoordinator.compactWidth",
                    "CenterNotchCoordinator.islandWidth",
                    "signal centerRequested(var screen)",
                    "readonly property bool hovered:"),
        "islands/CenterIsland.qml": (
            "CenterFocusStore.text",
            'I18n.tr("menubar.center.focus_fallback")',
            "strong: true",
            "CenterNotchCoordinator.setCompactWidth(root.implicitWidth)",
            "readonly property string presentationKey:",
            "const fullTransition = root.displayedPresentationKey !== root.presentationKey",
            "id: presentationFade",
            "duration: 160",
        ),
        "islands/TopbarPin.qml": (
            "BarVisibilityState.togglePinned()",
            "menubar.bar_pin.pin", "menubar.bar_pin.autohide",
            "showFocusRing: false",
            "backgroundRadius: Metrics.radiusLarge",
            "backgroundVisible: false",
        ),
        "islands/qmldir": (
            "ArchLogo 1.0 ArchLogo.qml",
            "ActiveWindowPill 1.0 ActiveWindowPill.qml",
            "CenterIsland 1.0 CenterIsland.qml",
            "TopbarPin 1.0 TopbarPin.qml",
        ),
        "islands/ActiveWindowPill.qml": (
            "CenterNotchCoordinator.openExpanded",
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
            "Text.ElideRight",
            "maximumLineCount: 1",
            "Shared.SystemIcon",
            "id: activeAppIcon",
            "centerHover.hovered ? 1.08 : 1",
        ),
        "islands/ConnectivityPill.qml": (
            "readonly property int fullImplicitWidth",
            "implicitWidth: root.fullImplicitWidth",
            "spacing: Metrics.spacingXSmall",
        ),
        "islands/EndIsland.qml": (
            "TopbarPin {",
            "ConnectivityPill {",
            "StatusPill {",
            "readonly property int preferredWidth: endRow.implicitWidth",
            "NotificationBell {",
            "spacing: Metrics.spacingSmall",
            "anchors.right: parent.right",
        ),
        "islands/StatusPill.qml": ("InputMethod {",),
        "notch/CenterPillWindow.qml": (
            "PanelWindow {",
            "CenterNotchSurface {",
            "property string styleName:",
            "visible: true",
            "WlrLayershell.exclusionMode: ExclusionMode.Ignore",
            "WlrLayershell.keyboardFocus:",
            "readonly property bool dismissing:",
            "closeRequested: window.dismissing",
            "Region { item: activeInputRegion }",
            "Region { item: compactInputRegion }",
        ),
        "notch/CenterNotchCoordinator.qml": (
            "property string exitingScreenName:",
            "function finishClose(screenName: string): void",
            "function openBanner(screenName: string, context: var): bool",
            "function openExpanded(screenName: string): bool",
            "function finishDrag(offset: real, velocity: real): var",
            "function completeDragSettle(targetState: string): void",
            "property real dragProgress: 0",
        ),
        "notch/CenterNotchSurface.qml": (
            "CenterNotchCoordinator.collapse()",
            "Keys.onEscapePressed",
            "readonly property real bannerWidth: 480",
            "readonly property real expandedWidth:",
            "readonly property real targetHeight:",
            "readonly property real targetRadius:",
            "property real transitionProgress:",
            "readonly property real compactContentOpacity:",
            "readonly property real openContentOpacity:",
            "Shared.ConnectedPillShape {",
            "bodyWidth: islandBody.width",
            "bodyHeight: islandBody.height",
            "CenterIsland {",
            "id: nestedSatellite",
            "property bool satellitePresented:",
            "trailingReservedWidth: root.satellitePresented ? 44 : 0",
            "CenterNotchState.connectedBodyWidth(",
            "root.closeAnimationFinished();",
        ),
        "notch/CenterNotch.qml": (
            "readonly property bool isBanner:",
            "id: bannerLayer",
            'I18n.tr("center_notch.canvas.title")',
            "property bool entranceRequested:",
            "property real canvasContentProgress:",
            "DragHandler",
            "signal dragFinished(real offset, real velocity)",
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
            "readonly property int controlSize: 28",
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
        notification_index = source.find("NotificationBell {")
        status_index = source.find("StatusPill {")
        if not (0 <= notification_index < status_index < pin_index < connectivity_index):
            errors.append("EndIsland order must be Notification, Input, Pin, then Connectivity")

    for shell_name in ("StartIsland.qml", "EndIsland.qml"):
        source = (BAR / "islands" / shell_name).read_text(encoding="utf-8")
        if "Shared.EdgePillShape {" in source:
            errors.append(f"{shell_name} must remain presentation-only")
        if "Shared.Surface {" in source:
            errors.append(f"{shell_name} must not layer a card beneath its edge pill shape")
    for child_name in (
        "ArchLogo.qml", "ActiveWindowPill.qml", "TopbarPin.qml",
        "ConnectivityPill.qml", "StatusPill.qml",
    ):
        source = (BAR / "islands" / child_name).read_text(encoding="utf-8")
        if "Shared.Surface {" in source:
            errors.append(f"{child_name} must not draw a detached nested surface")

    notification_bell = BAR / "widgets/NotificationBell.qml"
    if not notification_bell.is_file():
        errors.append("missing conditional Top Bar NotificationBell")
    else:
        source = notification_bell.read_text(encoding="utf-8")
        for fragment in (
            "visible: NotificationService.hasUnread",
            "NotificationService.unreadCount",
            "function onUnreadCountChanged()",
            "loops: 3",
            "CenterNotchCoordinator.openBanner",
            "Motion.reduced",
        ):
            if fragment not in source:
                errors.append(f"NotificationBell missing transient contract: {fragment}")

    topbar_motion_sources = {
        "TopbarPin.qml": 1,
        "ConnectivityPill.qml": 3,
    }
    for child_name, expected_count in topbar_motion_sources.items():
        source = (BAR / "islands" / child_name).read_text(encoding="utf-8")
        if source.count("iconHoverMotion: true") != expected_count:
            errors.append(f"{child_name} must opt each interactive icon into icon-only hover motion")

    status_pill = BAR / "islands/StatusPill.qml"
    if status_pill.is_file() and "Clock {" in status_pill.read_text(encoding="utf-8"):
        errors.append("StatusPill must keep Clock temporarily disabled")

    input_method = BAR / "widgets/InputMethod.qml"
    if input_method.is_file():
        source = input_method.read_text(encoding="utf-8")
        for fragment in ("id: inputHover", "hoverEnabled: true", "inputHover.containsMouse ? 1.08 : 1"):
            if fragment not in source:
                errors.append(f"InputMethod missing icon-only hover motion: {fragment}")

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
            "Theme.workspaceActivePalette[0]",
            "readonly property color inactiveColor:",
            "Shared.SystemIcon",
            "modelData.apps",
            "hoverHandler.hovered ? 1.08 : 1",
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
        for fragment in ("id: logoImage", "logoHover.hovered ? 1.08 : 1"):
            if fragment not in source:
                errors.append(f"ArchLogo missing icon-only hover motion: {fragment}")
        if "scale: root.hovered" in source:
            errors.append("ArchLogo must not scale its entire control on hover")
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

    center_island = BAR / "islands/CenterIsland.qml"
    if center_island.is_file():
        source = center_island.read_text(encoding="utf-8")
        for forbidden in (
            "anticipationScale",
            "scale: root.notchOpen ? 0.97 : 1",
            "scale: (root.notchOpen ? 0.97 : 1)",
        ):
            if forbidden in source:
                errors.append(f"Center compact content must not scale on open: {forbidden}")
        for fragment in (
            "CenterAttentionService.presentation",
            "CenterFocusStore.text",
            'I18n.tr("menubar.center.focus_fallback")',
            "signal notchRequested(var screen)",
            "Text.ElideRight",
            "maximumLineCount: 1",
            "Layout.fillWidth: true",
            "Layout.minimumWidth: 0",
            "clip: true",
            "implicitHeight: root.forcedHeight",
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

    for relative in (
        "Overlays/Audio/AudioPopupSurface.qml",
        "Overlays/Bluetooth/BluetoothPopupSurface.qml",
        "Overlays/Network/NetworkPopupSurface.qml",
    ):
        source = (ROOT / "Titonium" / relative).read_text(encoding="utf-8")
        if "readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing" not in source:
            errors.append(f"{relative} must follow the shared TopBar height")

    bar_source = (BAR / "Bar.qml").read_text(encoding="utf-8")
    if "x: 0" not in bar_source:
        errors.append("StartIsland must attach directly to the left screen edge")
    if "x: root.width - width" not in bar_source:
        errors.append("Right Pill reservation must attach directly to the right screen edge")
    if bar_source.count("anchors.top: parent.top") < 2:
        errors.append("Both edge pills must attach directly to the top screen edge")

    edge_shape = ROOT / "Titonium/Shared/EdgePillShape.qml"
    if not edge_shape.is_file():
        errors.append("missing Shared/EdgePillShape.qml")
    else:
        source = edge_shape.read_text(encoding="utf-8")
        for fragment in (
            'property string edge: "left"',
            'readonly property bool leftEdge: root.edge === "left"',
            "ShapePath {",
            "PathCubic {",
            "preferredRendererType: Shape.CurveRenderer",
        ):
            if fragment not in source:
                errors.append(f"EdgePillShape missing geometry contract: {fragment}")

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
            if "Timer {" in source and path.name not in ("BarSurface.qml", "CenterNotchCoordinator.qml"):
                errors.append(f"direct Bar contains timer outside auto-hide boundary: {path.name}")
            if path.name == "CenterNotchCoordinator.qml" and "repeat: true" in source:
                errors.append("Dynamic Island notification timeout must be one-shot")
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
            if "Loader {" in source:
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
        "menubar.center.indicator.media",
        "menubar.center.indicator.timer",
        "menubar.center.indicator.jobs",
        "menubar.connectivity.network_planned",
        "menubar.connectivity.bluetooth_planned",
        "menubar.connectivity.audio_planned",
        "center_notch.canvas.title",
        "center_notch.canvas.description",
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
