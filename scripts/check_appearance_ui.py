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
with tempfile.TemporaryDirectory(prefix="titonium-appearance-ui-") as directory:
    imports = Path(directory) / "imports"
    module = imports / "qs/Titonium"
    for name in ("Shared", "Theme", "Settings/components", "Services/Appearance", "Settings/pages"):
        shutil.copytree(ROOT / "Titonium" / name, module / name)
    runtime = module / "Core/Runtime"
    runtime.mkdir(parents=True)
    (runtime / "qmldir").write_text("module qs.Titonium.Core.Runtime\nsingleton Preferences 1.0 Preferences.qml\nsingleton I18n 1.0 I18n.qml\n")
    (runtime / "Preferences.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    readonly property var effectiveState: ({appearance: {mode: "dark", themeId: "neutral"}, accessibility: {reducedMotion: false}})
    readonly property var settings: effectiveState
    readonly property var committedState: effectiveState
}
''')
    (runtime / "I18n.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property var strings: STRINGS
    function tr(key, values) {
        let text = strings[key] || key;
        for (const name of Object.keys(values || {})) text = text.replace("{" + name + "}", values[name]);
        return text;
    }
}
'''.replace('STRINGS', json.dumps(json.loads((ROOT / 'config/i18n/en.json').read_text())['strings'])))
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
    result = subprocess.run([runner, "-input", str(ROOT / "scripts/fixtures/appearance_ui"), "-import", str(imports)],
        env={**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"},
        capture_output=True, text=True, timeout=30)
    print(result.stdout, end="")
    print(result.stderr, end="")
    if result.returncode:
        raise SystemExit(result.returncode)
    if any(marker in result.stdout + result.stderr for marker in ("TypeError", "ReferenceError", "Binding loop", "Unable to assign")):
        raise SystemExit("FAIL QML runtime warning")
for locale in ("en", "vi"):
    strings = json.loads((ROOT / f"config/i18n/{locale}.json").read_text())["strings"]
    other = json.loads((ROOT / f"config/i18n/{'vi' if locale == 'en' else 'en'}.json").read_text())["strings"]
    assert set(strings) == set(other), "i18n keys differ"
print("PASS isolated Appearance QML interaction and i18n parity")
