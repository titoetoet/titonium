#!/usr/bin/env python3

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PAGES = ROOT / "Titonium/Settings/pages"
COMPONENTS = ROOT / "Titonium/Settings/components"


def source(path: Path, errors: list[str]) -> str:
    if not path.is_file():
        errors.append(f"missing {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8")


def require(text: str, label: str, fragments: tuple[str, ...], errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in text:
            errors.append(f"{label} missing contract: {fragment}")


def main() -> int:
    errors: list[str] = []
    appearance = source(PAGES / "AppearancePage.qml", errors)
    spotlight = source(PAGES / "SpotlightPage.qml", errors)
    bar = source(PAGES / "BarPage.qml", errors)
    dock = source(PAGES / "DockPage.qml", errors)
    dock_editor = source(COMPONENTS / "DockApplicationEditor.qml", errors)
    notifications = source(PAGES / "NotificationsPage.qml", errors)
    audio = source(PAGES / "AudioPage.qml", errors)
    about = source(PAGES / "AboutPage.qml", errors)
    applications = source(COMPONENTS / "ApplicationVisibilityList.qml", errors)
    workspace = source(ROOT / "Titonium/Settings/SettingsWorkspace.qml", errors)
    service = source(ROOT / "Titonium/Services/Applications/ApplicationService.qml", errors)
    pages_qmldir = source(PAGES / "qmldir", errors)
    components_qmldir = source(COMPONENTS / "qmldir", errors)

    require(appearance, "AppearancePage", (
        'Preferences.patch("appearance.mode", "dark")',
        'Preferences.patch("appearance.mode", "light")',
        "Preferences.restoreAppearance()", "settings.appearance.identity",
        "settings.appearance.solid", "settings.appearance.restore",
    ), errors)
    for forbidden in ("themeId", "density", "glass", "blur", "materialBackend", "MultiEffect"):
        if forbidden in appearance:
            errors.append(f"AppearancePage exposes deferred control: {forbidden}")

    require(spotlight, "SpotlightPage", (
        '"slide-fade"', '"fade"', '"none"', "Shared.Select", "Shared.Slider",
        "from: 0", "to: 500", "stepSize: 20",
        'Preferences.patch("modules.spotlight.pageTransition"',
        'Preferences.patch("modules.spotlight.transitionDuration"',
        "Preferences.hiddenApplicationIds.length", "ApplicationVisibilityList {",
    ), errors)
    require(bar, "BarPage", (
        "from: 1", "to: 8", "stepSize: 1", "Shared.Slider", "Shared.Toggle",
        'Preferences.patch("modules.bar.workspaceCount"',
        'Preferences.patch("modules.bar.autoHide"', "settings.bar.workspace_count",
        'Preferences.patch("modules.bar.mascotEnabled"', "settings.bar.mascot",
        'Preferences.patch("modules.bar.style"', "settings.bar.style",
        "settings.bar.style.description",
        "settings.bar.style.connected", "settings.bar.style.classic",
    ), errors)
    require(dock, "DockPage", (
        '"auto-hide"', '"always-visible"', '"reserve-space"', '"hidden"',
        "DockStore.setVisibilityMode", "DockApplicationEditor {",
    ), errors)
    require(dock_editor, "DockApplicationEditor", (
        'property string query: ""', "DockStore.pinnedIds",
        "ApplicationService.allApplications", "ApplicationService.desktopEntryForAppId",
        "ListView {", "reuseItems: true", "DragHandler {", "dragOffsetY",
        "DockStore.movePin(pinnedRow.sourceIndex, targetIndex)",
        "DockStore.movePin(pinnedRow.index, pinnedRow.index - 1)",
        "DockStore.movePin(pinnedRow.index, pinnedRow.index + 1)", "DockStore.togglePin",
        "DockStore.isPinned(catalogRow.modelData.id)",
        "settings.dock.unavailable", "settings.dock.move_up", "settings.dock.move_down",
        "settings.dock.remove", "settings.dock.add",
        "Qt.Key_Up", "Qt.Key_Down",
    ), errors)
    for forbidden in ("ApplicationService.launch", "DockService.launchNew", "activateOrLaunch"):
        if forbidden in dock + dock_editor:
            errors.append(f"Dock Settings must not launch applications: {forbidden}")
    require(notifications, "NotificationsPage", (
        "Shared.Toggle", "Shared.Slider", "from: 2000", "to: 10000", "stepSize: 500",
        'Preferences.patch("modules.notifications.toastsEnabled"',
        'Preferences.patch("modules.notifications.toastDuration"',
    ), errors)
    require(audio, "AudioPage", (
        "Shared.Toggle", "Preferences.allowAudioAmplification",
        'Preferences.patch("modules.audio.allowAmplification"',
    ), errors)
    require(about, "AboutPage", (
        "ScreenPolicy.targetScreenName", "Preferences.runtimePath",
        "ApplicationService.allApplications.length", "AudioService.ready",
        "NetworkService.available", "BluetoothService.available",
        "NotificationService.notifications.length", "NotificationService.unreadCount",
        "settings.state.ready", "settings.state.unavailable",
    ), errors)
    for forbidden in ("Preferences.patch", "Preferences.apply", "Timer {", "Process", "FileView"):
        if forbidden in about:
            errors.append(f"About page must stay read-only/event-driven: {forbidden}")
    require(applications, "ApplicationVisibilityList", (
        'property string query: ""', "ApplicationService.allApplications",
        "ListView {", "reuseItems: true", "currentIndex: -1", "Shared.SystemIcon",
        "Shared.Toggle", "ApplicationService.hiddenIdsForVisibility(",
        'Preferences.patch("applications.hiddenIds"',
    ), errors)
    if "ApplicationService.launch" in applications or "onActivated:" in applications:
        errors.append("Application visibility rows must never launch applications")
    require(service, "ApplicationService", (
        "function hiddenIdsForVisibility(hiddenIds: var, entryId: string, visible: bool): var",
        "return Visibility.setVisible(hiddenIds, entryId, visible)",
    ), errors)
    require(workspace, "SettingsWorkspace", (
        "function componentFor(pageId: string): Component", "appearancePage", "spotlightPage",
        "barPage", "dockPage", "notificationsPage", "audioPage", "aboutPage",
        "primaryNavigationEntries", "aboutNavigationEntry",
        "model: root.primaryNavigationEntries",
        "sourceComponent: root.componentFor(SettingsCoordinator.requestedPage)",
    ), errors)
    require(pages_qmldir, "pages/qmldir", (
        "AppearancePage 1.0 AppearancePage.qml", "SpotlightPage 1.0 SpotlightPage.qml",
        "BarPage 1.0 BarPage.qml",
        "DockPage 1.0 DockPage.qml",
        "NotificationsPage 1.0 NotificationsPage.qml", "AudioPage 1.0 AudioPage.qml",
        "AboutPage 1.0 AboutPage.qml",
    ), errors)
    require(components_qmldir, "components/qmldir", (
        "ApplicationVisibilityList 1.0 ApplicationVisibilityList.qml",
        "DockApplicationEditor 1.0 DockApplicationEditor.qml",
    ), errors)

    keys = (
        "settings.nav.appearance", "settings.appearance.title", "settings.appearance.description",
        "settings.appearance.dark", "settings.appearance.light", "settings.appearance.identity",
        "settings.appearance.solid", "settings.appearance.restore", "settings.nav.spotlight",
        "settings.spotlight.title", "settings.spotlight.description",
        "settings.spotlight.transition", "settings.spotlight.transition.slide_fade",
        "settings.spotlight.transition.fade", "settings.spotlight.transition.none",
        "settings.spotlight.duration", "settings.spotlight.hidden_count",
        "settings.spotlight.applications.search", "settings.spotlight.applications.empty",
        "settings.spotlight.applications.visible", "settings.spotlight.applications.hidden",
        "settings.nav.bar", "settings.bar.title", "settings.bar.description",
        "settings.bar.workspace_count", "settings.bar.auto_hide",
        "settings.bar.auto_hide.description", "settings.bar.mascot",
        "settings.bar.mascot.description",
        "settings.bar.style", "settings.bar.style.description", "settings.bar.style.connected",
        "settings.bar.style.classic",
        "settings.nav.dock", "settings.dock.title", "settings.dock.description",
        "settings.dock.mode", "settings.dock.mode.auto_hide",
        "settings.dock.mode.always_visible", "settings.dock.mode.reserve_space",
        "settings.dock.pinned", "settings.dock.catalog", "settings.dock.search",
        "settings.dock.add", "settings.dock.remove", "settings.dock.move_up",
        "settings.dock.move_down", "settings.dock.unavailable",
        "settings.nav.notifications", "settings.notifications.title",
        "settings.notifications.description", "settings.notifications.toasts",
        "settings.notifications.duration", "settings.nav.audio", "settings.audio.title",
        "settings.audio.description", "settings.audio.amplification",
        "settings.audio.amplification.description", "settings.nav.about",
        "settings.about.title", "settings.about.description", "settings.about.schema",
        "settings.about.screen", "settings.about.runtime", "settings.about.applications",
        "settings.about.audio", "settings.about.network", "settings.about.bluetooth",
        "settings.about.notifications", "settings.state.ready", "settings.state.unavailable",
    )
    for locale in ("en", "vi"):
        catalog = json.loads((ROOT / f"config/i18n/{locale}.json").read_text(encoding="utf-8"))["strings"]
        for key in keys:
            if not isinstance(catalog.get(key), str) or not catalog[key]:
                errors.append(f"{locale} catalog missing Settings page key: {key}")

    feature = appearance + spotlight + applications + bar + dock + dock_editor \
        + notifications + audio + about
    for forbidden in ("Process", "FileView", "Quickshell.Services", "MultiEffect", "ShaderEffect"):
        if forbidden in feature:
            errors.append(f"Settings pages have forbidden dependency: {forbidden}")

    if errors:
        print("\n".join("FAIL " + error for error in errors))
        return 1
    print("PASS Appearance and Spotlight/Application Settings pages")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
