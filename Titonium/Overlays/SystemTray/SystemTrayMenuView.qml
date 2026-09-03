pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Services.SystemTray
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    signal dismissRequested()
    readonly property real implicitContentHeight: contentColumn.implicitHeight
    readonly property real implicitContentWidth: contentColumn.implicitWidth

    focus: true

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
                                ? menuRow.inputPresentation.label : menuRow.modelData.text
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
                        if (!menuRow.modelData.enabled || menuRow.modelData.separator)
                            return;
                        if (menuRow.modelData.hasChildren) {
                            SystemTrayService.enterPopupEntry(menuRow.index);
                            return;
                        }
                        if (SystemTrayService.triggerPopupEntry(menuRow.index)
                                && !SystemTrayService.popupIsInputMethod
                                && menuRow.modelData.buttonType === "none")
                            root.dismissRequested();
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
