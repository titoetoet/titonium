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
    forbidden_perf = re.compile(r"\bMultiEffect\b|Animation\.Infinite|loops\s*:\s*Animation\.Infinite")
    allowed_io = {"Foundation", "Platform"}

    for path in sorted((root / "Titonium").rglob("*.qml")):
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(root)
        layer = relative.parts[1] if len(relative.parts) > 1 else ""
        if layer not in allowed_io and forbidden_ui.search(text):
            errors.append(f"platform I/O in UI layer: {relative}")
        if layer not in allowed_io and forbidden_commands.search(text):
            errors.append(f"raw platform command in UI layer: {relative}")
        if forbidden_perf.search(text):
            errors.append(f"forbidden always-on visual cost: {relative}")
        if "/home/" in text or "~/" in text:
            errors.append(f"hardcoded home path in QML: {relative}")

    registry = (root / "Titonium/Composition/WidgetRegistry.qml").read_text(encoding="utf-8")
    if "unknownSource" not in registry or "sourceFor" not in registry:
        errors.append("WidgetRegistry must provide an unknown widget fallback")

    overlay = (root / "Titonium/Surfaces/OverlayHost.qml").read_text(encoding="utf-8")
    if "Loader" not in overlay or "active:" not in overlay:
        errors.append("OverlayHost must lazy-load transient UI")

    if errors:
        print("\n".join(f"FAIL {error}" for error in errors), file=sys.stderr)
        return 1
    print("PASS architecture boundaries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
