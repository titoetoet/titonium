#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOGGLE = ROOT / "Titonium/Shared/Toggle.qml"
BUTTON = ROOT / "Titonium/Shared/Button.qml"
QMLDIR = ROOT / "Titonium/Shared/qmldir"


def main() -> int:
    errors: list[str] = []
    source = TOGGLE.read_text(encoding="utf-8") if TOGGLE.is_file() else ""
    button = BUTTON.read_text(encoding="utf-8") if BUTTON.is_file() else ""
    qmldir = QMLDIR.read_text(encoding="utf-8") if QMLDIR.is_file() else ""

    for fragment in (
        "property bool checked: false",
        "property string accessibleName:",
        "signal toggled(bool checked)",
        "root.toggled(!root.checked)",
        "TapHandler",
        "Keys.onPressed:",
        "Accessible.checkable: true",
        "Accessible.checked: root.checked",
    ):
        if fragment not in source:
            errors.append(f"Shared Toggle missing behavior contract: {fragment}")
    if "Toggle 1.0 Toggle.qml" not in qmldir:
        errors.append("Shared qmldir does not export Toggle")
    for fragment in (
        "property color iconColor: root.foregroundColor",
        "color: root.iconColor",
    ):
        if fragment not in button:
            errors.append(f"Shared Button missing icon-color override contract: {fragment}")

    if errors:
        print("\n".join("FAIL " + error for error in errors))
        return 1
    print("PASS shared Toggle interaction contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
