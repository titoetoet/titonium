#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOGGLE = ROOT / "Titonium/Shared/Toggle.qml"
QMLDIR = ROOT / "Titonium/Shared/qmldir"


def main() -> int:
    errors: list[str] = []
    source = TOGGLE.read_text(encoding="utf-8") if TOGGLE.is_file() else ""
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

    if errors:
        print("\n".join("FAIL " + error for error in errors))
        return 1
    print("PASS shared Toggle interaction contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
