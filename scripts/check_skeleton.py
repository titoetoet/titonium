#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED = (
    "Titonium/App.qml",
    "Titonium/qmldir",
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
    "Titonium/Overlays/Spotlight/AppGrid.qml",
    "Titonium/Overlays/Spotlight/ApplicationTile.qml",
    "Titonium/Overlays/Spotlight/Calculator.js",
    "Titonium/Overlays/Spotlight/CategoryCatalog.js",
    "Titonium/Overlays/Spotlight/ClipboardView.qml",
    "Titonium/Overlays/Spotlight/PageIndicator.qml",
    "Titonium/Overlays/Spotlight/SearchEngine.js",
    "Titonium/Overlays/Spotlight/SearchResults.qml",
    "Titonium/Overlays/Spotlight/SpotlightLayout.js",
    "Titonium/Overlays/Spotlight/SpotlightModel.qml",
    "Titonium/Overlays/Spotlight/SpotlightScope.js",
    "Titonium/Overlays/Spotlight/SpotlightState.js",
    "Titonium/Overlays/Spotlight/SpotlightSurface.qml",
    "Titonium/Overlays/Spotlight/SpotlightTransition.js",
    "Titonium/Overlays/Spotlight/StableOrder.js",
    "Titonium/Overlays/Spotlight/SystemSearchMock.qml",
    "Titonium/Overlays/Spotlight/qmldir",
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

    spotlight_root = ROOT / "Titonium/Overlays/Spotlight"
    if spotlight_root.exists():
        forbidden_imports = (
            "qs.Titonium.Foundation",
            "qs.Titonium.Platform",
            "qs.Titonium.Design",
            "qs.Titonium.Composition",
        )
        for path in spotlight_root.glob("*.qml"):
            source = path.read_text(encoding="utf-8")
            for old_import in forbidden_imports:
                if old_import in source:
                    errors.append(
                        f"protected Spotlight retains old import: {path.relative_to(ROOT)}: {old_import}"
                    )

    app_path = ROOT / "Titonium/App.qml"
    shell_path = ROOT / "shell.qml"
    if app_path.is_file():
        app_source = app_path.read_text(encoding="utf-8")
        for contract in ("BarHost {}", "OverlayHost {}", 'target: "app"', 'target: "spotlight"'):
            if contract not in app_source:
                errors.append(f"minimal App is missing contract: {contract}")
        for retired in (
            "FrameHost",
            "SettingsCenter",
            "DesignGallery",
            "ArchMenu",
            "SessionActions",
            "CalendarPanel",
            "WidgetRegistry",
            "LayoutRenderer",
            "Modules/Spotlight",
        ):
            if retired in app_source:
                errors.append(f"minimal App retains retired runtime owner: {retired}")
    if shell_path.is_file():
        shell_source = shell_path.read_text(encoding="utf-8")
        if "import qs.Titonium\n" not in shell_source or "App {}" not in shell_source:
            errors.append("shell.qml must instantiate qs.Titonium App directly")

    for retired_dir in (
        "Titonium/App",
        "Titonium/Composition",
        "Titonium/Design",
        "Titonium/Foundation",
        "Titonium/Modules",
        "Titonium/Platform",
        "Titonium/Surfaces",
    ):
        retired_path = ROOT / retired_dir
        if retired_path.exists() and any(path.is_file() for path in retired_path.rglob("*")):
            errors.append(f"retired source directory remains: {retired_dir}")

    if errors:
        print("FAIL skeleton contract")
        print("\n".join(errors))
        return 1

    print("PASS skeleton contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
