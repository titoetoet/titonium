pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root

    required property var itemData
    property bool initialFocus: false
    signal triggered(var itemData)

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed

    implicitWidth: 276
    implicitHeight: 36
    activeFocusOnTab: root.enabled

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusSmall
        color: root.activeFocus || root.hovered || root.pressed
            ? Theme.surfaceInteractive : "transparent"
        border.width: root.activeFocus ? Metrics.borderWidth : 0
        border.color: Theme.focus
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingMedium
        anchors.rightMargin: Metrics.spacingMedium
        spacing: Metrics.spacingMedium

        Controls.Icon {
            name: root.itemData.icon
            size: 18
            tone: root.itemData.id === "shutdown" || root.itemData.id === "restart"
                ? "danger" : "secondary"
            accessibleName: ""
        }

        Controls.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr(root.itemData.labelKey)
            variant: "body"
            tone: root.itemData.id === "shutdown" || root.itemData.id === "restart"
                ? "danger" : "primary"
            elide: Text.ElideRight
        }
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        enabled: root.enabled
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.triggered(root.itemData);
        }
    }

    Keys.onPressed: event => {
        if (root.enabled && (event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            root.triggered(root.itemData);
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.MenuItem
    Accessible.name: I18n.tr(root.itemData.labelKey)
    Accessible.focusable: root.enabled

    Component.onCompleted: {
        if (root.initialFocus)
            root.forceActiveFocus(Qt.PopupFocusReason);
    }
}
