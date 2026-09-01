pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Audio
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    required property var device
    property bool checked: root.device?.selected === true
    readonly property bool hovered: hoverHandler.hovered

    implicitWidth: content.implicitWidth
    implicitHeight: Metrics.controlHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.RadioButton
    Accessible.name: I18n.tr("audio.output.select.accessible", {
        "name": root.device?.name || I18n.tr("audio.output")
    })
    Accessible.focusable: true
    Accessible.checkable: true
    Accessible.checked: root.checked

    function activate(): void {
        if (!root.checked)
            AudioService.selectOutputDevice(root.device.id);
    }

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusSmall
        color: root.hovered || root.activeFocus ? Theme.surfaceInteractive : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingSmall
        anchors.rightMargin: Metrics.spacingSmall
        spacing: Metrics.spacingMedium

        Shared.SystemIcon {
            sourceName: root.device?.icon || "volume_up"
            fallbackName: "volume_up"
            size: 20
            tone: root.checked ? "accent" : "secondary"
            accessibleName: ""
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            text: root.device?.name || I18n.tr("audio.output")
            variant: "label"
            strong: root.checked
            elide: Text.ElideRight
        }

        Shared.Icon {
            name: root.checked ? "radio_button_checked" : "radio_button_unchecked"
            size: 19
            tone: root.checked ? "accent" : "secondary"
            accessibleName: ""
        }
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.activate();
        }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter) {
            root.activate();
            event.accepted = true;
        }
    }
}
