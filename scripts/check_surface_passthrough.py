#!/usr/bin/env python3

"""Static contract for transient-overlay input passthrough surfaces."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CORE_ROOT = ROOT / "Titonium/Core"
SURFACES = CORE_ROOT / "Surfaces"
REGISTRY = SURFACES / "SurfaceInputRegions.qml"
QMLDIR = SURFACES / "qmldir"
OVERLAY = SURFACES / "OverlayHost.qml"
DOCK_WINDOW = ROOT / "Titonium/Dock/DockWindow.qml"
DOCK_SURFACE = ROOT / "Titonium/Dock/DockSurface.qml"
DOCK_BUTTON = ROOT / "Titonium/Dock/DockAppButton.qml"


def source(path: Path, errors: list[str]) -> str:
    if not path.is_file():
        errors.append(f"missing {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8")


def require_fragments(path: Path, fragments: tuple[str, ...], errors: list[str]) -> str:
    text = source(path, errors)
    for fragment in fragments:
        if fragment not in text:
            errors.append(f"{path.relative_to(ROOT)} missing contract: {fragment}")
    return text


def require_ordered(text: str, first: str, second: str, label: str, errors: list[str]) -> None:
    first_index = text.find(first)
    second_index = text.find(second)
    if first_index < 0 or second_index < 0 or first_index > second_index:
        errors.append(f"{label} must close SurfaceManager before the Dock intent")


def fixture_errors() -> list[str]:
    errors: list[str] = []
    malicious_core = 'import qs.Titonium.Dock\\nQtObject {}'
    if "qs.Titonium.Dock" not in malicious_core:
        errors.append("Core-to-Dock import fixture was not detected")

    missing_mask = "PanelWindow {\\n    visible: true\\n}"
    if "mask: Region {" in missing_mask:
        errors.append("missing-overlay-mask fixture was not detected")

    missing_clear = "Component.onCompleted: SurfaceInputRegions.publish([], screen)"
    if "Component.onDestruction" in missing_clear:
        errors.append("missing-destruction-clear fixture was not detected")
    return errors


def main() -> int:
    errors = fixture_errors()
    registry = require_fragments(REGISTRY, (
        "pragma Singleton",
        "function publish(ownerId: string, screen: var, body: rect, edge: rect): bool",
        "function clear(ownerId: string): bool",
        "function regionsFor(screen: var): var",
        "property var entries",
        '"body": root.zeroRect()',
        '"edge": root.zeroRect()',
    ), errors)
    if registry and ("Timer {" in registry or "Process" in registry):
        errors.append("surface input registry must be event-driven and pure Core state")

    qmldir = source(QMLDIR, errors)
    if "singleton SurfaceInputRegions 1.0 SurfaceInputRegions.qml" not in qmldir:
        errors.append("Core Surfaces qmldir must export SurfaceInputRegions singleton")

    for path in CORE_ROOT.rglob("*.qml"):
        if "qs.Titonium.Dock" in path.read_text(encoding="utf-8"):
            errors.append(f"Core must not import Dock: {path.relative_to(ROOT)}")

    overlay = require_fragments(OVERLAY, (
        "mask: Region {",
        "SurfaceInputRegions.regionsFor(window.modelData)",
        "intersection: Intersection.Subtract",
        "overlayInputRegions.body",
        "overlayInputRegions.edge",
        "SurfaceManager.descriptor.barConnected !== true",
    ), errors)
    if "active: window.ownsSurface && Boolean(SurfaceManager.descriptor.source)\n" \
            "                    && SurfaceManager.descriptor.barConnected !== true" not in overlay:
        errors.append("OverlayHost Loader must exclude connected Bar descriptors")
    if "visible: window.ownsOverlaySurface" not in overlay:
        errors.append("OverlayHost window must not paint connected Bar descriptors")
    if "WlrLayershell.keyboardFocus: window.ownsOverlaySurface" not in overlay:
        errors.append("OverlayHost must not focus connected Bar descriptors")
    if "width: window.ownsOverlaySurface ? window.modelData.width : 0" not in overlay \
            or "height: window.ownsOverlaySurface ? window.modelData.height : 0" not in overlay:
        errors.append("OverlayHost mask must be empty for connected Bar descriptors")

    require_fragments(DOCK_WINDOW, (
        "import qs.Titonium.Core.Surfaces",
        "readonly property rect bodyInputRect",
        "readonly property rect edgeInputRect",
        "function bottomLocalToOverlayRect(localRect: rect): rect",
        "root.screenModel.height - root.reservedHeight",
        "SurfaceInputRegions.publish(root.inputRegionOwnerId, root.screenModel,",
        "root.bodyInputRect, root.edgeInputRect",
        "Component.onDestruction: SurfaceInputRegions.clear(root.inputRegionOwnerId)",
        "onBodyInputRectChanged: root.publishInputRegions()",
        "onEdgeInputRectChanged: root.publishInputRegions()",
        "dockSurface.itemMenuActive",
    ), errors)

    dock_surface = require_fragments(DOCK_SURFACE, (
        "import qs.Titonium.Core.Surfaces",
        "SurfaceManager.close(SurfaceManager.ownerId)",
        "function openApplications(): void",
        "root.applicationsRequested(root.screenModel);",
        "DockStore.setPinnedOpen",
    ), errors)
    applications_function = dock_surface.find("function openApplications(): void")
    applications_close = dock_surface.find("root.closeTransient();", applications_function)
    applications_emit = dock_surface.find(
        "root.applicationsRequested(root.screenModel);", applications_function)
    if applications_function < 0 or applications_close < applications_function \
            or applications_emit < applications_close:
        errors.append("Dock Applications intent must close SurfaceManager before opening Spotlight")
    if dock_surface.count("root.openApplications();") < 2:
        errors.append("Dock Applications mouse and keyboard activation must share the close-first intent")
    require_ordered(dock_surface, "root.closeTransient();", "pinControl.togglePinnedOpen();",
                    "Dock pin control", errors)
    dock_button = require_fragments(DOCK_BUTTON, (
        "import qs.Titonium.Core.Surfaces",
        "SurfaceManager.close(SurfaceManager.ownerId)",
        "DockService.activateOrLaunch",
        "DockService.launchNew",
    ), errors)
    require_ordered(dock_button, "root.closeTransient();", "DockService.activateOrLaunch",
                    "Dock application activation", errors)
    require_ordered(dock_button, "root.closeTransient();", "DockService.launchNew",
                    "Dock application new-window action", errors)

    if errors:
        for error in errors:
            print(f"FAIL {error}")
        return 1
    print("PASS transient surface passthrough fixtures")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
