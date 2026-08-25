pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design

FocusScope {
    id: root

    property var model: []
    property string textRole: "label"
    property string iconRole: "icon"
    property string valueRole: "value"
    property int currentIndex: 0
    property string accessibleName: ""
    signal activated(int index, var value)

    readonly property int modelCount: {
        if (!root.model)
            return 0;
        if (root.model.count !== undefined)
            return root.model.count;
        return root.model.length || 0;
    }
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

    function iconFor(item: var): string {
        if (!item || typeof item !== "object" || item[root.iconRole] === undefined)
            return "";
        return String(item[root.iconRole]);
    }

    function valueFor(item: var): var {
        if (item === null || item === undefined)
            return null;
        if (typeof item !== "object")
            return item;
        return item[root.valueRole] === undefined ? item : item[root.valueRole];
    }

    function activate(index: int): void {
        if (!root.enabled || index < 0 || index >= root.modelCount)
            return;
        root.currentIndex = index;
        root.activated(index, root.valueFor(root.itemAt(index)));
    }

    function move(offset: int): void {
        if (root.modelCount === 0)
            return;
        const start = root.currentIndex >= 0 ? root.currentIndex : 0;
        root.activate((start + offset + root.modelCount) % root.modelCount);
    }

    implicitWidth: tabRow.implicitWidth + Metrics.spacingXSmall * 2
    implicitHeight: Metrics.controlHeight
    activeFocusOnTab: root.enabled && root.modelCount > 0
    opacity: root.enabled ? 1.0 : 0.55

    Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusSmall
        outlined: true
    }

    Row {
        id: tabRow
        anchors.fill: parent
        anchors.margins: Metrics.spacingXSmall / 2
        spacing: Metrics.spacingXSmall / 2

        Repeater {
            model: root.model

            Item {
                id: tabItem
                required property int index
                required property var modelData

                implicitWidth: tabContent.implicitWidth + Metrics.spacingMedium * 2
                height: tabRow.height

                Rectangle {
                    anchors.fill: parent
                    radius: Metrics.radiusSmall
                    color: tabItem.index === root.currentIndex ? Theme.surfaceInteractive : "transparent"
                    border.width: tabItem.index === root.currentIndex && root.activeFocus ? Metrics.borderWidth : 0
                    border.color: Theme.focus
                }

                Row {
                    id: tabContent
                    anchors.centerIn: parent
                    spacing: Metrics.spacingXSmall

                    Icon {
                        visible: root.iconFor(tabItem.modelData).length > 0
                        name: root.iconFor(tabItem.modelData)
                        size: 20
                        tone: tabItem.index === root.currentIndex ? "accent" : "secondary"
                    }

                    TextLabel {
                        text: root.textFor(tabItem.modelData)
                        variant: "label"
                        tone: tabItem.index === root.currentIndex ? "primary" : "secondary"
                    }
                }

                HoverHandler {
                    enabled: root.enabled
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: root.enabled
                    onTapped: {
                        root.forceActiveFocus(Qt.MouseFocusReason);
                        root.activate(tabItem.index);
                    }
                }

                Accessible.role: Accessible.PageTab
                Accessible.name: root.textFor(tabItem.modelData)
                Accessible.selected: tabItem.index === root.currentIndex
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Up)
            root.move(-1);
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down)
            root.move(1);
        else if (event.key === Qt.Key_Home)
            root.activate(0);
        else if (event.key === Qt.Key_End)
            root.activate(root.modelCount - 1);
        else
            return;
        event.accepted = true;
    }

    onModelCountChanged: {
        if (root.modelCount === 0)
            root.currentIndex = -1;
        else if (root.currentIndex < 0 || root.currentIndex >= root.modelCount)
            root.currentIndex = 0;
    }

    Accessible.role: Accessible.PageTabList
    Accessible.name: root.accessibleName
    Accessible.focusable: root.enabled && root.modelCount > 0
}
