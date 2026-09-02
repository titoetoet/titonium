pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Overlays.SystemTray
import qs.Titonium.Services.SystemTray
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property var invoker: root.descriptor?.invoker || null
    readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing
    readonly property real desiredX: (root.descriptor?.anchorX || 0)
        + (root.descriptor?.anchorWidth || 0) / 2 - panel.width / 2
    readonly property real contentHeight: contentColumn.implicitHeight + 2 * panel.padding

    anchors.fill: parent
    focus: true

    property bool closing: false

    function close(): void {
        if (root.invoker?.forceActiveFocus)
            root.invoker.forceActiveFocus(Qt.PopupFocusReason);
        if (Motion.reduced) {
            SystemTrayPopupCoordinator.close();
            return;
        }
        if (root.closing)
            return;
        root.closing = true;
        panelExit.restart();
    }

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0
            && local.x <= item.width && local.y <= item.height;
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(panel, eventPoint.position))
                    root.close();
            }
        }
    }

    Shared.Panel {
        id: panel
        x: Math.max(Metrics.barPadding,
            Math.min(root.width - width - Metrics.barPadding, root.desiredX))
        anchors.top: parent.top
        anchors.topMargin: root.panelTop
        width: 380
        height: Math.min(560,
            root.height - root.panelTop - Metrics.barPadding,
            root.contentHeight)
        customColor: Theme.surface
        clipContent: true
        transformOrigin: Item.Top
        opacity: Motion.reduced ? 1 : 0
        scale: Motion.reduced ? 1 : 0.94
        transform: Translate {
            id: panelEntranceOffset
            y: Motion.reduced ? 0 : -12
        }

        Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentColumn
                width: parent.width
                spacing: Metrics.spacingSmall

                Shared.Button {
                    Layout.fillWidth: true
                    visible: SystemTrayService.popupCanGoBack
                    label: "Back"
                    iconName: "arrow_back"
                    variant: "quiet"
                    size: "small"
                    contentAlignment: Qt.AlignLeft
                    onTriggered: SystemTrayService.popupBack()
                }

                Repeater {
                    model: SystemTrayService.popupEntries

                    delegate: FocusScope {
                        id: menuRow
                        required property var modelData
                        required property int index
                        readonly property var inputPresentation:
                            SystemTrayService.inputMenuPresentation(menuRow.modelData)

                        Layout.fillWidth: true
                        implicitHeight: menuRow.modelData.separator ? Metrics.spacingMedium
                            : Metrics.controlHeightSmall
                        activeFocusOnTab: menuRow.modelData.enabled
                            && !menuRow.modelData.separator

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: Metrics.borderWidth
                            visible: menuRow.modelData.separator
                            color: Theme.border
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !menuRow.modelData.separator
                            radius: Metrics.radiusSmall
                            color: rowHover.hovered && menuRow.modelData.enabled
                                ? Theme.surfaceInteractive : "transparent"
                            border.width: menuRow.activeFocus ? Metrics.borderWidth : 0
                            border.color: Theme.focus
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Metrics.spacingMedium
                            anchors.rightMargin: Metrics.spacingMedium
                            spacing: Metrics.spacingSmall
                            visible: !menuRow.modelData.separator

                            Shared.Icon {
                                visible: SystemTrayService.popupIsInputMethod
                                name: menuRow.inputPresentation.icon
                                size: 18
                                tone: menuRow.modelData.enabled ? "secondary" : "disabled"
                                accessibleName: ""
                            }

                            Shared.Icon {
                                visible: !SystemTrayService.popupIsInputMethod
                                    && menuRow.modelData.buttonType !== "none"
                                name: menuRow.modelData.checked
                                    ? (menuRow.modelData.buttonType === "radio"
                                        ? "radio_button_checked" : "check_box")
                                    : (menuRow.modelData.buttonType === "radio"
                                        ? "radio_button_unchecked" : "check_box_outline_blank")
                                size: 18
                                tone: menuRow.modelData.checked ? "accent" : "secondary"
                                accessibleName: ""
                            }

                            Image {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                visible: !SystemTrayService.popupIsInputMethod
                                    && menuRow.modelData.icon.length > 0
                                source: menuRow.modelData.icon
                                fillMode: Image.PreserveAspectFit
                            }

                            Shared.TextLabel {
                                Layout.fillWidth: true
                                text: SystemTrayService.popupIsInputMethod
                                    ? menuRow.inputPresentation.label
                                    : menuRow.modelData.text
                                variant: "label"
                                strong: !menuRow.modelData.enabled
                                tone: menuRow.modelData.enabled ? "primary" : "secondary"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Shared.Icon {
                                visible: menuRow.modelData.hasChildren
                                name: "chevron_right"
                                size: 18
                                tone: menuRow.modelData.enabled ? "secondary" : "disabled"
                                accessibleName: ""
                            }

                            Shared.Icon {
                                id: selectedCheckIcon
                                visible: SystemTrayService.popupIsInputMethod
                                    && menuRow.inputPresentation.selected
                                name: "check"
                                size: 18
                                tone: "accent"
                                accessibleName: ""
                            }
                        }

                        function activate(): void {
                            if (!menuRow.modelData.enabled
                                    || menuRow.modelData.separator)
                                return;
                            if (menuRow.modelData.hasChildren)
                                SystemTrayService.enterPopupEntry(menuRow.index);
                            else if (SystemTrayService.triggerPopupEntry(menuRow.index)) {
                                if (!SystemTrayService.popupIsInputMethod)
                                    root.close();
                            }
                        }

                        HoverHandler {
                            id: rowHover
                            enabled: menuRow.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            enabled: menuRow.modelData.enabled
                            onTapped: {
                                menuRow.forceActiveFocus(Qt.MouseFocusReason);
                                menuRow.activate();
                            }
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                    || event.key === Qt.Key_Space) {
                                menuRow.activate();
                                event.accepted = true;
                            }
                        }

                        Accessible.role: SystemTrayService.popupIsInputMethod
                                && menuRow.modelData.buttonType !== "none"
                            ? Accessible.CheckBox : Accessible.MenuItem
                        Accessible.name: SystemTrayService.popupIsInputMethod
                            ? menuRow.inputPresentation.label : menuRow.modelData.text
                        Accessible.focusable: menuRow.modelData.enabled
                        Accessible.checkable: menuRow.modelData.buttonType !== "none"
                        Accessible.checked: SystemTrayService.popupIsInputMethod
                            ? menuRow.inputPresentation.selected : menuRow.modelData.checked
                    }
                }

                Shared.TextLabel {
                    Layout.fillWidth: true
                    visible: SystemTrayService.popupEntries.length === 0
                    text: "Loading menu…"
                    tone: "secondary"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    ParallelAnimation {
        id: panelEntrance
        running: !Motion.reduced

        NumberAnimation {
            target: panel
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 0.94
            to: 1
            duration: 220
            easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
        }
        NumberAnimation {
            target: panelEntranceOffset
            property: "y"
            from: -12
            to: 0
            duration: 220
            easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1]
        }
    }

    ParallelAnimation {
        id: panelExit

        NumberAnimation {
            target: panel
            property: "opacity"
            from: 1
            to: 0
            duration: 120
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 1
            to: 0.96
            duration: 130
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panelEntranceOffset
            property: "y"
            from: 0
            to: -8
            duration: 130
            easing.type: Easing.InCubic
        }
        onFinished: SystemTrayPopupCoordinator.close()
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: panel.forceActiveFocus(Qt.PopupFocusReason)
}
