#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]

REQUIRED = (
    "Titonium/App.qml",
    "Titonium/qmldir",
    "Titonium/Orchestration/ServiceBootstrap.qml",
    "Titonium/Orchestration/BluetoothAudioBridge.qml",
    "Titonium/Orchestration/SurfaceRouter.qml",
    "Titonium/Orchestration/qmldir",
    "Titonium/Ipc/CoreIpc.qml",
    "Titonium/Ipc/CenterIpc.qml",
    "Titonium/Ipc/DeviceIpc.qml",
    "Titonium/Ipc/AgentApprovalIpc.qml",
    "Titonium/Ipc/qmldir",
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
    "Titonium/Overlays/Spotlight/ClipboardFormat.js",
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
        for contract in ("BarHost {", "OverlayHost {}", "SurfaceRouter {",
                "CoreIpc { router: router }", "CenterIpc {}", "DeviceIpc {}"):
            if contract not in app_source:
                errors.append(f"minimal App is missing contract: {contract}")
        if app_source.count("BarHost {") != 1:
            errors.append("minimal App must compose exactly one BarHost")
        if "IpcHandler" in app_source:
            errors.append("minimal App must not own IPC handler bodies")
        if len(app_source.splitlines()) > 80:
            errors.append("minimal App exceeds the 80-line composition-root budget")
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

    ipc_root = ROOT / "Titonium/Ipc"
    ipc_source = "\n".join(
        path.read_text(encoding="utf-8") for path in ipc_root.glob("*.qml")
    ) if ipc_root.is_dir() else ""
    expected_targets = {
        "agentApproval", "app", "audio", "bluetooth", "center", "centerNotch", "dock",
        "focus", "job", "mpris", "network", "notifications", "settings", "spotlight", "timer",
        "window-switcher",
    }
    actual_targets = re.findall(r'\btarget\s*:\s*"([^"]+)"', ipc_source)
    if set(actual_targets) != expected_targets or len(actual_targets) != len(expected_targets):
        errors.append("IPC adapters must expose each existing public target exactly once")
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
