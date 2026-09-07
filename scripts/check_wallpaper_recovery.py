#!/usr/bin/env python3
"""Exercise the real wallpaper service's recovery timer with inert QML I/O."""
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="wallpaper-recovery-") as temporary:
    base = Path(temporary)

    def put(name, text):
        path = base / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    put("Quickshell/qmldir", "module Quickshell\nsingleton Quickshell 1.0 Quickshell.qml\n")
    put("Quickshell/Quickshell.qml", '''pragma Singleton
import QtQuick
QtObject {
 property var screens: [{name:"DP-1"}]
 function shellPath(path) { return path; }
}''')
    put("Quickshell/Io/qmldir", "module Quickshell.Io\nProcess 1.0 Process.qml\nStdioCollector 1.0 StdioCollector.qml\n")
    put("Quickshell/Io/StdioCollector.qml", 'import QtQuick\nQtObject { property string text: "" }\n')
    put("Quickshell/Io/Process.qml", '''import QtQuick
QtObject {
 property bool running: false
 property var command: []
 property QtObject stdout
 property QtObject stderr
 property int starts: 0
 signal exited(int exitCode)
 onRunningChanged: if (running) starts += 1
 function complete(result) {
  stdout.text = JSON.stringify(result);
  running = false;
  exited(0);
 }
}''')
    put("qs/Titonium/Core/Runtime/qmldir", "module qs.Titonium.Core.Runtime\nsingleton Preferences 1.0 Preferences.qml\n")
    put("qs/Titonium/Core/Runtime/Preferences.qml", '''pragma Singleton
import QtQuick
QtObject {
 property bool ready: false
 property bool previewActive: false
 property var committedState: ({appearance:{wallpaper:{policy:"keep"}}})
}''')
    put("qs/Titonium/Services/Appearance/qmldir", "module qs.Titonium.Services.Appearance\nsingleton AppearanceService 1.0 AppearanceService.qml\n")
    put("qs/Titonium/Services/Appearance/AppearanceService.qml", '''pragma Singleton
import QtQuick
QtObject {
 property string systemMode: "dark"
 property var trialCandidate: null
 property var catalog: []
 function themeDescriptor(id) { return catalog.find(item => item.id === id); }
 function resolveCandidate(candidate) { return {themeId:"neutral",mode:"dark"}; }
}''')
    put("qs/Titonium/Services/Wallpapers/qmldir", "module qs.Titonium.Services.Wallpapers\nsingleton WallpapersService 1.0 WallpapersService.qml\n")
    (base / "qs/Titonium/Services/Wallpapers/WallpapersService.qml").symlink_to(
        ROOT / "Titonium/Services/Wallpapers/WallpapersService.qml")
    put("tst_recovery.qml", '''import QtQuick
import QtTest
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Wallpapers
TestCase {
 name: "WallpaperRecovery"
 property var service: WallpapersService
 function init() {
  service.recoveryRetry.stop();
  service.worker.running = false;
  service.operation = "";
  service.appearanceLease = true;
  service.appearanceRecoveryReady = false;
  service.canCaptureBaseline = false;
  service.managedWallpaper = false;
  service.recoveryRetries = 0;
  service.recoveryRetry.interval = 20;
  service.followPending = false;
  Preferences.ready = false;
 }
 function cleanup() { service.recoveryRetry.stop(); }
 function complete(result) {
  service.worker.complete(result);
  tryCompare(service, "busy", false);
 }
 function unavailableManaged() {
  return {ok:true,managed:true,lease:false,canCaptureBaseline:false,capabilityError:"unavailable"};
 }
 function recovered() {
  return {ok:true,managed:true,lease:false,canCaptureBaseline:true,capabilityError:""};
 }
 function test_startup_managed_unavailable_retries_then_stops() {
  verify(service.recoverAppearance({}));
  complete(unavailableManaged());
  verify(service.recoveryRetry.running);
  tryCompare(service, "operation", "appearance-recover");
  compare(service.recoveryRetries, 1);
  complete(recovered());
  verify(!service.recoveryRetry.running);
  verify(service.appearanceRecoveryReady);
  verify(service.canCaptureBaseline);
  const starts = service.worker.starts;
  wait(60);
  compare(service.worker.starts, starts);
 }
 function test_pending_journal_unavailable_retries_without_managed_metadata() {
  verify(service.recoverAppearance({}));
  complete({ok:false,error:"unavailable",lease:true});
  verify(!service.appearanceRecoveryReady);
  verify(service.recoveryRetry.running);
  tryCompare(service, "operation", "appearance-recover");
  compare(service.recoveryRetries, 1);
  complete(recovered());
  verify(!service.appearanceLease);
 }
 function test_successful_manual_retry_clears_queued_timer_before_trial() {
  service.recoveryRetry.interval = 100;
  verify(service.recoverAppearance({}));
  complete(unavailableManaged());
  verify(service.recoveryRetry.running);
  verify(service.refreshAppearanceCapability());
  complete(recovered());
  verify(!service.recoveryRetry.running);
  verify(service.beginAppearance("DP-1", "/fake.png", 4, {}));
  complete({ok:true,lease:true,snapshot:{screenName:"DP-1",path:"/old.png",fit:"cover"}});
  const starts = service.worker.starts;
  wait(150);
  compare(service.worker.starts, starts);
  verify(service.appearanceLease);
  compare(service.appearanceGeneration, 4);
 }
 function test_retry_does_not_consume_interactive_lease() {
  service.appearanceRecoveryReady = true;
  service.appearanceLease = true;
  service.canCaptureBaseline = false;
  const starts = service.worker.starts;
  service.recoveryRetry.start();
  wait(60);
  compare(service.worker.starts, starts);
  compare(service.recoveryRetries, 0);
 }
 function test_retry_budget_is_bounded() {
  service.recoveryRetries = 10;
  verify(service.recoverAppearance({}));
  complete({ok:false,error:"unavailable",lease:true});
  verify(!service.recoveryRetry.running);
  const starts = service.worker.starts;
  wait(60);
  compare(service.worker.starts, starts);
 }
}''')
    result = subprocess.run(
        ["/usr/lib/qt6/bin/qmltestrunner", "-input", str(base), "-import", str(base)],
        env={**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"},
        timeout=20,
    )
    raise SystemExit(result.returncode)
