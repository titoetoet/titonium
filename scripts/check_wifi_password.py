#!/usr/bin/env python3
"""Exercise real Wi-Fi rows/popup with offscreen Qt Quick and a fake network boundary."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    runner = shutil.which('qmltestrunner') or '/usr/lib/qt6/bin/qmltestrunner'
    with tempfile.TemporaryDirectory(prefix='titonium-wifi-password-') as directory:
        base = Path(directory)
        def module(name, files):
            path = base / name.replace('.', '/')
            path.mkdir(parents=True, exist_ok=True)
            exports = ['module ' + name]
            for key, value in files.items():
                singleton = value.startswith('pragma Singleton')
                (path / (key + '.qml')).write_text(value)
                exports.append(('singleton ' if singleton else '') + key + ' 1.0 ' + key + '.qml')
            (path / 'qmldir').write_text('\n'.join(exports))
        module('qs.Titonium.Core.Runtime', {'I18n': '''pragma Singleton
import QtQuick
QtObject { function tr(key, values) { return key; } }'''})
        module('qs.Titonium.Services.Network', {'NetworkService': '''pragma Singleton
import QtQuick
QtObject {
 property var networks: []
 property bool available: true
 property bool wifiEnabled: true
 property bool wifiHardwareEnabled: true
 property bool scanning: false
 property string connectedName: ""
 property string iconName: "wifi"
 property string stateKey: "wifi.on"
 property var submitted: null
 function connect(id) { return true; }
 function connectWithPassword(id, password) { submitted = {id: id, password: password}; return true; }
 function disconnect(id) { return true; }
 function forget(id) { return true; }
 function setScanning(value) { scanning = value; }
 function setWifiEnabled(value) { wifiEnabled = value; }
}'''})
        module('qs.Titonium.Core.Surfaces', {'SurfaceManager': '''pragma Singleton
import QtQuick
QtObject {
 property bool active: false
 function close(id) {}
 function closeOwned(id, descriptor, screen) {}
 function matches(id, descriptor, screen) { return true; }
 function beginClose(id, descriptor, screen) { return true; }
}'''})
        module('qs.Titonium.Theme', {
            'Motion': '''pragma Singleton
import QtQuick
QtObject { property bool reduced: true; property int normal: 0; property var springDamped: [0, 0, 1, 1, 1, 1] }''',
            'Metrics': '''pragma Singleton
import QtQuick
QtObject {
 property int barHeight: 32
 property int barSpacing: 8
 property int barPadding: 8
 property int spacingSmall: 8
 property int spacingMedium: 12
 property int spacingXSmall: 4
 property int controlHeightSmall: 32
 property int radiusSmall: 4
 property int borderWidth: 1
}''', 'Theme': '''pragma Singleton
import QtQuick
QtObject {
 property var material: ({backgroundOpacity:1,borderStrength:1,shadowStrength:0,sheenStrength:0,radiusScale:1})
 property var tokens: ({legacy: true})
 property bool legacy: true
 property color surface: "black"
 property color textPrimary: "white"
 property color surfaceElevated: "black"
 property color focus: "blue"
 property color border: "gray"
}'''})
        module('qs.Titonium.Shared', {
            'Panel': '''import QtQuick
Item { property color customColor; property bool clipContent; property int padding: 16 }''',
            'Icon': '''import QtQuick
Item { property string name; property int size; property string tone; property string accessibleName }''',
            'TextLabel': '''import QtQuick
Text { property string variant; property bool strong; property string tone }''',
            'Button': '''import QtQuick
Item { property string label; property string variant; property string size; property string iconName; property string accessibleName; signal triggered() }''',
            'Toggle': '''import QtQuick
Item { property bool checked; property string accessibleName; signal toggled(bool checked) }''',
            'StylePaint': '''import QtQuick
Item {
 property var tokens
 property string role
 property real radius
 property color borderColor: "transparent"
 property var interaction: ({})
 property bool outlined: true
 property bool showFocus: true
}'''})
        overlay = ROOT / 'Titonium/Overlays/Network'
        # Copy production components unchanged; isolate only their platform/presentation dependencies.
        files = {path.stem: path.read_text() for path in overlay.glob('*.qml')
                 if path.stem in ('WifiNetworkRow', 'WifiNetworkModel', 'ConnectedNetworkPopupContent',
                                  'ClassicNetworkPopupSurface')}
        module('qs.Titonium.Overlays.Network', files)
        (base / 'tst_password.qml').write_text('''import QtQuick
import QtTest
import qs.Titonium.Overlays.Network
import qs.Titonium.Services.Network

Item {
 width: 600; height: 700
 Component { id: popupComponent; ConnectedNetworkPopupContent { width: 500; height: 600 } }
 Component { id: classicComponent; ClassicNetworkPopupSurface {} }
 Component { id: rowComponent; WifiNetworkRow { width: 500 } }
 TestCase {
  name: "WifiPassword"; when: windowShown
  function descriptor(id, signal) {
   return {id: id, name: id, section: "available", secure: true, known: false,
    connected: false, transitioning: false, signal: signal, signalIcon: "wifi",
    signalKey: "wifi.signal.good", stateKey: "wifi.network.available"};
  }
  function find(item, predicate) {
   if (predicate(item)) return item;
   for (let i = 0; i < item.children.length; ++i) {
    const result = find(item.children[i], predicate);
    if (result) return result;
   }
   return null;
  }
  function rowIn(popup, id) { return find(popup, x => x.passwordPromptOpen !== undefined && x.network.id === id); }
  function inputIn(row) { return find(row, x => x.echoMode !== undefined); }
  function enter(row) {
   row.triggerConnect();
   const input = inputIn(row);
   input.forceActiveFocus();
   input.insert(0, "temporary-test-secret");
   input.cursorPosition = 7;
   verify(input.activeFocus);
   return input;
  }
  function test_sameDescriptorIdentity() {
   const row = createTemporaryObject(rowComponent, parent, {network: descriptor("Cafe", 60)});
   const input = enter(row);
   row.network = descriptor("Cafe", 70);
   verify(row.passwordPromptOpen, "same network descriptor update must preserve prompt");
   compare(input.text, "temporary-test-secret");
   compare(input.cursorPosition, 7);
   verify(input.activeFocus);
   row.network = descriptor("Other", 70);
   compare(row.password, "");
   verify(!row.passwordPromptOpen);
  }
  function test_popupRefresh_data() {
   return [{tag: "connected", component: popupComponent},
           {tag: "classic", component: classicComponent}];
  }
  function test_popupRefresh(data) {
   NetworkService.networks = [descriptor("Cafe", 60), descriptor("Other", 40)];
   const popup = createTemporaryObject(data.component, parent);
   const row = rowIn(popup, "Cafe");
   const input = enter(row);
   // A scan republishes freshly projected values; a signal update can reorder them.
   NetworkService.scanning = true;
   NetworkService.networks = [descriptor("Cafe", 60), descriptor("Other", 40)];
   compare(rowIn(popup, "Cafe"), row);
   compare(input.text, "temporary-test-secret");
   verify(input.activeFocus);
   NetworkService.networks = [descriptor("Other", 90), descriptor("Cafe", 70)];
   wait(0);
   const refreshed = rowIn(popup, "Cafe");
   verify(refreshed.passwordPromptOpen, "scan/signal array replacement must preserve password prompt");
   compare(refreshed, row, "same network must retain its delegate through sorting");
   compare(input.text, "temporary-test-secret");
   compare(input.cursorPosition, 7);
   verify(input.activeFocus);
   compare(refreshed.network.signal, 70);
   NetworkService.networks = [descriptor("New", 95), descriptor("Other", 90), descriptor("Cafe", 70)];
   compare(rowIn(popup, "Cafe"), row);
   verify(input.activeFocus);
   NetworkService.networks = [descriptor("Cafe", 70)];
   compare(rowIn(popup, "Cafe"), row);
   compare(row.password, "temporary-test-secret");
   NetworkService.networks = [];
   wait(0);
   NetworkService.networks = [descriptor("Cafe", 70)];
   compare(rowIn(popup, "Cafe").password, "");
   verify(!rowIn(popup, "Cafe").passwordPromptOpen);
  }
  function test_teardownClearsPassword() {
   const row = createTemporaryObject(rowComponent, parent, {network: descriptor("Cafe", 60)});
   enter(row);
   let lastPassword = row.password;
   row.passwordChanged.connect(function() { lastPassword = row.password; });
   row.destroy();
   wait(0);
   compare(lastPassword, "");
  }
  function test_submitCancelAndConnected() {
   const row = createTemporaryObject(rowComponent, parent, {network: descriptor("Cafe", 60)});
   enter(row);
   row.submitPassword();
   compare(NetworkService.submitted.id, "Cafe");
   compare(NetworkService.submitted.password, "temporary-test-secret");
   compare(row.password, ""); verify(!row.passwordPromptOpen);
   enter(row); row.clearPassword();
   compare(inputIn(row).text, ""); verify(!row.passwordPromptOpen);
   enter(row);
   const connected = descriptor("Cafe", 70); connected.connected = true; connected.known = true;
   row.network = connected;
   compare(row.password, ""); verify(!row.passwordPromptOpen);
  }
 }
}''')
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
        return subprocess.run([runner, '-input', str(base), '-import', str(base)], env=env).returncode


if __name__ == '__main__':
    raise SystemExit(main())
