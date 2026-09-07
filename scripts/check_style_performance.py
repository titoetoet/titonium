#!/usr/bin/env python3
"""Offline software scene protocol; /proc metrics describe only qmltestrunner.

FrameSwapped counts are offscreen submissions, not GPU/display frame timings.
Uses the production control harness with inert services and private temporary imports.
"""
import json
import os
from pathlib import Path
import runpy
import subprocess
import threading
import time
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SAMPLES = {}
FD_TARGETS = {}
PHASE = "startup"
HZ = os.sysconf("SC_CLK_TCK")


def measured_run(argv, **kwargs):
    global PHASE
    if "qmltestrunner" not in str(argv[0]):
        raise RuntimeError("Performance harness expects only the offline QML runner")
    kwargs.pop("capture_output", None)
    timeout = kwargs.pop("timeout", 90)
    process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, **kwargs)
    stopped = threading.Event()

    def sample():
        while not stopped.wait(.1):
            try:
                stat = Path(f"/proc/{process.pid}/stat").read_text().split(")", 1)[1].split()
                cpu = (int(stat[11]) + int(stat[12])) / HZ
                rss = int(stat[21]) * os.sysconf("SC_PAGE_SIZE")
                fd_paths = list(Path(f"/proc/{process.pid}/fd").iterdir())
                fds = len(fd_paths)
                targets = []
                for fd in fd_paths:
                    try:
                        targets.append(os.readlink(fd))
                    except FileNotFoundError:
                        pass
                FD_TARGETS[PHASE] = sorted(targets)
                SAMPLES.setdefault(PHASE, []).append((time.monotonic(), cpu, rss, fds))
            except (FileNotFoundError, ProcessLookupError):
                return

    watcher = threading.Thread(target=sample, daemon=True)
    watcher.start()
    deadline = threading.Timer(timeout, process.kill)
    deadline.start()
    lines = []
    try:
        for line in process.stdout:
            lines.append(line)
            if "PERF_PHASE " in line:
                PHASE = line.split("PERF_PHASE ", 1)[1].strip()
        process.wait()
    finally:
        stopped.set(); watcher.join(); deadline.cancel()
    return subprocess.CompletedProcess(argv, process.returncode, "".join(lines), "")


os.environ["STYLE_QPA"] = "offscreen"
os.environ["STYLE_BACKEND"] = "software"
os.environ.pop("STYLE_LINT", None)
with patch("subprocess.run", measured_run):
    runpy.run_path(str(ROOT / "scripts/check_style_controls.py"), init_globals={"FIXTURE_NAME": "style_performance"})

report = {}
for phase, samples in SAMPLES.items():
    if len(samples) < 2:
        continue
    first, last = samples[0], samples[-1]
    elapsed = last[0] - first[0]
    report[phase] = {
        "sampled_seconds": round(elapsed, 3),
        "cpu_one_core_percent": round(100 * (last[1] - first[1]) / elapsed, 3),
        "rss_first_kib": first[2] // 1024,
        "rss_last_kib": last[2] // 1024,
        "rss_peak_kib": max(s[2] for s in samples) // 1024,
        "fds_first": first[3], "fds_last": last[3],
        "fd_targets_last": FD_TARGETS.get(phase, []),
    }
print("PERF_METRICS " + json.dumps(report, sort_keys=True))
