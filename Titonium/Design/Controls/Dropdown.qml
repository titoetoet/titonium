pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design

FocusScope {
    id: root

    property var model: []
    property string textRole: "label"
    property string valueRole: "value"
    property int currentIndex: -1
    property string placeholder: ""
    property string accessibleName: ""
    property int maxVisibleItems: 6
    property bool expanded: false
    property int highlightedIndex: root.currentIndex >= 0 ? root.currentIndex : 0
    signal selected(int index, var value)

    readonly property int modelCount: {
        if (!root.model)
            return 0;
        if (root.model.count !== undefined)
            return root.model.count;
        return root.model.length || 0;
    }
    readonly property string currentText: root.currentIndex >= 0
        ? root.textFor(root.itemAt(root.currentIndex))
        : root.placeholder
    readonly property var currentValue: root.currentIndex >= 0
        ? root.valueFor(root.itemAt(root.currentIndex))
        : null

    function itemAt(index: int): var {
        if (!root.model || index < 0 || index >= root.modelCount)
            return null;
        if (typeof root.model.get === "function")
            return root.model.get(index);
        return root.model[index];
    }

    function textFor(item: var): string {
        if (item === null || item === undefined)
            return "";
        if (typeof item === "string" || typeof item === "number")
            return String(item);
        return item[root.textRole] === undefined ? "" : String(item[root.textRole]);
    }

    function valueFor(item: var): var {
        if (item === null || item === undefined)
            return null;
        if (typeof item !== "object")
            return item;
        return item[root.valueRole] === undefined ? item : item[root.valueRole];
    }

    function open(): void {
        if (!root.enabled || root.modelCount === 0)
            return;
        root.highlightedIndex = root.currentIndex >= 0 ? root.currentIndex : 0;
        root.expanded = true;
        root.forceActiveFocus(Qt.PopupFocusReason);
    }

    function close(): void {
        root.expanded = false;
    }

    function choose(index: int): void {
        if (!root.enabled || index < 0 || index >= root.modelCount)
            return;
        root.currentIndex = index;
        root.highlightedIndex = index;
        root.selected(index, root.valueFor(root.itemAt(index)));
        root.close();
    }

    implicitWidth: 220
    implicitHeight: Metrics.controlHeight
    activeFocusOnTab: root.enabled && root.modelCount > 0
    opacity: root.enabled ? 1.0 : 0.55
    z: root.expanded ? 100 : 0

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusSmall
        color: root.expanded ? Theme.surfaceInteractive : Theme.surfaceElevated
        border.width: Metrics.borderWidth
        border.color: root.activeFocus ? Theme.focus : Theme.border
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingMedium
        anchors.rightMargin: Metrics.spacingSmall
        spacing: Metrics.spacingSmall

        TextLabel {
            width: parent.width - chevron.width - parent.spacing
            height: parent.height
            text: root.currentText
            variant: "label"
            tone: root.currentIndex >= 0 ? "primary" : "secondary"
            elide: Text.ElideRight
        }

        Icon {
            id: chevron
            anchors.verticalCenter: parent.verticalCenter
            name: "expand_more"
            size: 20
            rotation: root.expanded ? 180 : 0

            Behavior on rotation { RotationAnimation { duration: Motion.fast } }
        }
    }

    HoverHandler {
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.enabled
        onTapped: root.expanded ? root.close() : root.open()
    }

    Loader {
        anchors.left: parent.left
        anchors.right: parent.right
        y: parent.height + Metrics.spacingXSmall
        active: root.expanded
        sourceComponent: optionsComponent
    }

    Component {
        id: optionsComponent

        Panel {
            height: Math.min(root.modelCount, root.maxVisibleItems) * Metrics.controlHeightSmall
                + Metrics.spacingSmall * 2
            padding: Metrics.spacingSmall
            z: 101

            ListView {
                id: optionList
                anchors.fill: parent
                model: root.model
                currentIndex: root.highlightedIndex
                clip: true
                reuseItems: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: Motion.fast

                delegate: Button {
                    required property int index
                    required property var modelData

                    width: optionList.width
                    size: "small"
                    variant: "quiet"
                    label: root.textFor(modelData)
                    selected: index === root.highlightedIndex || index === root.currentIndex
                    onTriggered: root.choose(index)
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && root.expanded) {
            root.close();
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.expanded)
                root.choose(root.highlightedIndex);
            else
                root.open();
        } else if (event.key === Qt.Key_Down && root.modelCount > 0) {
            if (!root.expanded)
                root.open();
            else
                root.highlightedIndex = Math.min(root.modelCount - 1, root.highlightedIndex + 1);
        } else if (event.key === Qt.Key_Up && root.modelCount > 0) {
            if (!root.expanded)
                root.open();
            else
                root.highlightedIndex = Math.max(0, root.highlightedIndex - 1);
        } else {
            return;
        }
        event.accepted = true;
    }

    onActiveFocusChanged: {
        if (!root.activeFocus)
            root.close();
    }

    Accessible.role: Accessible.ComboBox
    Accessible.name: root.accessibleName + ", " + root.currentText
    Accessible.focusable: root.enabled && root.modelCount > 0
}
