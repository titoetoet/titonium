#!/usr/bin/env python3
"""Guard Titonium's architectural boundaries with inexpensive static checks."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    errors: list[str] = []

    for qml_dir in sorted({path.parent for path in (root / "Titonium").rglob("*.qml")}):
        if not (qml_dir / "qmldir").is_file():
            errors.append(f"missing qmldir: {qml_dir.relative_to(root)}")

    forbidden_ui = re.compile(r"\b(Process|FileView)\s*\{")
    forbidden_commands = re.compile(r"\b(hyprctl|nmcli|wpctl)\b")
    forbidden_platform_imports = re.compile(
        r"^import Quickshell\.(Hyprland|Services\.SystemTray)\b", re.MULTILINE
    )
    forbidden_platform_objects = re.compile(r"\b(Hyprland|ToplevelManager|SystemTray)\.")
    forbidden_perf = re.compile(r"\b(MultiEffect|ShaderEffect)\b|Animation\.Infinite|loops\s*:\s*Animation\.Infinite")
    allowed_io = {"Foundation", "Platform"}

    for path in sorted((root / "Titonium").rglob("*.qml")):
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(root)
        layer = relative.parts[1] if len(relative.parts) > 1 else ""
        if layer not in allowed_io and forbidden_ui.search(text):
            errors.append(f"platform I/O in UI layer: {relative}")
        if layer not in allowed_io and forbidden_commands.search(text):
            errors.append(f"raw platform command in UI layer: {relative}")
        if layer != "Platform" and forbidden_platform_imports.search(text):
            errors.append(f"direct platform API import outside Platform: {relative}")
        if layer != "Platform" and forbidden_platform_objects.search(text):
            errors.append(f"direct platform object access outside Platform: {relative}")
        if layer != "Platform" and re.search(r"\bDesktopEntries\b", text):
            errors.append(f"direct desktop-entry access outside Platform: {relative}")
        if forbidden_perf.search(text):
            errors.append(f"forbidden always-on visual cost: {relative}")
        if "/home/" in text or "~/" in text:
            errors.append(f"hardcoded home path in QML: {relative}")
        if ".config/quickshell/titonium" in text or ".local/share/Trash/files/titonium" in text:
            errors.append(f"legacy source reference in runtime QML: {relative}")

    registry = (root / "Titonium/Composition/WidgetRegistry.qml").read_text(encoding="utf-8")
    if "unknownSource" not in registry or "sourceFor" not in registry:
        errors.append("WidgetRegistry must provide an unknown widget fallback")
    for widget_type in (
        "menubar.workspaces",
        "menubar.active-window",
        "menubar.input-method",
        "menubar.clock",
        "menubar.launcher",
    ):
        if widget_type not in registry:
            errors.append(f"WidgetRegistry is missing {widget_type}")
    if '"menubar.launcher": Qt.resolvedUrl("../Modules/MenuBar/ArchMenu/ArchMenuWidget.qml")' not in registry:
        errors.append("menubar.launcher must resolve to the compact ArchMenuWidget")

    overlay = (root / "Titonium/Surfaces/OverlayHost.qml").read_text(encoding="utf-8")
    if "Loader" not in overlay or "active:" not in overlay:
        errors.append("OverlayHost must lazy-load transient UI")
    if "implicitWidth: window.modelData.width" not in overlay or "implicitHeight: window.modelData.height" not in overlay:
        errors.append("OverlayHost must expose the target screen's logical size to lazy content")

    layout_renderer = (root / "Titonium/Composition/LayoutRenderer.qml").read_text(encoding="utf-8")
    if "Layout.preferredWidth: implicitWidth" not in layout_renderer:
        errors.append("LayoutRenderer must propagate asynchronously loaded widget width")
    if re.search(r"columns\s*:\s*[^\n?]+\?\s*0\b", layout_renderer):
        errors.append("LayoutRenderer horizontal columns must never resolve to zero")

    for adapter_path in (
        root / "Titonium/Platform/Hyprland/HyprlandAdapter.qml",
        root / "Titonium/Platform/Input/FcitxAdapter.qml",
    ):
        adapter_text = adapter_path.read_text(encoding="utf-8")
        if re.search(r"\b(Process|Timer)\s*\{", adapter_text):
            errors.append(f"MenuBar adapter must remain event-driven: {adapter_path.relative_to(root)}")

    clock_text = (root / "Titonium/Modules/MenuBar/Clock/ClockModel.qml").read_text(encoding="utf-8")
    if "SystemClock.Minutes" not in clock_text or "SystemClock.Seconds" in clock_text:
        errors.append("Clock must update by minute, never by second")
    clock_feature = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (root / "Titonium/Modules/MenuBar/Clock").glob("*.qml")
    )
    if re.search(r"\b(Timer|Process)\s*\{", clock_feature):
        errors.append("Clock and calendar must not poll or launch processes")

    launcher_dir = root / "Titonium/Modules/MenuBar" / "Launcher"
    if launcher_dir.exists():
        errors.append("superseded MenuBar/Launcher module directory remains")
    for legacy_symbol in ("Launcher" + "SettingsPage", "Launcher" + "SectionRegistry"):
        for path in sorted((root / "Titonium").rglob("*")):
            if not path.is_file() or (
                path.suffix not in {".qml", ".js"} and path.name != "qmldir"
            ):
                continue
            if legacy_symbol in path.name or legacy_symbol in path.read_text(encoding="utf-8"):
                errors.append(
                    f"superseded Launcher reference remains: {path.relative_to(root)} ({legacy_symbol})"
                )

    compact_menu_dir = root / "Titonium/Modules/MenuBar/ArchMenu"
    compact_menu_files = (
        "ArchMenuWidget.qml",
        "ArchMenu.qml",
        "ArchMenuModel.js",
        "ArchMenuItem.qml",
        "SessionConfirmation.qml",
        "AboutTitonium.qml",
        "qmldir",
    )
    for compact_menu_file in compact_menu_files:
        if not (compact_menu_dir / compact_menu_file).is_file():
            errors.append(f"compact Arch Menu is missing focused component: {compact_menu_file}")

    compact_menu_qml = {
        path.name: path.read_text(encoding="utf-8")
        for path in compact_menu_dir.glob("*.qml")
    } if compact_menu_dir.is_dir() else {}
    compact_menu_feature = "\n".join(compact_menu_qml.values())
    if re.search(
        r"\b(Grid|GridLayout|LauncherRail|SearchResults|TextInput|TextField|search|query)\b",
        compact_menu_feature,
        re.IGNORECASE,
    ):
        errors.append("compact Arch Menu must not contain grid, rail or search UI")
    if re.search(r"\b(Process|FileView|Timer)\s*\{|execDetached|Animation\.Infinite", compact_menu_feature):
        errors.append("compact Arch Menu must remain event-driven and platform-I/O free")

    compact_item = compact_menu_qml.get("ArchMenuItem.qml", "")
    for contract in (
        "Controls.Icon",
        "Controls.TextLabel",
        "activeFocusOnTab:",
        "Accessible.role: Accessible.MenuItem",
        "Accessible.name:",
        "Accessible.focusable:",
    ):
        if contract not in compact_item:
            errors.append(f"ArchMenuItem is missing icon/text/accessibility contract: {contract}")

    compact_surface = compact_menu_qml.get("ArchMenu.qml", "")
    if (
        "Accessible.role: Accessible.Separator" not in compact_surface
        or "implicitHeight: Metrics.borderWidth" not in compact_surface
    ):
        errors.append("Arch Menu group boundaries must render semantic one-pixel separators")
    if compact_surface.count("SessionActions.executeConfirmed(") != 1:
        errors.append("Arch Menu must have exactly one confirmed Platform execution path")
    if (
        "ArchMenuModel.routeFor(item)" not in compact_surface
        or 'Logger.warn("arch-menu", "unknown item id: "' not in compact_surface
    ):
        errors.append("unknown non-confirming Arch Menu items must log a warning and do nothing")
    pending_assignment = compact_surface.find("pendingAction = actionId")
    confirmed_execution = compact_surface.find("SessionActions.executeConfirmed(actionId)")
    if pending_assignment < 0 or confirmed_execution < 0 or pending_assignment > confirmed_execution:
        errors.append("Arch Menu must set pendingAction before confirmed session execution")
    for leaf_name in ("ArchMenuItem.qml", "SessionConfirmation.qml"):
        if "SessionActions" in compact_menu_qml.get(leaf_name, ""):
            errors.append(f"{leaf_name} must emit intent without calling SessionActions")

    confirmation = compact_menu_qml.get("SessionConfirmation.qml", "")
    if confirmation.count("Controls.Button {") != 2:
        errors.append("SessionConfirmation must expose exactly Cancel and confirm controls")
    for contract in ("accessibleName:", "activeFocusOnTab:", "Accessible.role: Accessible.Button"):
        if confirmation.count(contract) < 2:
            errors.append(f"each confirmation control must expose {contract}")
    if "cancelButton.forceActiveFocus" not in confirmation:
        errors.append("SessionConfirmation must give Cancel initial keyboard focus")
    if "signal cancelled()" not in confirmation or "onTriggered: root.cancelled()" not in confirmation:
        errors.append("SessionConfirmation Cancel must emit only the cancelled intent")
    cancel_path = re.search(
        r"function cancelPendingAction\(\): void\s*\{(?P<body>[\s\S]*?)\n\s*\}",
        compact_surface,
    )
    cancel_path_body = cancel_path.group("body") if cancel_path else ""
    if (
        "onCancelled: root.cancelPendingAction()" not in compact_surface
        or 'root.pendingAction = ""' not in cancel_path_body
        or "SessionActions" in cancel_path_body
        or "SurfaceCoordinator" in cancel_path_body
    ):
        errors.append("Arch Menu Cancel must clear pendingAction without Platform execution")

    guard_call = compact_surface.find("SurfaceCoordinator.guardOwner(root.ownerId)")
    confirmed_call = compact_surface.find("SessionActions.executeConfirmed(actionId)")
    if guard_call < 0 or confirmed_call < 0 or guard_call > confirmed_call:
        errors.append("Arch Menu must guard its surface owner before confirmed session execution")
    action_started_handler = re.search(
        r"function onActionStarted\(action: string\): void\s*\{(?P<body>[\s\S]*?)\n\s*\}",
        compact_surface,
    )
    action_started_body = action_started_handler.group("body") if action_started_handler else ""
    if "SurfaceCoordinator.forceClose(root.ownerId)" not in action_started_body:
        errors.append("matching actionStarted must explicitly force-close the guarded Arch Menu")
    action_failed_handler = re.search(
        r"function onActionFailed\(action: string, error: string\): void\s*\{(?P<body>[\s\S]*?)\n\s*\}",
        compact_surface,
    )
    action_failed_body = action_failed_handler.group("body") if action_failed_handler else ""
    if (
        "SurfaceCoordinator.releaseOwnerGuard(root.ownerId)" not in action_failed_body
        or "root.launchPending = false" not in action_failed_body
        or "SurfaceCoordinator.close" in action_failed_body
        or "SurfaceCoordinator.forceClose" in action_failed_body
    ):
        errors.append("actionFailed must release the owner guard and retain the confirmation sheet")

    app_metadata_path = root / "Titonium/Foundation/AppMetadata.qml"
    if not app_metadata_path.is_file():
        errors.append("Foundation is missing the AppMetadata singleton")
        app_metadata = ""
    else:
        app_metadata = app_metadata_path.read_text(encoding="utf-8")
    for contract in ('name: "Titonium"', 'version: "0.1.0-dev"'):
        if contract not in app_metadata:
            errors.append(f"AppMetadata is missing build identity contract: {contract}")
    about_surface = compact_menu_qml.get("AboutTitonium.qml", "")
    for contract in (
        "AppMetadata.name",
        "AppMetadata.version",
        "AppMetadata.themeIdentity",
        "AppMetadata.sessionTechnologies",
    ):
        if contract not in about_surface:
            errors.append(f"AboutTitonium must project Foundation metadata: {contract}")

    app_shell = (root / "Titonium/App/AppShell.qml").read_text(encoding="utf-8")
    for contract in (
        "function coordinatorIpcResult(accepted: bool, successResult: string): string",
        'return "blocked:guarded:" + SurfaceCoordinator.ownerId',
        "return successResult",
    ):
        if contract not in app_shell:
            errors.append(f"AppShell is missing guarded IPC result contract: {contract}")
    ipc_blocks = re.findall(
        r"\n    IpcHandler\s*\{(?P<body>[\s\S]*?)"
        r"(?=\n    IpcHandler\s*\{|\n    Component\.onCompleted:)",
        app_shell,
    )
    ipc_bodies: dict[str, str] = {}
    for ipc_block in ipc_blocks:
        target_match = re.search(r'target:\s*"(?P<target>[^"]+)"', ipc_block)
        if target_match:
            ipc_bodies[target_match.group("target")] = ipc_block
    reporting_mutation_counts = {
        "settings": 4,
        "arch-menu": 3,
        "spotlight": 6,
        "clock": 3,
        "calendar": 3,
        "gallery": 3,
    }
    for target, expected_count in reporting_mutation_counts.items():
        ipc_body = ipc_bodies.get(target, "")
        mutation_count = len(re.findall(r"SurfaceCoordinator\.(?:open|close)\(", ipc_body))
        result_count = ipc_body.count("root.coordinatorIpcResult(")
        if mutation_count != expected_count or result_count != expected_count:
            errors.append(
                f"{target} IPC must map all {expected_count} coordinator mutations "
                "through guarded result reporting"
            )
    if 'target: "arch-menu"' not in app_shell:
        errors.append("AppShell must expose arch-menu IPC")
    if re.search(r'target:\s*"launcher"', app_shell):
        errors.append("superseded launcher IPC target remains")
    arch_menu_ipc = re.search(
        r'IpcHandler\s*\{\s*target:\s*"arch-menu"(?P<body>[\s\S]*?)\n\s*\}\n\s*IpcHandler',
        app_shell,
    )
    arch_menu_ipc_body = arch_menu_ipc.group("body") if arch_menu_ipc else ""
    for method in ("function toggle(screenName: string)", "function close()", "function state()"):
        if method not in arch_menu_ipc_body:
            errors.append(f"arch-menu IPC is missing {method}")
    if "function section(" in arch_menu_ipc_body:
        errors.append("arch-menu IPC must not expose legacy section navigation")
    if (
        "function openSettings()" not in compact_surface
        or '"source": Qt.resolvedUrl("../../Settings/SettingsCenter.qml")' not in compact_surface
        or 'root.openSettings();' not in compact_surface
    ):
        errors.append("Arch Menu Settings activation must open standalone SettingsCenter")
    arch_menu_opening_paths = {
        "AppShell arch-menu IPC": arch_menu_ipc_body,
        "ArchMenuWidget": compact_menu_qml.get("ArchMenuWidget.qml", ""),
    }
    for path_name, opening_path in arch_menu_opening_paths.items():
        if "ArchMenu.qml" not in opening_path:
            errors.append(f"Arch Menu opening path is missing its ArchMenu.qml source: {path_name}")
        if "cancelPreviewOnClose" in opening_path:
            errors.append(f"Arch Menu descriptor must not own Settings preview cancellation: {path_name}")

    session_actions = (root / "Titonium/Platform/System/SessionActions.qml").read_text(encoding="utf-8")
    for contract in (
        '"lock"',
        '["hyprlock"]',
        "signal actionStarted(string action)",
        "signal actionFailed(string action, string error)",
        "onStarted:",
    ):
        if contract not in session_actions:
            errors.append(f"SessionActions is missing launch lifecycle contract: {contract}")
    if re.search(r'"lock"\s*:\s*\[\s*"(?:sh|bash|zsh)"', session_actions):
        errors.append("SessionActions lock must use direct hyprlock execution without a shell")
    application_adapter = (
        root / "Titonium/Platform/Applications/ApplicationCatalog.qml"
    ).read_text(encoding="utf-8")
    for contract in (
        "DesktopEntries.applications",
        "ApplicationLaunch.request(entry)",
        "signal launchFailed(string entryId, string error)",
        "root.launchFailed(entryId, result.error)",
    ):
        if contract not in application_adapter:
            errors.append(f"ApplicationCatalog is missing guarded launch contract: {contract}")

    clipboard_adapter_path = root / "Titonium/Platform/Clipboard/ClipboardAdapter.qml"
    clipboard_adapter = clipboard_adapter_path.read_text(encoding="utf-8")
    for contract in ("Quickshell.clipboardText", "onClipboardTextChanged", "textObserved"):
        if contract not in clipboard_adapter:
            errors.append(f"ClipboardAdapter is missing event boundary: {contract}")
    if re.search(r"\b(Timer|Process)\s*\{|wl-paste|wl-copy", clipboard_adapter):
        errors.append("ClipboardAdapter must observe Quickshell clipboard events without polling or processes")
    for contract in (
        "property bool available:",
        "property string error:",
        "ClipboardAccess.observe(",
        "ClipboardAccess.copy(",
    ):
        if contract not in clipboard_adapter:
            errors.append(f"ClipboardAdapter is missing availability/error contract: {contract}")

    clipboard_store_path = root / "Titonium/Foundation/ClipboardHistoryStore.qml"
    if not clipboard_store_path.is_file():
        errors.append("Clipboard history is missing Foundation/ClipboardHistoryStore.qml")
    else:
        clipboard_store = clipboard_store_path.read_text(encoding="utf-8")
        for contract in (
            'Quickshell.dataPath("clipboard-history.json")',
            "FileView",
            "atomicWrites: true",
            "setText(",
            "ClipboardAdapter",
            "readonly property bool available:",
            "readonly property string error:",
        ):
            if contract not in clipboard_store:
                errors.append(f"ClipboardHistoryStore is missing persistence/event contract: {contract}")
        if re.search(r"\b(Timer|Process)\s*\{|wl-paste|wl-copy", clipboard_store):
            errors.append("ClipboardHistoryStore must remain event-driven and process-free")
        adapter_starts_observation = bool(re.search(
            r"Component\.onCompleted\s*:\s*root\.observeCurrent\(\)",
            clipboard_adapter,
        ))
        store_starts_observation = bool(re.search(
            r"Component\.onCompleted\s*:\s*\{[\s\S]*?ClipboardAdapter\.observeCurrent\(\)",
            clipboard_store,
        ))
        if adapter_starts_observation or not store_starts_observation:
            errors.append(
                "ClipboardHistoryStore must be the sole initial observation owner; adapter changes remain event-driven"
            )

    spotlight_acceptance = (
        root / "scripts/spotlight_acceptance.sh"
    ).read_text(encoding="utf-8")
    call_ipc_helper = re.search(
        r"call_ipc\(\)\s*\{(?P<body>[\s\S]*?)\n\}", spotlight_acceptance
    )
    call_ipc_body = call_ipc_helper.group("body") if call_ipc_helper else ""
    if not re.search(
        r'qs\s+-p\s+"\$project_root"\s+ipc\s+--pid\s+"\$shell_pid"\s+call',
        call_ipc_body,
    ):
        errors.append("Spotlight acceptance IPC must target its spawned shell PID")
    for polling_contract in (
        "wait_for_spotlight_state()",
        "for _ in {1..40}",
        'mode=results;query=fire;selected=0',
        'sleep 0.05',
    ):
        if polling_contract not in spotlight_acceptance:
            errors.append(
                f"Spotlight acceptance must poll the exact settled results state: {polling_contract}"
            )

    settings_acceptance = (root / "scripts/settings_acceptance.sh").read_text(encoding="utf-8")
    call_ipc_helper = re.search(
        r"call_ipc\(\)\s*\{(?P<body>[\s\S]*?)\n\}", settings_acceptance
    )
    call_ipc_body = call_ipc_helper.group("body") if call_ipc_helper else ""
    if not re.search(
        r'qs\s+-p\s+"\$project_root"\s+ipc\s+--pid\s+"\$shell_pid"\s+call',
        call_ipc_body,
    ):
        errors.append("Settings acceptance IPC must target its spawned shell PID")

    settings_feature = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (root / "Titonium/Modules/Settings").glob("*.qml")
    )
    if re.search(r"\b(Timer|Process|FileView)\s*\{|execDetached|MultiEffect|ShaderEffect", settings_feature):
        errors.append("Settings UI must remain transaction-only and effect-free")
    settings_workspace = root / "Titonium/Modules/Settings/SettingsWorkspace.qml"
    settings_center = root / "Titonium/Modules/Settings/SettingsCenter.qml"
    if not settings_workspace.is_file() or not settings_center.is_file():
        errors.append("standalone Settings requires SettingsCenter and SettingsWorkspace")
    else:
        settings_workspace_hosts = []
        for qml_path in sorted((root / "Titonium").rglob("*.qml")):
            count = len(re.findall(
                r"\bSettingsWorkspace\s*\{",
                qml_path.read_text(encoding="utf-8"),
            ))
            if count > 0:
                settings_workspace_hosts.append((qml_path, count))
        total_settings_workspaces = sum(count for _, count in settings_workspace_hosts)
        if total_settings_workspaces != 1:
            errors.append(
                f"SettingsWorkspace must have exactly one QML instantiation; found {total_settings_workspaces}"
            )
        invalid_settings_hosts = [
            path.relative_to(root)
            for path, _ in settings_workspace_hosts
            if path != settings_center
        ]
        if invalid_settings_hosts:
            errors.append(
                "SettingsWorkspace must not be instantiated outside SettingsCenter: "
                + ", ".join(str(path) for path in invalid_settings_hosts)
            )
    spotlight_settings = (
        root / "Titonium/Modules/Settings/SpotlightPage.qml"
    ).read_text(encoding="utf-8")
    if '+ " ms"' in spotlight_settings:
        errors.append("Spotlight duration must not render a raw millisecond suffix")
    if 'I18n.tr("settings.spotlight.transition_duration_value"' not in spotlight_settings:
        errors.append("Spotlight duration value must use its localized formatter")

    spotlight_dir = root / "Titonium/Modules/Spotlight"
    visibility_store_path = root / "Titonium/Foundation/ApplicationVisibilityStore.qml"
    foundation_qmldir = (root / "Titonium/Foundation/qmldir").read_text(encoding="utf-8")
    if not visibility_store_path.is_file():
        errors.append("Foundation application visibility store is missing")
    else:
        visibility_store = visibility_store_path.read_text(encoding="utf-8")
        for contract in (
            "ApplicationCatalog.applications",
            "ConfigStore.previewState.applications",
            "readonly property var allApplications",
            "readonly property var visibleApplications",
            "function isVisible(entryId: string): bool",
            "function setVisible(entryId: string, visible: bool): bool",
        ):
            if contract not in visibility_store:
                errors.append(f"ApplicationVisibilityStore is missing contract: {contract}")
    if "singleton ApplicationVisibilityStore 1.0 ApplicationVisibilityStore.qml" not in foundation_qmldir:
        errors.append("Foundation qmldir must register ApplicationVisibilityStore")
    spotlight_files = (
        "SpotlightModel.qml",
        "SpotlightSurface.qml",
        "ClipboardView.qml",
        "AppGrid.qml",
        "ApplicationTile.qml",
        "SearchResults.qml",
        "SystemSearchMock.qml",
        "PageIndicator.qml",
        "qmldir",
    )
    for spotlight_file in spotlight_files:
        if not (spotlight_dir / spotlight_file).is_file():
            errors.append(f"Spotlight is missing focused component: {spotlight_file}")
    spotlight_qml = {
        path.name: path.read_text(encoding="utf-8")
        for path in spotlight_dir.glob("*.qml")
    }
    spotlight_feature = "\n".join(spotlight_qml.values())
    spotlight_model = spotlight_qml.get("SpotlightModel.qml", "")
    if "ApplicationVisibilityStore.visibleApplications" not in spotlight_model:
        errors.append("SpotlightModel must consume the global visible application projection")
    if "ApplicationCatalog.applications" in spotlight_model:
        errors.append("SpotlightModel must not browse or search the raw application catalog")
    if re.search(
        r"\b(Process|FileView|Timer|MultiEffect|ShaderEffect)\s*\{|"
        r"execDetached|\b(hyprctl|nmcli|wpctl)\b|Animation\.Infinite|"
        r"loops\s*:\s*Animation\.Infinite",
        spotlight_feature,
    ):
        errors.append("Spotlight must not perform I/O, poll, spawn commands or animate continuously")
    for ordering_file in ("CategoryCatalog.js", "SearchEngine.js"):
        ordering_text = (spotlight_dir / ordering_file).read_text(encoding="utf-8")
        if "localeCompare" in ordering_text:
            errors.append(f"Spotlight ordering must not use host locale collation: {ordering_file}")
        if '.import "StableOrder.js" as StableOrder' not in ordering_text:
            errors.append(f"Spotlight ordering must share StableOrder.compare: {ordering_file}")
    spotlight_surface = spotlight_qml.get("SpotlightSurface.qml", "")
    if (
        "Loader" not in spotlight_surface
        or 'mode === "browse"' not in spotlight_surface
        or 'mode === "results"' not in spotlight_surface
        or 'mode === "clipboard"' not in spotlight_surface
        or 'mode === "system"' not in spotlight_surface
        or "AppGrid.qml" not in spotlight_surface
        or "SearchResults.qml" not in spotlight_surface
        or "ClipboardView.qml" not in spotlight_surface
        or "SystemSearchMock.qml" not in spotlight_surface
    ):
        errors.append("SpotlightSurface must lazy-load Apps, Clipboard and System Search branches")
    for scope_contract in (
        "spotlightModel.cycleScope",
        "Qt.Key_Tab",
        "Qt.ShiftModifier",
        "scopeIcon",
    ):
        if scope_contract not in spotlight_surface:
            errors.append(f"Spotlight search field must expose keyboard scope switching: {scope_contract}")
    page_indicator = spotlight_qml.get("PageIndicator.qml", "")
    for density_contract in (
        "SpotlightLayout.indicatorTrackWidth()",
        "SpotlightLayout.indicatorFillWidth(root.page, SpotlightLayout.pageSize())",
    ):
        if density_contract not in page_indicator:
            errors.append(f"Spotlight page indicator must compare page density on a fixed track: {density_contract}")
    clipboard_view = spotlight_qml.get("ClipboardView.qml", "")
    if "ClipboardHistoryStore" not in clipboard_view:
        errors.append("ClipboardView must project ClipboardHistoryStore intents")
    if "ClipboardAdapter" in clipboard_view or "clipboardTextChanged" in clipboard_view:
        errors.append("Clipboard UI must not own clipboard observation")
    for contract in (
        'I18n.tr("spotlight.clipboard.unavailable")',
        "ClipboardHistoryStore.available",
    ):
        if contract not in clipboard_view:
            errors.append(f"ClipboardView must distinguish unavailable from empty: {contract}")
    spotlight_accessibility = {
        "SpotlightSurface.qml": (
            "activeFocusOnTab:",
            "Accessible.name:",
            "Accessible.focusable:",
            "accessibleName: I18n.tr(\"spotlight.category_accessible\"",
        ),
        "ApplicationTile.qml": ("activeFocusOnTab:", "Accessible.name:", "Accessible.focusable:"),
        "SearchResults.qml": ("activeFocusOnTab:", "Accessible.name:", "Accessible.focusable:"),
    }
    for filename, required_fragments in spotlight_accessibility.items():
        text = spotlight_qml.get(filename, "")
        for fragment in required_fragments:
            if fragment not in text:
                errors.append(f"missing Spotlight accessibility contract {fragment!r}: {filename}")
    spotlight_results = spotlight_qml.get("SearchResults.qml", "")
    for contract in (
        "Image {",
        'source: resultRow.modelData.type === "application" ? (resultRow.modelData.icon || "") : ""',
        'visible: resultRow.modelData.type === "application"',
        "resultApplicationIcon.status !== Image.Ready",
        'name: resultRow.modelData.type === "calculator" ? "calculate" : "apps"',
    ):
        if contract not in spotlight_results:
            errors.append(f"Spotlight results are missing URL icon/fallback contract: {contract}")
    result_key_handler = re.search(
        r"Keys\.onPressed:\s*event\s*=>\s*\{"
        r"[\s\S]*?event\.key\s*===\s*Qt\.Key_Down"
        r"[\s\S]*?moveSelection\(1\)"
        r"[\s\S]*?event\.key\s*===\s*Qt\.Key_Up"
        r"[\s\S]*?moveSelection\(-1\)",
        spotlight_results,
    )
    if not result_key_handler:
        errors.append("Focused Spotlight result rows must forward Up/Down selection to SpotlightModel")
    result_key_block = re.search(
        r"Keys\.onPressed:\s*event\s*=>\s*\{[\s\S]*?\n\s*\}"
        r"(?=\n\s*Accessible\.role)",
        spotlight_results,
    )
    key_block_text = result_key_block.group(0) if result_key_block else ""
    pointer_activates_row = re.search(
        r"TapHandler\s*\{\s*onTapped:\s*root\.activate\(resultRow\.index\)\s*\}",
        spotlight_results,
    )
    keyboard_activates_selection = re.search(
        r"if\s*\(root\.spotlightModel\.activateSelected\(\)\)"
        r"\s*root\.activatedSuccessfully\(\);",
        key_block_text,
    )
    if (
        not pointer_activates_row
        or not keyboard_activates_selection
        or "root.activate(resultRow.index)" in key_block_text
    ):
        errors.append("Spotlight result keyboard activation must use model selection, not focused row index")

    coordinator_text = (root / "Titonium/Foundation/SurfaceCoordinator.qml").read_text(encoding="utf-8")
    if "cancelPreviewOnClose" not in coordinator_text or "ConfigStore.cancel()" not in coordinator_text:
        errors.append("SurfaceCoordinator must rollback abandoned preview transactions")
    for contract in (
        "property string guardedOwnerId",
        "readonly property bool ownerGuarded",
        "function guardOwner(requestOwnerId: string): bool",
        "function releaseOwnerGuard(requestOwnerId: string): bool",
        "function forceClose(requestOwnerId: string): bool",
    ):
        if contract not in coordinator_text:
            errors.append(f"SurfaceCoordinator is missing owner lifecycle guard: {contract}")
    if coordinator_text.count("if (root.ownerGuarded)") < 2:
        errors.append("SurfaceCoordinator ordinary open and close must veto a guarded owner")
    if "root.cancelPreviewIfOwned(requestDescriptor)" not in coordinator_text:
        errors.append("a guarded replacement must roll back its rejected preview transaction")

    config_store_text = (root / "Titonium/Foundation/ConfigStore.qml").read_text(encoding="utf-8")
    for contract in ("committedLayout", "previewLayout", "patchLayout", "restoreLayout", "runtimeLayoutFile.setText"):
        if contract not in config_store_text:
            errors.append(f"ConfigStore is missing layout transaction contract: {contract}")
    if ".concat(Validator.validateLayout(root.previewLayout))" not in config_store_text:
        errors.append("ConfigStore Apply must revalidate both transaction documents")

    material_text = (root / "Titonium/Design/MaterialSurface.qml").read_text(encoding="utf-8")
    if 'requested === "auto"' not in material_text or 'allowed.indexOf("qml")' not in material_text:
        errors.append("MaterialSurface must resolve auto/native through the QML fallback")
    surface_text = (root / "Titonium/Design/Controls/Surface.qml").read_text(encoding="utf-8")
    if 'backend: "solid"' in surface_text:
        errors.append("semantic Surface must not override the active theme material policy")
    catalog_text = (root / "Titonium/Foundation/ThemeCatalog.qml").read_text(encoding="utf-8")
    if "blockAllReads: true" not in catalog_text:
        errors.append("dynamic theme package reads must not return stale FileView content")

    capability_text = (root / "Titonium/Platform/Hyprland/HyprglassCapability.qml").read_text(encoding="utf-8")
    if '["hyprctl", "plugin", "list"]' not in capability_text or "running: true" not in capability_text:
        errors.append("hyprglass capability must use exactly one startup probe")
    if re.search(r"\bTimer\s*\{|restart|execDetached", capability_text):
        errors.append("hyprglass capability probe must never poll, mutate or retry")

    frame_feature = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (root / "Titonium/Modules/Frame").glob("*.qml")
    )
    if re.search(r"\b(Canvas|Timer|Process|MultiEffect|ShaderEffect)\s*\{", frame_feature):
        errors.append("Frame must remain geometry-only and event-driven")
    if "mask: Region {}" not in frame_feature or "FrameModel.enabled ? Quickshell.screens : []" not in frame_feature:
        errors.append("Frame must be click-through and absent while disabled")

    accessibility_contracts = {
        "Button.qml": ("activeFocusOnTab:", "Accessible.role:", "Accessible.name:", "Accessible.focusable:"),
        "Card.qml": ("activeFocusOnTab:", "Accessible.role:", "Accessible.name:", "Accessible.focusable:"),
        "Switch.qml": ("activeFocusOnTab:", "Accessible.role:", "Accessible.name:", "Accessible.focusable:"),
        "Slider.qml": ("activeFocusOnTab:", "Accessible.role:", "Accessible.name:", "Accessible.focusable:"),
        "Dropdown.qml": ("activeFocusOnTab:", "Accessible.role:", "Accessible.name:", "Accessible.focusable:"),
        "Tabs.qml": ("activeFocusOnTab:", "Accessible.PageTabList", "Accessible.name:", "Accessible.focusable:"),
    }
    controls = root / "Titonium/Design/Controls"
    for filename, required_fragments in accessibility_contracts.items():
        text = (controls / filename).read_text(encoding="utf-8")
        for fragment in required_fragments:
            if fragment not in text:
                errors.append(f"missing accessibility contract {fragment!r}: Titonium/Design/Controls/{filename}")

    if errors:
        print("\n".join(f"FAIL {error}" for error in errors), file=sys.stderr)
        return 1
    print("PASS architecture boundaries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
