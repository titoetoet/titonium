pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Item {
    id: root

    property var descriptor: null
    property var screen: null

    Keys.onEscapePressed: root.cancelAndClose()

    function cancelAndClose(): void {
        if (ConfigStore.previewActive)
            ConfigStore.cancel();
        SurfaceCoordinator.close("design-gallery");
    }

    function applyAndClose(): void {
        if (ConfigStore.apply())
            SurfaceCoordinator.close("design-gallery");
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.46)

        TapHandler { onTapped: root.cancelAndClose() }
    }

    Controls.Panel {
        id: galleryCard
        anchors.centerIn: parent
        width: Math.min(1000, parent.width - Metrics.spacingLarge * 4)
        height: Math.min(980, parent.height - Metrics.spacingLarge * 4)
        radius: Metrics.radiusLarge
        padding: 0
        outlined: true
        customColor: Theme.background

        TapHandler {}

        Column {
            anchors.fill: parent
            anchors.margins: Metrics.spacingLarge
            spacing: Metrics.spacingMedium

            Item {
                width: parent.width
                height: 48

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Metrics.spacingXSmall

                    Controls.TextLabel {
                        text: I18n.tr("gallery.title")
                        variant: "title"
                    }

                    Controls.TextLabel {
                        text: I18n.tr("gallery.subtitle")
                        variant: "caption"
                        tone: "secondary"
                    }
                }

                Controls.TextLabel {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.id + " · " + Theme.mode + " · solid"
                    variant: "mono"
                    tone: "secondary"
                }
            }

            Rectangle { width: parent.width; height: Metrics.borderWidth; color: Theme.border }

            Row {
                spacing: Metrics.spacingSmall

                Controls.TextLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 132
                    text: I18n.tr("gallery.mode")
                }

                Controls.Button {
                    label: I18n.tr("gallery.dark")
                    selected: Theme.mode === "dark"
                    onTriggered: ConfigStore.patch("appearance.mode", "dark")
                }

                Controls.Button {
                    label: I18n.tr("gallery.light")
                    selected: Theme.mode === "light"
                    onTriggered: ConfigStore.patch("appearance.mode", "light")
                }
            }

            Controls.TextLabel {
                text: I18n.tr("gallery.palette")
                variant: "label"
                strong: true
            }

            Row {
                spacing: Metrics.spacingSmall
                GallerySwatch { swatchColor: Theme.surface; label: "surface" }
                GallerySwatch { swatchColor: Theme.surfaceElevated; label: "elevated" }
                GallerySwatch { swatchColor: Theme.surfaceInteractive; label: "interactive" }
                GallerySwatch { swatchColor: Theme.accent; label: "accent" }
                GallerySwatch { swatchColor: Theme.success; label: "success" }
                GallerySwatch { swatchColor: Theme.warning; label: "warning" }
            }

            GallerySurfaceSection { width: parent.width }

            GalleryInputSection { width: parent.width }

            GalleryTabsSection { width: parent.width }

            GalleryTypographySection { width: parent.width }
            GalleryControlsSection { width: parent.width }

            Item {
                width: parent.width
                height: 48

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Metrics.spacingSmall

                    Controls.Button {
                        label: I18n.tr("gallery.restore")
                        onTriggered: ConfigStore.restoreAppearance()
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Metrics.spacingSmall

                    Controls.Button { label: I18n.tr("gallery.cancel"); onTriggered: root.cancelAndClose() }
                    Controls.Button { label: I18n.tr("gallery.apply"); variant: "primary"; onTriggered: root.applyAndClose() }
                }
            }
        }
    }

    Component.onDestruction: {
        if (ConfigStore.previewActive)
            ConfigStore.cancel();
    }
}
