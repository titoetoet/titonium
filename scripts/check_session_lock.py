#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(source: str, fragment: str, errors: list[str], label: str) -> None:
    if fragment not in source:
        errors.append(f"{label} missing session-lock contract: {fragment}")


def main() -> int:
    errors: list[str] = []
    router = (ROOT / "Titonium/Orchestration/SurfaceRouter.qml").read_text(encoding="utf-8")
    core_ipc = (ROOT / "Titonium/Ipc/CoreIpc.qml").read_text(encoding="utf-8")
    settings = (ROOT / "Titonium/Settings/SettingsCoordinator.qml").read_text(encoding="utf-8")

    for fragment in (
        "function prepareSessionLock(): bool",
        'root.closeCenter("session-lock")',
        "SurfaceManager.close(\"\")",
        "RightPillCoordinator.forceCloseConnectedSurface()",
        "RightPillCoordinator.closeForStyleChange()",
        "SettingsCoordinator.closeForSessionLock()",
    ):
        require(router, fragment, errors, "SurfaceRouter.qml")

    require(core_ipc, "function prepareLock(): bool", errors, "CoreIpc.qml")
    require(core_ipc, "return root.router.prepareSessionLock();", errors, "CoreIpc.qml")
    require(settings, "function closeForSessionLock(): bool", errors, "SettingsCoordinator.qml")

    if errors:
        for error in errors:
            print(f"FAIL {error}")
        return 1
    print("PASS session lock focus release contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
