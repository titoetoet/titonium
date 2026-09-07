pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Wallpapers
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root
    property string screenName: ""
    // Host binds this to tab selection when keeping the component mounted.
    property bool active: true
    property var selected: null
    readonly property bool viewing: root.active && root.visible
    implicitWidth: 700
    implicitHeight: 420
    clip: true

    onViewingChanged: WallpapersService.setVisible(root, root.viewing)
    Component.onCompleted: WallpapersService.setVisible(root, root.viewing)
    Component.onDestruction: WallpapersService.setVisible(root, false)

    Connections {
        target: WallpapersService
        function onItemsChanged(): void { root.selected = null; }
        function onDirectoryChanged(): void { folder.text = WallpapersService.directory; }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingLarge
        spacing: Metrics.spacingSmall

        RowLayout {
            Layout.fillWidth: true
            QtControls.TextField {
                id: folder
                Layout.fillWidth: true
                implicitHeight: Metrics.controlHeight
                text: WallpapersService.directory
                placeholderText: I18n.tr("wallpapers.folder")
                Accessible.name: I18n.tr("wallpapers.folder")
                color: Theme.textPrimary
                placeholderTextColor: Theme.textSecondary
                font.family: Typography.family
                font.pixelSize: Typography.bodySize
                selectByMouse: true
                enabled: !WallpapersService.busy
                onAccepted: WallpapersService.refresh(text)
                background: Rectangle {
                    radius: Metrics.radiusSmall
                    color: Theme.surfaceElevated
                    border.color: folder.activeFocus ? Theme.focus : Theme.border
                }
            }
            Shared.Button {
                label: I18n.tr("wallpapers.refresh")
                enabled: root.viewing && !WallpapersService.busy
                onTriggered: WallpapersService.refresh(folder.text)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Metrics.spacingMedium

            GridView {
                id: catalog
                Layout.preferredWidth: Math.max(140, root.width * 0.44)
                Layout.fillHeight: true
                clip: true
                model: root.viewing ? WallpapersService.items : []
                cellWidth: width / Math.max(1, Math.floor(width / 140))
                cellHeight: 102
                cacheBuffer: 0
                boundsBehavior: Flickable.StopAtBounds
                QtControls.ScrollBar.vertical: QtControls.ScrollBar {}
                delegate: Item {
                    id: tile
                    required property var modelData
                    width: catalog.cellWidth
                    height: catalog.cellHeight
                    Shared.Button {
                        anchors.fill: parent
                        anchors.margins: Metrics.spacingXSmall
                        selected: root.selected?.path === tile.modelData.path
                        accessibleName: tile.modelData.name
                        onTriggered: root.selected = tile.modelData
                        Image {
                            anchors.fill: parent
                            anchors.margins: Metrics.spacingXSmall
                            anchors.bottomMargin: 25
                            source: tile.modelData.url
                            sourceSize.width: 180
                            sourceSize.height: 100
                            asynchronous: true
                            cache: false
                            fillMode: Image.PreserveAspectFit
                        }
                        Shared.TextLabel {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: Metrics.spacingXSmall
                            text: tile.modelData.name
                            variant: "caption"
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
                Shared.TextLabel {
                    anchors.centerIn: parent
                    width: parent.width
                    visible: catalog.count === 0 && !WallpapersService.busy
                    text: I18n.tr("wallpapers.empty")
                    tone: "secondary"
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Image {
                        id: preview
                        anchors.fill: parent
                        source: root.viewing && root.selected ? root.selected.url : ""
                        sourceSize.width: Math.max(1, Math.ceil(width))
                        sourceSize.height: Math.max(1, Math.ceil(height))
                        asynchronous: true
                        cache: false
                        fillMode: Image.PreserveAspectFit
                    }
                    Shared.TextLabel {
                        anchors.centerIn: parent
                        width: parent.width
                        visible: preview.status !== Image.Ready
                        text: I18n.tr(preview.status === Image.Error ? "wallpapers.error.image" : "wallpapers.select")
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        tone: "secondary"
                    }
                }
                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: root.selected?.name || ""
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                }
                Shared.Button {
                    Layout.fillWidth: true
                    label: I18n.tr("wallpapers.apply", {screen: root.screenName})
                    variant: "primary"
                    enabled: root.viewing && !!root.screenName && !!root.selected
                        && preview.status === Image.Ready && WallpapersService.available && !WallpapersService.busy
                    onTriggered: WallpapersService.applyTo(root.screenName, root.selected.path)
                }
            }
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            text: WallpapersService.statusKey ? I18n.tr(WallpapersService.statusKey) : I18n.tr("wallpapers.select")
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            tone: "secondary"
        }
        Shared.TextLabel {
            Layout.fillWidth: true
            visible: WallpapersService.truncated
            text: I18n.tr("wallpapers.truncated")
            variant: "caption"
            tone: "secondary"
        }
    }
}
