pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property var categories: [
        { "id": "all", "labelKey": "launcher.category.all", "icon": "apps" },
        { "id": "internet", "labelKey": "launcher.category.internet", "icon": "public" },
        { "id": "development", "labelKey": "launcher.category.development", "icon": "code" },
        { "id": "media", "labelKey": "launcher.category.media", "icon": "movie" },
        { "id": "system", "labelKey": "launcher.category.system", "icon": "settings" }
    ]

    anchors.fill: parent
    focus: true

    function close(): void {
        SurfaceCoordinator.close(root.ownerId);
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.28)
        TapHandler { onTapped: root.close() }
    }

    Controls.Panel {
        id: panel
        z: 1
        width: Math.min(1000, root.width - Metrics.spacingLarge * 2)
        height: Math.min(620, root.height - Metrics.barHeight - Metrics.spacingLarge * 2)
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Metrics.barHeight + Metrics.spacingSmall
        anchors.leftMargin: Metrics.barPadding
        padding: Metrics.spacingLarge

        TapHandler {}

        RowLayout {
            anchors.fill: parent
            spacing: Metrics.spacingLarge

            ColumnLayout {
                Layout.preferredWidth: 184
                Layout.fillHeight: true
                spacing: Metrics.spacingSmall

                Controls.TextLabel {
                    text: I18n.tr("launcher.title")
                    variant: "title_large"
                    strong: true
                }

                Controls.TextLabel {
                    Layout.fillWidth: true
                    text: I18n.tr("launcher.subtitle")
                    variant: "caption"
                    tone: "secondary"
                    wrapMode: Text.WordWrap
                }

                Item { implicitHeight: Metrics.spacingSmall }

                Repeater {
                    model: root.categories

                    Controls.Button {
                        required property var modelData
                        Layout.fillWidth: true
                        label: I18n.tr(modelData.labelKey)
                        iconName: modelData.icon
                        variant: "quiet"
                        selected: catalog.category === modelData.id
                        accessibleName: label
                        onTriggered: catalog.category = modelData.id
                    }
                }

                Item { Layout.fillHeight: true }

                Controls.TextLabel {
                    Layout.fillWidth: true
                    text: I18n.tr("launcher.keyboard_hint")
                    variant: "caption"
                    tone: "secondary"
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: Metrics.borderWidth
                color: Theme.border
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Metrics.spacingMedium

                RowLayout {
                    Layout.fillWidth: true

                    Controls.Surface {
                        Layout.fillWidth: true
                        implicitWidth: 1
                        implicitHeight: Metrics.controlHeight
                        tone: "elevated"
                        radius: Metrics.radiusMedium
                        outlined: true
                        borderColor: searchInput.activeFocus ? Theme.focus : Theme.border

                        Controls.Icon {
                            anchors.left: parent.left
                            anchors.leftMargin: Metrics.spacingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            name: "search"
                            size: 19
                            tone: searchInput.activeFocus ? "accent" : "secondary"
                            accessibleName: ""
                        }

                        TextInput {
                            id: searchInput
                            anchors.left: parent.left
                            anchors.leftMargin: 42
                            anchors.right: clearButton.left
                            anchors.rightMargin: Metrics.spacingSmall
                            anchors.verticalCenter: parent.verticalCenter
                            text: catalog.query
                            color: Theme.textPrimary
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentText
                            font.family: Typography.family
                            font.pixelSize: Typography.sizeFor("body")
                            selectByMouse: true
                            clip: true
                            onTextEdited: catalog.query = text

                            Controls.TextLabel {
                                anchors.fill: parent
                                visible: searchInput.text.length === 0
                                text: I18n.tr("launcher.search_placeholder")
                                tone: "secondary"
                            }
                        }

                        Controls.Button {
                            id: clearButton
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            visible: catalog.query.length > 0
                            iconName: "close"
                            variant: "quiet"
                            size: "small"
                            accessibleName: I18n.tr("launcher.clear_search")
                            onTriggered: {
                                catalog.query = "";
                                searchInput.text = "";
                                searchInput.forceActiveFocus(Qt.ShortcutFocusReason);
                            }
                        }
                    }

                    Controls.Button {
                        iconName: "close"
                        variant: "quiet"
                        size: "small"
                        accessibleName: I18n.tr("launcher.close")
                        onTriggered: root.close()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Controls.TextLabel {
                        Layout.fillWidth: true
                        text: I18n.tr("launcher.results", { "count": catalog.filteredApplications.length })
                        variant: "title_small"
                        strong: true
                    }

                    Controls.TextLabel {
                        visible: catalog.filteredApplications.length > catalog.visibleLimit
                        text: I18n.tr("launcher.result_limit", { "count": catalog.visibleLimit })
                        variant: "caption"
                        tone: "secondary"
                    }
                }

                GridView {
                    id: applicationGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: width / 6
                    cellHeight: 112
                    model: catalog.visibleApplications

                    delegate: ApplicationTile {
                        required property var modelData
                        width: applicationGrid.cellWidth - Metrics.spacingSmall
                        height: applicationGrid.cellHeight - Metrics.spacingSmall
                        application: modelData
                        onTriggered: {
                            if (catalog.launch(modelData))
                                root.close();
                        }
                    }

                    Controls.TextLabel {
                        anchors.centerIn: parent
                        visible: catalog.filteredApplications.length === 0
                        text: I18n.tr("launcher.no_results")
                        tone: "secondary"
                    }
                }
            }
        }
    }

    ApplicationCatalogModel { id: catalog }

    Keys.onEscapePressed: event => {
        if (catalog.query.length > 0) {
            catalog.query = "";
            searchInput.text = "";
        } else {
            root.close();
        }
        event.accepted = true;
    }

    Component.onCompleted: Qt.callLater(() => searchInput.forceActiveFocus(Qt.PopupFocusReason))
}
