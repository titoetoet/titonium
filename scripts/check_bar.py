#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(relative, errors):
    path = ROOT / relative
    if not path.is_file():
        errors.append(f"missing Bar contract file: {relative}")
        return ""
    return path.read_text(encoding="utf-8")

def require(source, relative, fragments, errors):
    for fragment in fragments:
        if fragment not in source:
            errors.append(f"{relative} missing contract: {fragment}")

def main():
    errors = []
    host = read("Titonium/Bar/BarHost.qml", errors)
    bar = read("Titonium/Bar/Bar.qml", errors)
    surface = read("Titonium/Bar/BarSurface.qml", errors)
    controller = read("Titonium/Core/Surfaces/Center/CenterSurfaceController.qml", errors)
    center_host = read("Titonium/Core/Surfaces/Center/CenterSurfaceHost.qml", errors)
    compact = read("Titonium/Core/Surfaces/Center/CenterCompactWindow.qml", errors)
    overlay = read("Titonium/Core/Surfaces/Center/CenterOverlayWindow.qml", errors)
    renderer = read("Titonium/Bar/center/CenterRenderer.qml", errors)
    connected = read("Titonium/Bar/center/presentations/Connected/ConnectedRenderer.qml", errors)
    router = read("Titonium/Orchestration/SurfaceRouter.qml", errors)
    require(host, "BarHost.qml", ("Variants {", "model: ScreenPolicy.screens", "BarSurface {",
        "CenterSurfaceHost {", "profile: CenterPresentationRules.profile(RightPillCoordinator.presentedStyle)"), errors)
    require(bar, "Bar.qml", ("StartIsland {", "EndIsland {", "BarLayout.centerX"), errors)
    require(surface, "BarSurface.qml", ("RightPillCoordinator.presentedStyle === \"connected\"",
        "RightPillCoordinator.presentedStyle === \"classic\"", "CenterSurfaceController.active"), errors)
    require(controller, "CenterSurfaceController.qml", ("readonly property var viewState",
        "function dispatch(intent: var): var", "CenterDomain.dispatch", "CenterSurfaceState.transition"), errors)
    require(center_host, "CenterSurfaceHost.qml", ("CenterCompactWindow {", "CenterOverlayWindow {",
        "CenterDomain.snapshot"), errors)
    require(compact, "CenterCompactWindow.qml", ("PanelWindow {",
        "WlrLayershell.keyboardFocus: WlrKeyboardFocus.None", "renderer.interactiveBounds"), errors)
    require(overlay, "CenterOverlayWindow.qml", ("PanelWindow {",
        "window.viewState.focusPolicy === \"exclusive\"", "renderer.visualBounds",
        "CenterSurfaceController.finishClose"), errors)
    require(renderer, "CenterRenderer.qml", ("Pill.PillRenderer", "Notch.NotchRenderer",
        "Connected.ConnectedRenderer", "Classic.ClassicRenderer"), errors)
    require(connected, "ConnectedRenderer.qml", ("required property var snapshot",
        "required property var viewState", "required property var profile",
        "signal intentRequested(var intent)", "type: \"invoke-action\""), errors)
    require(router, "SurfaceRouter.qml", ("function openCenter(", "function presentCenterBanner(",
        "function closeCenter("), errors)
    for relative in ("Titonium/Bar/islands/CenterIsland.qml",
            "Titonium/Bar/notch/CenterNotchCoordinator.qml",
            "Titonium/Bar/notch/CenterPillWindow.qml",
            "Titonium/Bar/notch/CenterNotchSurface.qml", "Titonium/Bar/notch/CenterNotch.qml"):
        if (ROOT / relative).exists():
            errors.append(f"legacy Center ownership remains: {relative}")
    for path in (ROOT / "Titonium/Bar/center/presentations").rglob("*.qml"):
        source = path.read_text(encoding="utf-8")
        for forbidden in ("Services.Capture", "Services.Mpris", "Services.Notifications",
                "Services.AgentApproval", "Services.Center", "Process {", "FileView {"):
            if forbidden in source:
                errors.append(f"renderer owns business dependency: {path.relative_to(ROOT)}: {forbidden}")
    if errors:
        print("FAIL direct Bar contract")
        print("\n".join(errors))
        return 1
    print("PASS neutral Center Bar, host, renderer and routing contracts")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
