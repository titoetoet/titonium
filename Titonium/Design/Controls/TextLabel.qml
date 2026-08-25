pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design

Text {
    id: root

    property string variant: "body"
    property string tone: root.enabled ? "primary" : "disabled"
    property bool strong: false

    readonly property color resolvedColor: {
        const tones = {
            primary: Theme.textPrimary,
            secondary: Theme.textSecondary,
            disabled: Theme.textDisabled,
            accent: Theme.accent,
            success: Theme.success,
            warning: Theme.warning,
            danger: Theme.danger
        };
        return tones[root.tone] || Theme.textPrimary;
    }

    color: root.resolvedColor
    font.family: root.variant === "mono" ? Typography.monoFamily : Typography.family
    font.pixelSize: Typography.sizeFor(root.variant)
    font.weight: root.strong ? Typography.semiboldWeight : Typography.weightFor(root.variant)
    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter

    Accessible.name: root.text
    Accessible.role: Accessible.StaticText
}
