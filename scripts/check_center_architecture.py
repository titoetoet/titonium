#!/usr/bin/env python3

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / "Titonium/Core/Surfaces/Center/CenterSurfaceController.qml"
ROUTER = ROOT / "Titonium/Orchestration/SurfaceRouter.qml"
HOST_ROOT = ROOT / "Titonium/Core/Surfaces/Center"
BAR_HOST = ROOT / "Titonium/Bar/BarHost.qml"
PRESENTATIONS = ROOT / "Titonium/Bar/center/presentations"

errors = []
if not CONTROLLER.exists():
    errors.append("missing neutral CenterSurfaceController")
else:
    source = CONTROLLER.read_text()
    for fragment in (
        "readonly property var viewState",
        "signal surfaceRequested(var request)",
        "signal navigationRequested(var request)",
        "function dispatch(intent: var): var",
        "function finishClose(screenName: string, generation: int): bool",
        "CenterSurfaceState.transition",
        "CenterDomain.dispatch",
    ):
        if fragment not in source:
            errors.append(f"controller missing contract: {fragment}")
    for forbidden in ("qs.Titonium.Bar", "RightPillCoordinator", "SettingsCoordinator"):
        if forbidden in source:
            errors.append(f"controller imports presentation/orchestration: {forbidden}")

router_source = ROUTER.read_text()
for fragment in ("function openCenter(", "function presentCenterBanner(", "function closeCenter("):
    if fragment not in router_source:
        errors.append(f"router missing neutral API: {fragment}")
for forbidden in ("activateCenterSource", "openCenterNotch", "openCenterBanner",
                  "Services.Mpris", "CenterServices"):
    if forbidden in router_source:
        errors.append(f"router retains source/theme API: {forbidden}")

for filename in ("CenterSurfaceHost.qml", "CenterCompactWindow.qml", "CenterOverlayWindow.qml"):
    if not (HOST_ROOT / filename).exists():
        errors.append(f"missing neutral host file: {filename}")

bar_host_source = BAR_HOST.read_text()
if "CenterSurfaceHost {" not in bar_host_source:
    errors.append("BarHost does not compose CenterSurfaceHost")
if "CenterPillWindow {" in bar_host_source:
    errors.append("BarHost still composes legacy CenterPillWindow")

production_files = list((ROOT / "Titonium").rglob("*.qml"))
legacy_consumers = []
legacy_name = "Center" + "NotchCoordinator"
for path in production_files:
    if path.name == legacy_name + ".qml":
        continue
    if legacy_name in path.read_text():
        legacy_consumers.append(str(path.relative_to(ROOT)))
if legacy_consumers:
    errors.append("legacy coordinator consumers: " + ", ".join(legacy_consumers))

for path in PRESENTATIONS.rglob("*.qml"):
    source = path.read_text()
    for forbidden in ("Services.Capture", "Services.Mpris", "Services.Notifications",
                      "Services.AgentApproval", "Services.Center", "SurfaceManager",
                      "ScreenRouter", "PanelWindow", "WlrLayershell", "Process {",
                      "FileView {", "Timer {"):
        if forbidden in source:
            errors.append(f"presentation owns forbidden dependency: {path.relative_to(ROOT)}: {forbidden}")

document_contracts = {
    "docs/ARCHITECTURE.md": ("CenterDomain", "CenterSurfaceController", "CenterSurfaceHost"),
    "docs/MODULE_CONTRACT.md": ("CenterDomain", "CenterSurfaceController", "CenterSurfaceHost"),
    "docs/TESTING.md": ("CenterSurfaceHost", "compact/banner/expanded"),
    "docs/THEMING_AND_GLASS.md": ("Pill, Notch, Connected, and Classic", "CenterSurfaceHost"),
}
for relative, required in document_contracts.items():
    source = (ROOT / relative).read_text()
    for fragment in required:
        if fragment not in source:
            errors.append(f"{relative} missing neutral Center boundary: {fragment}")

if errors:
    print("FAIL neutral Center architecture")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)
print("PASS neutral Center controller and router contracts")
