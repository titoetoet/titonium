#!/usr/bin/env python3

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BAR = ROOT / "Titonium/Bar"


def main() -> int:
    errors: list[str] = []
    required = (
        "islands/qmldir",
        "islands/StartIsland.qml",
        "islands/CenterIsland.qml",
        "islands/EndIsland.qml",
        "islands/ConnectivityPill.qml",
        "islands/StatusPill.qml",
        "notch/qmldir",
        "notch/CenterNotchCoordinator.qml",
        "notch/CenterNotchWindow.qml",
        "notch/CenterNotchSurface.qml",
        "notch/CenterNotch.qml",
        "notch/CenterNotchRail.qml",
        "notch/CenterNotchViewport.qml",
        "notch/OverviewPage.qml",
    )
    for relative in required:
        if not (BAR / relative).is_file():
            errors.append(f"missing Bar island contract: Titonium/Bar/{relative}")

    contracts = {
        "BarHost.qml": (
            "Variants {",
            "model: Quickshell.screens",
            "CenterNotchWindow {",
        ),
        "BarSurface.qml": ("PanelWindow {", "exclusiveZone: 40", "mask: Region {"),
        "Bar.qml": ("StartIsland {", "CenterIsland {", "EndIsland {", "BarLayout.centerX"),
        "islands/CenterIsland.qml": (
            "CenterNotchCoordinator.toggle",
            "CenterNotchCoordinator.ownerScreenName",
        ),
        "islands/ConnectivityPill.qml": ("readonly property int fullImplicitWidth",),
        "islands/EndIsland.qml": (
            "ConnectivityPill {",
            "StatusPill {",
            "connectivity.fullImplicitWidth",
        ),
        "islands/StatusPill.qml": ("InputMethod {", "Clock {"),
        "notch/CenterNotchWindow.qml": (
            "PanelWindow {",
            "Loader {",
            "active: window.ownsNotch",
            "WlrLayershell.exclusionMode: ExclusionMode.Ignore",
            "WlrLayershell.keyboardFocus:",
        ),
        "notch/CenterNotchSurface.qml": (
            "CenterNotchCoordinator.close()",
            "Keys.onEscapePressed",
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

    if BAR.exists():
        feature = "\n".join(path.read_text(encoding="utf-8") for path in BAR.rglob("*.qml"))
        for forbidden in (
            "WidgetRegistry",
            "LayoutRenderer",
            "ConfigStore",
            "layout.json",
            "Process {",
            "Timer {",
            "Quickshell.execDetached",
            "MultiEffect",
            "ShaderEffect",
            "qs.modules.",
        ):
            if forbidden in feature:
                errors.append(f"direct Bar contains forbidden dependency: {forbidden}")

    protected_acceptance = (ROOT / "scripts/protected_acceptance.sh").read_text(encoding="utf-8")
    for path_fragment in (
        "Titonium/Bar/widgets/InputMethod.qml",
        "Titonium/Services/InputMethod/InputMethodService.qml",
    ):
        if path_fragment not in protected_acceptance:
            errors.append(f"protected acceptance does not inspect new Input Method path: {path_fragment}")

    required_i18n = {
        "menubar.center_notch.accessible",
        "menubar.connectivity.network_planned",
        "menubar.connectivity.bluetooth_planned",
        "menubar.connectivity.audio_planned",
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
    }
    for locale in ("en", "vi"):
        catalog = json.loads((ROOT / f"config/i18n/{locale}.json").read_text(encoding="utf-8"))
        missing = sorted(required_i18n - set(catalog.get("strings", {})))
        for key in missing:
            errors.append(f"{locale} catalog missing Bar key: {key}")

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

    if errors:
        print("FAIL direct Bar contract")
        print("\n".join(errors))
        return 1
    print("PASS direct Bar contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
