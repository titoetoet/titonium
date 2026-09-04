#!/usr/bin/env python3

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PARSER = ROOT / "scripts/check_focus_handoff_trace.py"
FIXTURES = ROOT / "tests/fixtures"
OLD_OWNER = "center:DP-1"
NEW_OWNER = "overlay:spotlight:DP-1"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def legacy_last_match_passes(trace: str, old_owner: str, new_owner: str) -> bool:
    """Characterize the previous protected-acceptance tail-match behavior."""
    lines = trace.splitlines()
    release_lines = [index for index, line in enumerate(lines, start=1)
                     if f"released {old_owner}" in line]
    acquire_lines = [index for index, line in enumerate(lines, start=1)
                     if f"acquired {new_owner}" in line]
    return bool(release_lines and acquire_lines
                and release_lines[-1] < acquire_lines[-1])


def invoke(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(PARSER), *args], text=True,
                          capture_output=True, check=False)


def main() -> int:
    require(PARSER.is_file(), "focus handoff trace parser must exist")

    premature = (FIXTURES / "focus-handoff-premature-acquisition.log").read_text(
        encoding="utf-8")
    require(legacy_last_match_passes(premature, OLD_OWNER, NEW_OWNER),
            "fixture must prove the previous last-match helper accepted the bad trace")
    result = invoke("handoff", str(FIXTURES / "focus-handoff-premature-acquisition.log"),
                    "1", OLD_OWNER, NEW_OWNER)
    require(result.returncode == 1,
            f"cursor-aware parser must reject a premature/duplicate acquisition: {result.stderr}")
    require("before exact release" in result.stderr,
            f"premature acquisition rejection must explain the ordering failure: {result.stderr}")

    result = invoke("handoff", str(FIXTURES / "focus-handoff-duplicate-acquisition.log"),
                    "0", OLD_OWNER, NEW_OWNER)
    require(result.returncode == 1,
            f"parser must reject duplicate acquisitions: {result.stderr}")
    require("duplicate acquired" in result.stderr,
            f"duplicate acquisition rejection must explain the failure: {result.stderr}")

    result = invoke("handoff", str(FIXTURES / "focus-handoff-ordered.log"),
                    "2", OLD_OWNER, NEW_OWNER)
    require(result.returncode == 0,
            f"parser must accept one ordered post-cursor handoff: {result.stderr}")

    result = invoke("handoff", str(FIXTURES / "focus-handoff-dp10.log"),
                    "0", OLD_OWNER, NEW_OWNER)
    require(result.returncode == 1,
            f"DP-1 must not substring-match DP-10: {result.stderr}")
    require("missing exact release" in result.stderr,
            f"DP-10 rejection must identify the exact owner mismatch: {result.stderr}")

    result = invoke("event", str(FIXTURES / "focus-handoff-ordered.log"),
                    "2", "acquired", NEW_OWNER)
    require(result.returncode == 0,
            f"event polling must match an exact canonical post-cursor acquisition: {result.stderr}")

    print("PASS focus handoff trace cursor, exact-owner, and duplicate-acquisition regressions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
