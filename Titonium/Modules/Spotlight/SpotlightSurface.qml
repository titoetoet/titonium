pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""

    anchors.fill: parent
    focus: true

    function close(): void {
        SurfaceCoordinator.close(root.ownerId);
    }

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    function handleEscape(): void {
        if (spotlightModel.escape())
            root.close();
    }

    function publishState(): void {
        if (!root.descriptor || SurfaceCoordinator.ownerId !== root.ownerId)
            return;
        if (root.descriptor?.stateMode === spotlightModel.mode
                && root.descriptor?.query === spotlightModel.query
                && root.descriptor?.selectedIndex === spotlightModel.selectedIndex)
            return;
        SurfaceCoordinator.open(root.ownerId, {
            "source": root.descriptor.source,
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": root.ownerId,
            "mode": "applications",
            "query": spotlightModel.query,
            "stateMode": spotlightModel.mode,
            "selectedIndex": spotlightModel.selectedIndex
        }, root.screen);
    }

    onDescriptorChanged: {
        const descriptorQuery = root.descriptor?.query || "";
        if (descriptorQuery !== spotlightModel.query)
            spotlightModel.setQuery(descriptorQuery);
    }

    SpotlightModel { id: spotlightModel }

    Connections {
        target: spotlightModel
        function onModeChanged(): void { root.publishState(); }
        function onQueryChanged(): void { root.publishState(); }
        function onSelectedIndexChanged(): void { root.publishState(); }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.42)
        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(panel, eventPoint.position))
                    root.close();
            }
        }
    }

    Controls.Panel {
        id: panel
        z: 1
        width: Math.min(800, root.width - Metrics.spacingLarge * 4)
        height: Math.min(620, root.height - Metrics.spacingLarge * 4)
        anchors.centerIn: parent
        customColor: Theme.background

        ColumnLayout {
            anchors.fill: parent
            spacing: Metrics.spacingMedium

            QtControls.TextField {
                id: searchField
                Layout.fillWidth: true
                implicitHeight: 44
                activeFocusOnTab: true
                text: spotlightModel.query
                placeholderText: I18n.tr("spotlight.search_placeholder")
                color: Theme.textPrimary
                placeholderTextColor: Theme.textSecondary
                font.family: Typography.family
                font.pixelSize: Typography.bodyLargeSize
                leftPadding: Metrics.spacingLarge
                rightPadding: Metrics.spacingLarge
                selectByMouse: true

                background: Rectangle {
                    radius: Metrics.radiusMedium
                    color: Theme.surfaceElevated
                    border.width: Metrics.borderWidth
                    border.color: searchField.activeFocus ? Theme.focus : Theme.border
                }

                onTextEdited: spotlightModel.setQuery(text)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) {
                        spotlightModel.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        spotlightModel.moveSelection(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (spotlightModel.activateSelected())
                            root.close();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.handleEscape();
                        event.accepted = true;
                    }
                }

                Accessible.role: Accessible.EditableText
                Accessible.name: I18n.tr("spotlight.search_accessible")
                Accessible.focusable: true
            }

            Flickable {
                Layout.fillWidth: true
                implicitHeight: categoryRow.implicitHeight
                contentWidth: categoryRow.implicitWidth
                contentHeight: height
                visible: spotlightModel.mode === "browse"
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: categoryRow
                    spacing: Metrics.spacingSmall

                    Repeater {
                        model: spotlightModel.categories

                        Controls.Button {
                            required property var modelData
                            label: I18n.tr("spotlight.category." + modelData.id)
                            variant: "quiet"
                            size: "small"
                            selected: spotlightModel.categoryId === modelData.id
                            accessibleName: I18n.tr("spotlight.category_accessible", { "name": label })
                            onTriggered: {
                                spotlightModel.setCategory(modelData.id);
                                searchField.forceActiveFocus(Qt.ShortcutFocusReason);
                            }
                        }
                    }
                }
            }

            Loader {
                id: bodyLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: spotlightModel.mode === "browse" || spotlightModel.mode === "results"
                source: spotlightModel.mode === "browse"
                    ? Qt.resolvedUrl("AppGrid.qml")
                    : (spotlightModel.mode === "results" ? Qt.resolvedUrl("SearchResults.qml") : "")
            }

            Binding {
                target: bodyLoader.item || null
                property: "spotlightModel"
                value: spotlightModel
                when: bodyLoader.item !== null
            }

            Connections {
                target: bodyLoader.item || null
                function onActivatedSuccessfully(): void { root.close(); }
            }
        }
    }

    Keys.onEscapePressed: event => {
        root.handleEscape();
        event.accepted = true;
    }

    Component.onCompleted: {
        spotlightModel.open(root.descriptor?.mode || "applications");
        spotlightModel.setQuery(root.descriptor?.query || "");
        searchField.forceActiveFocus(Qt.PopupFocusReason);
    }
}
