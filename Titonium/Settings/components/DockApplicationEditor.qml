pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Applications
import qs.Titonium.Services.Dock
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

ColumnLayout {
    id: root

    property string query: ""
    readonly property var pinnedIds: DockStore.pinnedIds
    readonly property var filteredApplications: {
        const needle = root.query.trim().toLocaleLowerCase();
        if (needle.length === 0)
            return ApplicationService.allApplications;
        return ApplicationService.allApplications.filter(application =>
            String(application?.name || "").toLocaleLowerCase().indexOf(needle) >= 0
            || String(application?.id || "").toLocaleLowerCase().indexOf(needle) >= 0);
    }

    spacing: Metrics.spacingSmall

    Shared.TextLabel {
        text: I18n.tr("settings.dock.pinned")
        variant: "label"
        strong: true
    }

    ListView {
        id: pinnedList
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(148, Math.max(44, contentHeight))
        model: root.pinnedIds
        currentIndex: -1
        clip: true
        spacing: Metrics.spacingXSmall
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true

        delegate: Shared.Surface {
            id: pinnedRow
            required property int index
            required property string modelData

            readonly property var entry: ApplicationService.desktopEntryForAppId(modelData)
            property real dragOffsetY: 0
            readonly property int sourceIndex: index

            width: pinnedList.width
            implicitHeight: 44
            tone: "elevated"
            radius: Metrics.radiusMedium
            z: dragHandler.active ? 2 : 0
            transform: Translate { y: pinnedRow.dragOffsetY }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Metrics.spacingSmall
                anchors.rightMargin: Metrics.spacingSmall
                spacing: Metrics.spacingSmall

                Item {
                    id: dragHandle
                    Layout.preferredWidth: 28
                    Layout.fillHeight: true
                    activeFocusOnTab: true

                    Shared.Icon {
                        anchors.centerIn: parent
                        name: "drag_indicator"
                        size: 20
                        tone: "secondary"
                    }

                    HoverHandler { cursorShape: Qt.SizeVerCursor }
                    DragHandler {
                        id: dragHandler
                        target: null
                        xAxis.enabled: false
                        onActiveTranslationChanged:
                            pinnedRow.dragOffsetY = activeTranslation.y
                        onActiveChanged: {
                            if (active)
                                return;
                            const stride = pinnedRow.height + pinnedList.spacing;
                            const targetIndex = Math.max(0, Math.min(pinnedList.count - 1,
                                Math.floor((pinnedRow.y + pinnedRow.dragOffsetY
                                    + pinnedRow.height / 2) / stride)));
                            DockStore.movePin(pinnedRow.sourceIndex, targetIndex);
                            pinnedRow.dragOffsetY = 0;
                        }
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Up && pinnedRow.index > 0) {
                            DockStore.movePin(pinnedRow.index, pinnedRow.index - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down
                                && pinnedRow.index < pinnedList.count - 1) {
                            DockStore.movePin(pinnedRow.index, pinnedRow.index + 1);
                            event.accepted = true;
                        }
                    }

                    Accessible.role: Accessible.Grip
                    Accessible.name: I18n.tr("settings.dock.pinned")
                }

                Shared.SystemIcon {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    sourceName: ApplicationService.iconForAppId(pinnedRow.modelData)
                    fallbackName: "dock_to_bottom"
                    size: 28
                }

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: pinnedRow.entry?.name || I18n.tr("settings.dock.unavailable", {
                        "id": pinnedRow.modelData
                    })
                    variant: "label"
                    tone: pinnedRow.entry ? "primary" : "warning"
                    elide: Text.ElideRight
                }

                Shared.Button {
                    iconName: "arrow_upward"
                    variant: "quiet"
                    size: "small"
                    enabled: pinnedRow.index > 0
                    accessibleName: I18n.tr("settings.dock.move_up")
                    onTriggered: DockStore.movePin(pinnedRow.index, pinnedRow.index - 1)
                }

                Shared.Button {
                    iconName: "arrow_downward"
                    variant: "quiet"
                    size: "small"
                    enabled: pinnedRow.index < pinnedList.count - 1
                    accessibleName: I18n.tr("settings.dock.move_down")
                    onTriggered: DockStore.movePin(pinnedRow.index, pinnedRow.index + 1)
                }

                Shared.Button {
                    iconName: "remove_circle_outline"
                    variant: "quiet"
                    size: "small"
                    accessibleName: I18n.tr("settings.dock.remove")
                    onTriggered: DockStore.togglePin(pinnedRow.modelData)
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Metrics.borderWidth
        color: Theme.border
    }

    Shared.TextLabel {
        text: I18n.tr("settings.dock.catalog")
        variant: "label"
        strong: true
    }

    QtControls.TextField {
        id: searchField
        Layout.fillWidth: true
        implicitHeight: 36
        placeholderText: I18n.tr("settings.dock.search")
        color: Theme.textPrimary
        placeholderTextColor: Theme.textSecondary
        font.family: Typography.family
        font.pixelSize: Typography.bodySize
        selectByMouse: true
        onTextEdited: root.query = text

        background: Rectangle {
            radius: Metrics.radiusMedium
            color: Theme.surfaceElevated
            border.width: Metrics.borderWidth
            border.color: searchField.activeFocus ? Theme.focus : Theme.border
        }
    }

    ListView {
        id: catalogList
        Layout.fillWidth: true
        Layout.fillHeight: true
        model: root.filteredApplications
        currentIndex: -1
        clip: true
        spacing: Metrics.spacingXSmall
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true

        delegate: Shared.Surface {
            id: catalogRow
            required property var modelData

            width: catalogList.width
            implicitHeight: 44
            tone: "elevated"
            radius: Metrics.radiusMedium

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Metrics.spacingMedium
                anchors.rightMargin: Metrics.spacingMedium
                spacing: Metrics.spacingMedium

                Shared.SystemIcon {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    sourceName: catalogRow.modelData.icon || ""
                    fallbackName: "apps"
                    size: 28
                }

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: catalogRow.modelData.name
                    variant: "label"
                    elide: Text.ElideRight
                }

                Shared.Toggle {
                    readonly property bool pinned:
                        DockStore.isPinned(catalogRow.modelData.id)
                    checked: pinned
                    accessibleName: I18n.tr(pinned
                        ? "settings.dock.remove" : "settings.dock.add")
                    onToggled: DockStore.togglePin(catalogRow.modelData.id)
                }
            }
        }
    }
}
