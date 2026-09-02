pragma ComponentBehavior: Bound
// Protected Spotlight vertical slice.

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import qs.Titonium.Theme
import qs.Titonium.Shared as Controls
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Clipboard
import "ClipboardSelection.js" as ClipboardSelection
import "ClipboardFormat.js" as ClipboardFormat

FocusScope {
    id: root

    property var spotlightModel: null
    property var spotlightSurface: null
    signal activatedSuccessfully()

    readonly property var filteredItems: {
        const query = (root.spotlightModel?.query || "").trim().toLowerCase();
        if (query.length === 0)
            return ClipboardService.items;
        return ClipboardService.items.filter(item =>
            item.text.toLowerCase().indexOf(query) >= 0
            || item.kind.toLowerCase().indexOf(query) >= 0);
    }
    readonly property int selectedIndex: typeof root.spotlightModel?.selectedIndex === "number"
        ? root.spotlightModel.selectedIndex : -1
    readonly property var selectedItem: ClipboardSelection.itemAt(
        root.filteredItems, root.selectedIndex)

    function select(index: int): void {
        if (!root.spotlightModel || index < 0 || index >= root.filteredItems.length)
            return;
        root.spotlightModel.selectedIndex = index;
        root.spotlightModel.selectionMoved = true;
    }

    function moveSelection(delta: int): void {
        if (!root.spotlightModel || root.filteredItems.length === 0)
            return;
        root.spotlightModel.selectedIndex = ClipboardSelection.move(
            root.selectedIndex, delta, root.filteredItems.length);
        root.spotlightModel.selectionMoved = true;
        historyList.positionViewAtIndex(root.spotlightModel.selectedIndex, ListView.Contain);
    }

    function activateSelected(): bool {
        return ClipboardService.available && root.selectedItem !== null
            && ClipboardService.copy(root.selectedItem.id);
    }

    function deleteSelected(): void {
        if (root.selectedItem === null)
            return;
        ClipboardService.remove(root.selectedItem.id);
        if (root.spotlightModel)
            root.spotlightModel.selectedIndex = ClipboardSelection.clamp(
                root.selectedIndex, root.filteredItems.length);
    }

    onFilteredItemsChanged: {
        if (root.spotlightModel)
            root.spotlightModel.selectedIndex = ClipboardSelection.clamp(
                root.selectedIndex, root.filteredItems.length);
    }

    Connections {
        target: root.spotlightSurface
        function onClipboardMoveRequested(delta: int): void {
            root.moveSelection(delta);
        }
        function onClipboardActivateRequested(): void {
            if (root.activateSelected())
                root.activatedSuccessfully();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Metrics.spacingMedium

        ColumnLayout {
            Layout.preferredWidth: 320
            Layout.fillHeight: true
            spacing: Metrics.spacingSmall

            RowLayout {
                Layout.fillWidth: true
                Controls.TextLabel {
                    Layout.fillWidth: true
                    text: I18n.tr("spotlight.clipboard.title")
                    variant: "title"
                    strong: true
                }
                Controls.Button {
                    id: clearAllButton
                    iconName: "clear_all"
                    variant: "quiet"
                    size: "small"
                    enabled: ClipboardService.items.length > 0
                    accessibleName: I18n.tr("spotlight.clipboard.clear")
                    onTriggered: ClipboardService.clear()
                    QtControls.ToolTip.visible: hovered
                    QtControls.ToolTip.text: accessibleName
                    QtControls.ToolTip.delay: 500
                }
            }

            Controls.TextLabel {
                Layout.fillWidth: true
                visible: !ClipboardService.available
                text: I18n.tr("spotlight.clipboard.unavailable")
                tone: "danger"
                wrapMode: Text.WordWrap
            }

            ListView {
                id: historyList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: root.filteredItems
                currentIndex: root.selectedIndex
                clip: true
                spacing: Metrics.spacingXSmall
                boundsBehavior: Flickable.StopAtBounds

                delegate: FocusScope {
                    id: historyRow
                    required property int index
                    required property var modelData
                    width: historyList.width
                    height: 56
                    activeFocusOnTab: true
                    readonly property bool actionsVisible:
                        historyRow.index === root.selectedIndex
                        || rowHover.hovered || historyRow.activeFocus

                    Rectangle {
                        anchors.fill: parent
                        radius: Metrics.radiusMedium
                        color: historyRow.index === root.selectedIndex
                            || historyRow.activeFocus || rowHover.hovered
                            ? Theme.surfaceInteractive : "transparent"
                        border.width: historyRow.activeFocus ? Metrics.borderWidth : 0
                        border.color: Theme.focus
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Metrics.spacingMedium
                        anchors.rightMargin: Metrics.spacingMedium
                        spacing: Metrics.spacingSmall

                        Rectangle {
                            visible: historyRow.modelData.kind === "color"
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: Metrics.radiusSmall
                            color: historyRow.modelData.colorHex || "transparent"
                            border.width: Metrics.borderWidth
                            border.color: Theme.borderStrong
                        }
                        Item {
                            visible: historyRow.modelData.kind !== "color"
                            implicitWidth: 24
                            implicitHeight: 24
                            Controls.SystemIcon {
                                anchors.centerIn: parent
                                sourceName: ClipboardFormat.appIconSource(historyRow.modelData)
                                fallbackName: ClipboardFormat.itemIcon(historyRow.modelData)
                                size: 22
                                tone: "secondary"
                                accessibleName: ClipboardFormat.sourceName(historyRow.modelData)
                            }
                            HoverHandler { id: iconHover }
                            QtControls.ToolTip.visible: iconHover.hovered
                            QtControls.ToolTip.text: ClipboardFormat.sourceName(historyRow.modelData)
                            QtControls.ToolTip.delay: 400
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Controls.TextLabel {
                                Layout.fillWidth: true
                                text: historyRow.modelData.preview
                                variant: historyRow.modelData.kind === "code" ? "mono" : "label"
                                strong: historyRow.index === root.selectedIndex
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                            }
                            Controls.TextLabel {
                                text: ClipboardFormat.relativeTime(historyRow.modelData.timestamp)
                                variant: "caption"
                                tone: "secondary"
                            }
                        }

                        RowLayout {
                            id: rowActions
                            spacing: Metrics.spacingXSmall
                            opacity: historyRow.actionsVisible ? 1 : 0
                            enabled: historyRow.actionsVisible

                            Behavior on opacity {
                                NumberAnimation { duration: Motion.fast }
                            }

                            Controls.Button {
                                iconName: "content_copy"
                                variant: "quiet"
                                size: "small"
                                enabled: rowActions.enabled && ClipboardService.available
                                accessibleName: I18n.tr("spotlight.clipboard.copy")
                                onTriggered: {
                                    if (ClipboardService.copy(historyRow.modelData.id))
                                        root.activatedSuccessfully();
                                }
                                QtControls.ToolTip.visible: hovered
                                QtControls.ToolTip.text: accessibleName
                                QtControls.ToolTip.delay: 500
                            }

                            Controls.Button {
                                iconName: "delete"
                                variant: "danger"
                                size: "small"
                                enabled: rowActions.enabled
                                accessibleName: I18n.tr("spotlight.clipboard.delete")
                                onTriggered: {
                                    ClipboardService.remove(historyRow.modelData.id);
                                    if (root.spotlightModel)
                                        root.spotlightModel.selectedIndex = ClipboardSelection.clamp(
                                            root.selectedIndex, root.filteredItems.length);
                                }
                                QtControls.ToolTip.visible: hovered
                                QtControls.ToolTip.text: accessibleName
                                QtControls.ToolTip.delay: 500
                            }
                        }
                    }

                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            root.select(historyRow.index);
                            historyRow.forceActiveFocus(Qt.MouseFocusReason);
                        }
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            root.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete) {
                            root.deleteSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            if (root.activateSelected())
                                root.activatedSuccessfully();
                            event.accepted = true;
                        }
                    }

                    Accessible.role: Accessible.ListItem
                    Accessible.name: historyRow.modelData.preview
                    Accessible.focusable: true
                    Accessible.selected: historyRow.index === root.selectedIndex
                }

                Controls.TextLabel {
                    anchors.centerIn: parent
                    visible: ClipboardService.available && historyList.count === 0
                    text: I18n.tr(ClipboardService.items.length === 0
                        ? "spotlight.clipboard.empty" : "spotlight.clipboard.no_results")
                    tone: "secondary"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Controls.Surface {
            Layout.fillWidth: true
            Layout.fillHeight: true
            tone: "elevated"
            radius: Metrics.radiusMedium
            padding: 0
            outlined: true
            clipContent: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Image {
                        visible: root.selectedItem?.kind === "image"
                            && (root.selectedItem?.imagePath || "").length > 0
                        anchors.fill: parent
                        anchors.margins: Metrics.spacingLarge
                        source: visible ? ("file://" + root.selectedItem.imagePath) : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                    }

                    QtControls.ScrollView {
                        visible: root.selectedItem?.kind !== "image"
                        anchors.fill: parent
                        anchors.margins: Metrics.spacingLarge
                        clip: true

                        Controls.TextLabel {
                            width: parent.width
                            text: root.selectedItem?.text || I18n.tr("spotlight.clipboard.preview_empty")
                            variant: root.selectedItem?.kind === "code" || root.selectedItem !== null ? "mono" : "body"
                            tone: root.selectedItem === null ? "secondary" : "primary"
                            wrapMode: Text.WrapAnywhere
                            verticalAlignment: Text.AlignTop
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Metrics.borderWidth
                    color: Theme.border
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: metadataCol.implicitHeight + (Metrics.spacingMedium * 2)
                    visible: root.selectedItem !== null

                    ColumnLayout {
                        id: metadataCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: Metrics.spacingLarge
                        anchors.rightMargin: Metrics.spacingLarge
                        anchors.topMargin: Metrics.spacingMedium
                        spacing: Metrics.spacingSmall

                        RowLayout {
                            Layout.fillWidth: true
                            Controls.TextLabel {
                                text: ClipboardFormat.label("type")
                                variant: "mono"
                                tone: "secondary"
                            }
                            Item { Layout.fillWidth: true }
                            Controls.TextLabel {
                                text: ClipboardFormat.typeLabel(root.selectedItem)
                                variant: "mono"
                                tone: "primary"
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Controls.TextLabel {
                                text: ClipboardFormat.label("size")
                                variant: "mono"
                                tone: "secondary"
                            }
                            Item { Layout.fillWidth: true }
                            Controls.TextLabel {
                                text: ClipboardFormat.sizeLabel(root.selectedItem)
                                variant: "mono"
                                tone: "primary"
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Controls.TextLabel {
                                text: ClipboardFormat.label("copied_at")
                                variant: "mono"
                                tone: "secondary"
                            }
                            Item { Layout.fillWidth: true }
                            Controls.TextLabel {
                                text: ClipboardFormat.copiedAt(root.selectedItem?.timestamp)
                                variant: "mono"
                                tone: "primary"
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Controls.TextLabel {
                                text: ClipboardFormat.label("md5")
                                variant: "mono"
                                tone: "secondary"
                            }
                            Item { Layout.fillWidth: true }
                            Controls.TextLabel {
                                text: root.selectedItem?.md5 || (root.selectedItem ? ClipboardFormat.md5(root.selectedItem.text) : "")
                                variant: "mono"
                                tone: "primary"
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }
    }
}
