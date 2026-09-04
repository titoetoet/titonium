#!/usr/bin/env python3

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / "Titonium/Core/Surfaces/Center/CenterSurfaceController.qml"
ROUTER = ROOT / "Titonium/Orchestration/SurfaceRouter.qml"

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

if errors:
    print("FAIL neutral Center architecture")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)
print("PASS neutral Center controller and router contracts")
