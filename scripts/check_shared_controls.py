#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOGGLE = ROOT / "Titonium/Shared/Toggle.qml"
BUTTON = ROOT / "Titonium/Shared/Button.qml"
QMLDIR = ROOT / "Titonium/Shared/qmldir"
SELECT = ROOT / "Titonium/Shared/Select.qml"
SLIDER = ROOT / "Titonium/Shared/Slider.qml"


def main() -> int:
    errors: list[str] = []
    source = TOGGLE.read_text(encoding="utf-8") if TOGGLE.is_file() else ""
    button = BUTTON.read_text(encoding="utf-8") if BUTTON.is_file() else ""
    qmldir = QMLDIR.read_text(encoding="utf-8") if QMLDIR.is_file() else ""
    select = SELECT.read_text(encoding="utf-8") if SELECT.is_file() else ""
    slider = SLIDER.read_text(encoding="utf-8") if SLIDER.is_file() else ""

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
        "property bool iconHoverMotion: false",
        "root.iconHoverMotion && root.hovered ? 1.08",
        "root.iconHoverMotion && root.hovered ? -1 : 0",
        "Motion.reduced ? 0 : 140",
        "root.pressed && !root.iconHoverMotion",
        "property bool backgroundVisible: true",
        "visible: root.backgroundVisible",
    ):
        if fragment not in button:
            errors.append(f"Shared Button missing icon-color override contract: {fragment}")
    for fragment in (
        "property var model:",
        "property int currentIndex:",
        "property string accessibleName:",
        "signal selected(int index, var value)",
        "QtControls.ComboBox",
        "Accessible.name: root.accessibleName",
    ):
        if fragment not in select:
            errors.append(f"Shared Select missing behavior contract: {fragment}")
    for fragment in (
        "property real from:",
        "property real to:",
        "property real stepSize:",
        "property real value:",
        "property string accessibleName:",
        "signal moved(real value)",
        "QtControls.Slider",
        "Accessible.name: root.accessibleName",
    ):
        if fragment not in slider:
            errors.append(f"Shared Slider missing behavior contract: {fragment}")
    for name, source_text in (("Select", select), ("Slider", slider)):
        for forbidden in ("FileView", "Process", "Timer {", "MultiEffect", "ShaderEffect"):
            if forbidden in source_text:
                errors.append(f"Shared {name} has forbidden dependency: {forbidden}")
    if "Select 1.0 Select.qml" not in qmldir:
        errors.append("Shared qmldir does not export Select")
    if "Slider 1.0 Slider.qml" not in qmldir:
        errors.append("Shared qmldir does not export Slider")

    if errors:
        print("\n".join("FAIL " + error for error in errors))
        return 1
    print("PASS shared Toggle interaction contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
