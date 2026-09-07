#!/usr/bin/env python3
"""Exercise real presentation components without native shell or persistence services."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
runner = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"
with tempfile.TemporaryDirectory(prefix="titonium-settings-ui-") as directory:
    imports = Path(directory) / "imports"
    module = imports / "qs/Titonium"
    for name in ("Shared", "Theme", "Services/Appearance", "Settings"):
        shutil.copytree(ROOT / "Titonium" / name, module / name, dirs_exist_ok=True)
    runtime = module / "Core/Runtime"
    runtime.mkdir(parents=True)
    (runtime / "qmldir").write_text("module qs.Titonium.Core.Runtime\nsingleton Preferences 1.0 Preferences.qml\nsingleton I18n 1.0 I18n.qml\n")
    (runtime / "Preferences.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property var effectiveState: ({appearance: {mode: "dark", themeId: "neutral"}, accessibility: {reducedMotion: true}})
    readonly property var settings: effectiveState
    readonly property var committedState: effectiveState
    property string locale: "en"
    property bool reducedMotion: false
    property string lastError: ""
    property bool dirty: false
    property bool savePending: false
    property string runtimePath: "/tmp/settings-fixture/settings.json"
    property var bar: ({workspaceCount:5,height:44,mascot:"dog",mascotEnabled:true,autoHide:false})
    property string barStyle: "connected"
    property var dock: ({style:"follow-topbar"})
    property var spotlight: ({pageTransition:"slide-fade",transitionDuration:220})
    property var notifications: ({policyMode:"automatic",toastDuration:5000})
    property var hiddenApplicationIds: []
    property bool allowAudioAmplification: false
    function patch(path, value) { if (path === "locale") locale = value;
        if (path === "appearance.mode") effectiveState = {appearance:{themeId:"modern-flat",mode:value},accessibility:{reducedMotion:true}};
        dirty = true; }
}
''')
    (runtime / "I18n.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property var catalogs: STRINGS
    readonly property var strings: catalogs[Preferences.locale]
    function tr(key, values) {
        let text = strings[key] || key;
        for (const name of Object.keys(values || {})) text = text.replace("{" + name + "}", values[name]);
        return text;
    }
}
'''.replace('STRINGS', json.dumps({locale: json.loads((ROOT / f'config/i18n/{locale}.json').read_text())['strings'] for locale in ('en', 'vi')})))
    settings = module / "Settings"
    (settings / "qmldir").write_text("module qs.Titonium.Settings\nsingleton AppearanceCoordinator 1.0 AppearanceCoordinator.qml\n")
    (settings / "AppearanceCoordinator.qml").write_text('''pragma Singleton
import QtQuick
import qs.Titonium.Services.Appearance
QtObject {
    property var candidate: ({appearance: {themeId: "glass", mode: "dark", wallpaper: {policy: "keep"}}, reducedMotion: false})
    readonly property var tokens: AppearanceService.resolveCandidate(candidate)
    property string editMode: "dark"
    property bool advancedOpen: false
    property bool trialActive: false
    property int remainingSeconds: 15
    property bool busy: false
    property bool finalizationPending: false
    readonly property bool themeWallpaperMissing: false
    function retryFinalization() { return true; }
    property string error: ""
    property bool canUndo: false
    property bool dirty: false
    function editable() { return !busy && !trialActive; }
    function setAdvancedOpen(value) { advancedOpen = value; }
    function startTrial() { trialActive = true; }
    function cancelTrial() { trialActive = false; }
    function keepTrial() { trialActive = false; }
}
''')
    wallpapers = module / "Services/Wallpapers"
    wallpapers.mkdir()
    (wallpapers / "qmldir").write_text("module qs.Titonium.Services.Wallpapers\nsingleton WallpapersService 1.0 WallpapersService.qml\n")
    (wallpapers / "WallpapersService.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    readonly property bool appearanceAvailable: false
    function refreshAppearanceCapability() {}
}
''')
    with (settings / "qmldir").open("a") as f:
        f.write("SettingsWorkspace 1.0 SettingsWorkspace.qml\nsingleton SettingsCoordinator 1.0 SettingsCoordinator.qml\n")
    (settings / "SettingsCoordinator.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property bool active: true
    property bool busy: false
    property bool dirty: false
    property string requestedPage: "general"
    property bool discardConfirmationVisible: false
    function requestPage(page) { requestedPage = page; }
    function restoreDefaults(all) {}
    function requestClose() {}
    function discardAndClose() {}
    function apply() {}
}
''')
    def stub(folder, name, body):
        dest = module / folder
        dest.mkdir(parents=True, exist_ok=True)
        (dest / "qmldir").write_text(f"module qs.Titonium.{folder.replace('/', '.')}\nsingleton {name} 1.0 {name}.qml\n")
        (dest / (name + ".qml")).write_text("pragma Singleton\nimport QtQuick\nQtObject {\n" + body + "\n}\n")
    stub("Core/Screens", "ScreenPolicy", 'property string targetScreenName: "DP-1"')
    stub("Services/Applications", "ApplicationService", '''property var allApplications: [{id:"sample.desktop",name:"A long application name for Settings layout",icon:""}]
    function desktopEntryForAppId(id) { return allApplications[0]; }
    function iconForAppId(id) { return ""; }''')
    stub("Services/Dock", "DockStore", '''property var pinnedIds: ["sample.desktop"]
    property string visibilityMode: "auto-hide"
    function isPinned(id) { return pinnedIds.indexOf(id)>=0; }''')
    stub("Services/Audio", "AudioService", 'property bool ready: false')
    stub("Services/Network", "NetworkService", 'property bool available: false')
    stub("Services/Bluetooth", "BluetoothService", 'property bool available: false')
    stub("Services/Notifications", "NotificationCoordinator", '''property var history: [{source:"native",appId:"sample.desktop",appName:"A long application name for Settings layout"}]
    property int unreadCount: 0''')
    # Native icon lookup is outside the layout test; keep its presentation dimensions.
    (module / "Shared/SystemIcon.qml").write_text('import QtQuick\nItem { property string sourceName: ""; property string fallbackName: ""; property int size: 32; implicitWidth: size; implicitHeight: size }\n')
    result = subprocess.run([runner, "-input", str(ROOT / "scripts/fixtures/settings_ui"), "-import", str(imports)],
        env={**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"},
        capture_output=True, text=True, timeout=30)
    print(result.stdout, end="")
    print(result.stderr, end="")
    if result.returncode:
        raise SystemExit(result.returncode)
    if any(marker in result.stdout + result.stderr for marker in ("QWARN", "TypeError", "ReferenceError", "Binding loop", "Unable to assign")):
        raise SystemExit("FAIL QML runtime warning")
for locale in ("en", "vi"):
    strings = json.loads((ROOT / f"config/i18n/{locale}.json").read_text())["strings"]
    other = json.loads((ROOT / f"config/i18n/{'vi' if locale == 'en' else 'en'}.json").read_text())["strings"]
    assert set(strings) == set(other), "i18n keys differ"
print("PASS Settings layout and control regressions in both locales")
