pragma ComponentBehavior: Bound
// Protected Spotlight vertical slice.

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import qs.Titonium.Theme
import qs.Titonium.Shared as Controls
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Clipboard

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
    readonly property var selectedItem: root.filteredItems.length > 0
        ? root.filteredItems[Math.min(root.spotlightModel?.selectedIndex || 0, root.filteredItems.length - 1)]
        : null

    function select(index: int): void {
        if (!root.spotlightModel || index < 0 || index >= root.filteredItems.length)
            return;
        root.spotlightModel.selectedIndex = index;
        root.spotlightModel.selectionMoved = true;
    }

    function moveSelection(delta: int): void {
        if (!root.spotlightModel || root.filteredItems.length === 0)
            return;
        const length = root.filteredItems.length;
        root.spotlightModel.selectedIndex = (root.spotlightModel.selectedIndex + delta + length) % length;
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
            root.spotlightModel.selectedIndex = Math.max(0,
                Math.min(root.spotlightModel.selectedIndex, root.filteredItems.length - 1));
    }

    onFilteredItemsChanged: {
        if (root.spotlightModel)
            root.spotlightModel.selectedIndex = Math.max(0,
                Math.min(root.spotlightModel.selectedIndex, root.filteredItems.length - 1));
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
            Layout.preferredWidth: 330
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
                    label: I18n.tr("spotlight.clipboard.clear")
                    iconName: "delete_sweep"
                    variant: "quiet"
                    size: "small"
                    enabled: ClipboardService.items.length > 0
                    onTriggered: ClipboardService.clear()
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
                currentIndex: root.spotlightModel?.selectedIndex || 0
                clip: true
                spacing: Metrics.spacingXSmall
                boundsBehavior: Flickable.StopAtBounds

                delegate: FocusScope {
                    id: historyRow
                    required property int index
                    required property var modelData
                    width: historyList.width
                    height: 60
                    activeFocusOnTab: true

                    Rectangle {
                        anchors.fill: parent
                        radius: Metrics.radiusMedium
                        color: historyRow.index === (root.spotlightModel?.selectedIndex || 0)
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
                        Controls.Icon {
                            visible: historyRow.modelData.kind !== "color"
                            name: historyRow.modelData.kind === "url" ? "link"
                                : (historyRow.modelData.kind === "code" ? "code" : "content_paste")
                            size: 24
                            tone: "secondary"
                            accessibleName: ""
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Controls.TextLabel {
                                Layout.fillWidth: true
                                text: historyRow.modelData.preview
                                variant: historyRow.modelData.kind === "code" ? "mono" : "label"
                                strong: historyRow.index === (root.spotlightModel?.selectedIndex || 0)
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                            }
                            Controls.TextLabel {
                                text: I18n.tr("spotlight.clipboard.kind." + historyRow.modelData.kind)
                                variant: "caption"
                                tone: "secondary"
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
                    Accessible.selected: historyRow.index === (root.spotlightModel?.selectedIndex || 0)
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
            padding: Metrics.spacingLarge
            outlined: true
            clipContent: true

            ColumnLayout {
                anchors.fill: parent
                spacing: Metrics.spacingMedium

                RowLayout {
                    Layout.fillWidth: true
                    Controls.TextLabel {
                        Layout.fillWidth: true
                        text: root.selectedItem === null ? I18n.tr("spotlight.clipboard.preview")
                            : I18n.tr("spotlight.clipboard.kind." + root.selectedItem.kind)
                        variant: "title"
                        strong: true
                    }
                    Controls.Button {
                        label: I18n.tr("spotlight.clipboard.copy")
                        iconName: "content_copy"
                        size: "small"
                        enabled: ClipboardService.available && root.selectedItem !== null
                        onTriggered: {
                            if (root.activateSelected())
                                root.activatedSuccessfully();
                        }
                    }
                    Controls.Button {
                        label: I18n.tr("spotlight.clipboard.delete")
                        iconName: "delete"
                        variant: "danger"
                        size: "small"
                        enabled: root.selectedItem !== null
                        onTriggered: root.deleteSelected()
                    }
                }

                QtControls.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Controls.TextLabel {
                        width: parent.width
                        text: root.selectedItem?.text || I18n.tr("spotlight.clipboard.preview_empty")
                        variant: root.selectedItem?.kind === "code" ? "mono" : "body"
                        tone: root.selectedItem === null ? "secondary" : "primary"
                        wrapMode: Text.WrapAnywhere
                        verticalAlignment: Text.AlignTop
                    }
                }

                Controls.TextLabel {
                    Layout.fillWidth: true
                    visible: root.selectedItem !== null
                    text: root.selectedItem === null ? "" : I18n.tr("spotlight.clipboard.stats", {
                        "lines": root.selectedItem.lines,
                        "words": root.selectedItem.words,
                        "chars": root.selectedItem.chars
                    })
                    variant: "caption"
                    tone: "secondary"
                }
            }
        }
    }
}
