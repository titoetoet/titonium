#!/usr/bin/env python3
"""Exercise the real Bluetooth agent lifecycle with no native process or adapter."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    with tempfile.TemporaryDirectory(prefix='titonium-bluetooth-agent-') as directory:
        base = Path(directory)

        def module(name, files):
            path = base / name.replace('.', '/')
            path.mkdir(parents=True, exist_ok=True)
            exports = ['module ' + name]
            for key, source in files.items():
                (path / (key + '.qml')).write_text(source)
                exports.append(('singleton ' if source.startswith('pragma Singleton') else '')
                               + key + ' 1.0 ' + key + '.qml')
            (path / 'qmldir').write_text('\n'.join(exports))
            return path

        module('Quickshell.Bluetooth', {'BluetoothDeviceState': '''import QtQuick
QtObject { enum State { Connecting, Disconnecting } }''', 'Bluetooth': '''pragma Singleton
import QtQuick
QtObject {
 property QtObject firstAdapter: QtObject {
  property string name: "Test adapter"
  property bool enabled: true
  property bool discovering: false
  property QtObject devices: QtObject { property var values: [] }
 }
 property QtObject secondAdapter: QtObject {
  property string name: "Other adapter"
  property bool enabled: true
  property bool discovering: false
  property QtObject devices: QtObject { property var values: [] }
 }
 property var defaultAdapter: null
}'''})
        module('Quickshell.Io', {
            'Process': '''import QtQuick
QtObject {
 id: root
 property var command: []
 property bool stdinEnabled: false
 property var stdout: null
 property var stderr: null
 property bool running: false
 property int starts: 0
 signal started()
 signal exited(int exitCode, int exitStatus)
 onRunningChanged: if (running) { starts += 1; started(); }
 function fail() { running = false; exited(1, 0); }
}''', 'StdioCollector': '''import QtQuick
QtObject { property bool waitForEnd: false }'''})
        module('qs.Titonium.Core.Runtime', {
            'Logger': '''pragma Singleton
import QtQuick
QtObject {
 property int warnings: 0
 function warn(source, message) { warnings += 1; }
 function info(source, message) {}
}''', 'I18n': '''pragma Singleton
import QtQuick
QtObject { function tr(key, values) { return key; } }'''})
        module('qs.Titonium.Services.Center', {'CenterAttentionService': '''pragma Singleton
import QtQuick
QtObject {
 function publish(event) {}
 function setIndicator(id, icon, text, active) {}
}'''})
        service = ROOT / 'Titonium/Services/Bluetooth'
        path = module('qs.Titonium.Services.Bluetooth', {'BluetoothService': (service / 'BluetoothService.qml').read_text()})
        shutil.copyfile(service / 'BluetoothRules.js', path / 'BluetoothRules.js')
        (base / 'tst_agent.qml').write_text('''import QtQuick
import QtTest
import Quickshell.Bluetooth
import qs.Titonium.Services.Bluetooth
import qs.Titonium.Core.Runtime

TestCase {
 name: "BluetoothAgent"
 function init() {
  Bluetooth.defaultAdapter = null;
  if (BluetoothService.agentProcess.running) BluetoothService.agentProcess.fail();
  BluetoothService.agentProcess.starts = 0;
  BluetoothService.operationWarningCounts = ({});
  Logger.warnings = 0;
  BluetoothService.agentStable.interval = 30000;
  Bluetooth.defaultAdapter = Bluetooth.firstAdapter;
  tryCompare(BluetoothService.agentProcess, "running", true);
  compare(BluetoothService.agentProcess.starts, 1);
 }
 function cleanup() {
  Bluetooth.defaultAdapter = null;
  if (BluetoothService.agentProcess.running) BluetoothService.agentProcess.fail();
  Bluetooth.firstAdapter.devices.values = [];
  BluetoothService.resetPairing();
 }
 function expireRetry() {
  // Keep production scheduling logic; accelerate only the clock interval.
  BluetoothService.agentRetry.interval = 1;
  tryCompare(BluetoothService.agentProcess, "running", true);
 }
 function test_backoffPreventsImmediateRestart() {
  BluetoothService.agentProcess.fail();
  wait(30);
  compare(BluetoothService.agentProcess.starts, 1, "agent exit must not relaunch on the next event-loop turn");
  verify(BluetoothService.agentRetry.running);
  compare(BluetoothService.agentRetry.interval, 1000);
  BluetoothService.ensureAgent();
  compare(BluetoothService.agentProcess.starts, 1, "ensureAgent must respect the pending backoff");
  expireRetry();
  compare(BluetoothService.agentProcess.starts, 2);
 }
 function test_repeatedFailuresStop() {
  for (const delay of [1000, 2000, 4000, 8000, 16000]) {
   BluetoothService.agentProcess.fail();
   compare(BluetoothService.agentRetry.interval, delay);
   verify(BluetoothService.agentRetry.running);
   expireRetry();
  }
  compare(BluetoothService.agentProcess.starts, 6);
  BluetoothService.agentProcess.fail();
  verify(!BluetoothService.agentRetry.running);
  BluetoothService.ensureAgent();
  wait(30);
  compare(BluetoothService.agentProcess.starts, 6, "exhausted retries must stop spawning");
  verify(Logger.warnings <= 4, "crash-loop logs must stay bounded");
 }
 function test_adapterLossCancelsPendingRetry() {
  BluetoothService.agentProcess.fail();
  Bluetooth.defaultAdapter = null;
  verify(!BluetoothService.agentRetry.running);
  BluetoothService.ensureAgent();
  compare(BluetoothService.agentProcess.starts, 1);
  Bluetooth.defaultAdapter = Bluetooth.firstAdapter;
  tryCompare(BluetoothService.agentProcess, "running", true);
  compare(BluetoothService.agentProcess.starts, 2);
  BluetoothService.agentProcess.fail();
  compare(BluetoothService.agentRetry.interval, 1000, "adapter recovery starts a fresh budget");
 }
 function test_adapterReplacementRestartsExhaustedAgent() {
  for (let i = 0; i < 5; ++i) { BluetoothService.agentProcess.fail(); expireRetry(); }
  BluetoothService.agentProcess.fail();
  Bluetooth.defaultAdapter = Bluetooth.secondAdapter;
  tryCompare(BluetoothService.agentProcess, "running", true);
  compare(BluetoothService.agentProcess.starts, 7);
 }
 function test_healthyAgentSurvivesAdapterReplacement() {
  Bluetooth.defaultAdapter = Bluetooth.secondAdapter;
  compare(BluetoothService.agentProcess.starts, 1, "adapter replacement must not duplicate a running global agent");
  Bluetooth.defaultAdapter = null;
  verify(!BluetoothService.agentRetry.running);
  Bluetooth.defaultAdapter = Bluetooth.firstAdapter;
  compare(BluetoothService.agentProcess.starts, 1);
 }
 function test_explicitPairingDuringBackoff() {
  BluetoothService.agentProcess.fail();
  verify(BluetoothService.agentRetry.running);
  const device = Qt.createQmlObject('import QtQuick; QtObject { property string address: "AA:BB:CC:DD:EE:FF"; property string name: "Test device"; property int state: -1; property int pairCalls: 0; property bool agentRunningWhenPaired: false; property var agent: null; function pair() { agentRunningWhenPaired = agent.running; pairCalls += 1; } }', this);
  device.agent = BluetoothService.agentProcess;
  Bluetooth.firstAdapter.devices.values = [device];
  verify(BluetoothService.pairDevice("AA:BB:CC:DD:EE:FF"));
  verify(device.agentRunningWhenPaired, "explicit pairing must start the agent before issuing pair during backoff");
  compare(device.pairCalls, 1);
  compare(BluetoothService.agentProcess.starts, 2);
  verify(!BluetoothService.agentRetry.running);
  Bluetooth.firstAdapter.devices.values = [];
  device.destroy();
 }
 function test_explicitPairingRestoresBudget() {
  for (let i = 0; i < 5; ++i) { BluetoothService.agentProcess.fail(); expireRetry(); }
  BluetoothService.agentProcess.fail();
  const device = Qt.createQmlObject('import QtQuick; QtObject { property string address: "AA:BB:CC:DD:EE:FF"; property string name: "Test device"; property int state: -1; property int pairCalls: 0; function pair() { pairCalls += 1; } }', this);
  Bluetooth.firstAdapter.devices.values = [device];
  verify(BluetoothService.pairDevice("AA:BB:CC:DD:EE:FF"));
  compare(BluetoothService.agentProcess.starts, 7);
  compare(device.pairCalls, 1);
  Bluetooth.firstAdapter.devices.values = [];
  device.destroy();
 }
 function test_stableRunRestoresBudget() {
  BluetoothService.agentProcess.fail(); expireRetry();
  BluetoothService.agentStable.interval = 1;
  tryVerify(() => !BluetoothService.agentStable.running);
  BluetoothService.agentProcess.fail();
  compare(BluetoothService.agentRetry.interval, 1000, "stable agent must not retain crash-loop backoff");
  // Restore the normal healthy threshold before the next fake process starts.
  BluetoothService.agentStable.interval = 30000;
  expireRetry();
  BluetoothService.agentProcess.fail();
  compare(BluetoothService.agentRetry.interval, 2000);
 }
}''')
        runner = shutil.which('qmltestrunner') or '/usr/lib/qt6/bin/qmltestrunner'
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
        return subprocess.run([runner, '-input', str(base), '-import', str(base)], env=env).returncode


if __name__ == '__main__':
    raise SystemExit(main())
