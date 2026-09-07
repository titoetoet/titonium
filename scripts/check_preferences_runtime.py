#!/usr/bin/env python3
"""Real FileView regression: external atomic writes refresh the committed settings."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="titonium-preferences-runtime-") as directory:
    base = Path(directory)
    (base / "Titonium").symlink_to(ROOT / "Titonium", target_is_directory=True)
    shutil.copytree(ROOT / "config/defaults", base / "config/defaults")
    (base / "shell.qml").write_text('''//@ pragma DataDir $BASE/titonium
import Quickshell
import Quickshell.Io
import qs.Titonium.Core.Runtime
ShellRoot {
    IpcHandler {
        target: "fixture"
        function state(): string { return Preferences.ready ? Preferences.barStyle + ":" + Preferences.locale : "loading"; }
        function begin(): bool { return Preferences.beginPreview(); }
        function patch(): bool { return Preferences.patch("locale", "vi"); }
        function cancel(): void { Preferences.cancel(); }
    }
}
''')
    env = {**os.environ, "QT_QPA_PLATFORM": "offscreen",
           "XDG_DATA_HOME": str(base / "data"), "XDG_STATE_HOME": str(base / "state"),
           "XDG_CACHE_HOME": str(base / "cache")}
    runtime = base / "data/titonium/settings.json"
    runtime.parent.mkdir(parents=True)
    settings = json.loads((ROOT / "config/defaults/settings.json").read_text())
    settings["locale"] = "en"
    settings["modules"]["bar"]["style"] = "connected"
    def write():
        pending = runtime.with_suffix(".new")
        pending.write_text(json.dumps(settings))
        pending.replace(runtime)
    write()
    with (base / "shell.log").open("w+") as log:
        process = subprocess.Popen(["qs", "-p", str(base), "--no-color"], env=env,
                                   stdout=log, stderr=log)
        def call(method):
            return subprocess.run(["qs", "-p", str(base), "ipc", "--pid", str(process.pid),
                                   "call", "fixture", method], env=env,
                                  capture_output=True, text=True, timeout=3).stdout.strip()
        def expect(value):
            deadline = time.monotonic() + 5
            actual = ""
            while time.monotonic() < deadline:
                actual = call("state")
                if actual == value:
                    return
                time.sleep(.05)
            log.flush()
            raise AssertionError(f"expected {value}, got {actual}\n{(base / 'shell.log').read_text()}")
        try:
            expect("connected:en")
            settings["modules"]["bar"]["style"] = "classic"
            write()
            expect("classic:en")
            # A second rename proves the watcher survives atomic replacement.
            settings["modules"]["bar"]["style"] = "connected"
            write()
            expect("connected:en")
            assert call("begin") == "true"
            assert call("patch") == "true"
            expect("connected:vi")
            settings["modules"]["bar"]["style"] = "classic"
            write()
            time.sleep(.15)
            expect("connected:vi")  # External notifications must not replace the draft.
            call("cancel")
            expect("connected:en")
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
print("PASS real Preferences FileView refresh, repeated atomic writes and preview isolation")
