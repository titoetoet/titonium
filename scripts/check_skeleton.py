#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED = (
    "Titonium/Core/Screens/ScreenRouter.qml",
    "Titonium/Core/Screens/qmldir",
    "Titonium/Core/Surfaces/SurfaceManager.qml",
    "Titonium/Core/Surfaces/OverlayHost.qml",
    "Titonium/Core/Surfaces/qmldir",
    "Titonium/Core/Runtime/Logger.qml",
    "Titonium/Core/Runtime/Preferences.qml",
    "Titonium/Core/Runtime/PreferencesValidator.js",
    "Titonium/Core/Runtime/I18n.qml",
    "Titonium/Core/Runtime/qmldir",
    "Titonium/Theme/Theme.qml",
    "Titonium/Theme/Metrics.qml",
    "Titonium/Theme/Typography.qml",
    "Titonium/Theme/Motion.qml",
    "Titonium/Theme/qmldir",
    "Titonium/Shared/Surface.qml",
    "Titonium/Shared/Panel.qml",
    "Titonium/Shared/Button.qml",
    "Titonium/Shared/Icon.qml",
    "Titonium/Shared/TextLabel.qml",
    "Titonium/Shared/qmldir",
)

FORBIDDEN_UI_TOKENS = ("Process {", "Quickshell.execDetached", "FileView {")


def main() -> int:
    errors: list[str] = []

    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            errors.append(f"missing skeleton file: {relative}")

    for relative in ("Titonium/Bar", "Titonium/Overlays", "Titonium/Shared"):
        ui_root = ROOT / relative
        if not ui_root.exists():
            continue
        for path in ui_root.rglob("*.qml"):
            source = path.read_text(encoding="utf-8")
            for token in FORBIDDEN_UI_TOKENS:
                if token in source:
                    errors.append(
                        f"UI platform/persistence boundary: {path.relative_to(ROOT)}: {token}"
                    )

    if errors:
        print("FAIL skeleton contract")
        print("\n".join(errors))
        return 1

    print("PASS skeleton contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
