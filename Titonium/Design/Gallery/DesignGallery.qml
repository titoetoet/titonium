pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Foundation

Item {
    id: root

    property var descriptor: null
    property var screen: null

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

    MaterialSurface {
        id: galleryCard
        anchors.centerIn: parent
        width: Math.min(860, parent.width - Metrics.spacingLarge * 4)
        height: Math.min(540, parent.height - Metrics.spacingLarge * 4)
        radius: Metrics.radiusLarge
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

                    Text {
                        text: I18n.tr("gallery.title")
                        color: Theme.textPrimary
                        font.family: Typography.family
                        font.pixelSize: Typography.titleSize
                        font.weight: Typography.semiboldWeight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: I18n.tr("gallery.subtitle")
                        color: Theme.textSecondary
                        font.family: Typography.family
                        font.pixelSize: Typography.captionSize
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.id + " · " + Theme.mode + " · solid"
                    color: Theme.textSecondary
                    font.family: Typography.monoFamily
                    font.pixelSize: Typography.captionSize
                    renderType: Text.NativeRendering
                }
            }

            Rectangle { width: parent.width; height: Metrics.borderWidth; color: Theme.border }

            Row {
                spacing: Metrics.spacingSmall

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 132
                    text: I18n.tr("gallery.mode")
                    color: Theme.textPrimary
                    font.family: Typography.family
                    font.pixelSize: Typography.bodySize
                    renderType: Text.NativeRendering
                }

                GalleryAction {
                    label: I18n.tr("gallery.dark")
                    kind: Theme.mode === "dark" ? "focus" : "default"
                    onTriggered: ConfigStore.patch("appearance.mode", "dark")
                }

                GalleryAction {
                    label: I18n.tr("gallery.light")
                    kind: Theme.mode === "light" ? "focus" : "default"
                    onTriggered: ConfigStore.patch("appearance.mode", "light")
                }
            }

            Text {
                text: I18n.tr("gallery.palette")
                color: Theme.textPrimary
                font.family: Typography.family
                font.pixelSize: Typography.bodySize
                font.weight: Typography.semiboldWeight
                renderType: Text.NativeRendering
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

            Text {
                text: I18n.tr("gallery.surfaces")
                color: Theme.textPrimary
                font.family: Typography.family
                font.pixelSize: Typography.bodySize
                font.weight: Typography.semiboldWeight
                renderType: Text.NativeRendering
            }

            Row {
                spacing: Metrics.spacingSmall

                MaterialSurface {
                    width: 240
                    height: 72
                    radius: Metrics.radiusMedium
                    outlined: true
                    Text { anchors.centerIn: parent; text: "Surface · border 1px"; color: Theme.textPrimary; font.family: Typography.family; renderType: Text.NativeRendering }
                }

                MaterialSurface {
                    width: 240
                    height: 72
                    radius: Metrics.radiusMedium
                    outlined: true
                    customColor: Theme.surfaceElevated
                    Text { anchors.centerIn: parent; text: "Elevated · tonal only"; color: Theme.textPrimary; font.family: Typography.family; renderType: Text.NativeRendering }
                }
            }

            Text {
                text: I18n.tr("gallery.typography")
                color: Theme.textPrimary
                font.family: Typography.family
                font.pixelSize: Typography.bodySize
                font.weight: Typography.semiboldWeight
                renderType: Text.NativeRendering
            }

            Row {
                spacing: Metrics.spacingLarge
                Text { text: "Title / Semibold / 16"; color: Theme.textPrimary; font.family: Typography.family; font.pixelSize: Typography.titleSize; font.weight: Typography.semiboldWeight; renderType: Text.NativeRendering }
                Text { text: "Body / Regular / 13"; color: Theme.textPrimary; font.family: Typography.family; font.pixelSize: Typography.bodySize; renderType: Text.NativeRendering }
                Text { text: "Caption / Secondary / 11"; color: Theme.textSecondary; font.family: Typography.family; font.pixelSize: Typography.captionSize; renderType: Text.NativeRendering }
            }

            Text {
                text: I18n.tr("gallery.states")
                color: Theme.textPrimary
                font.family: Typography.family
                font.pixelSize: Typography.bodySize
                font.weight: Typography.semiboldWeight
                renderType: Text.NativeRendering
            }

            Row {
                spacing: Metrics.spacingSmall
                GalleryAction { label: I18n.tr("gallery.default") }
                GalleryAction { label: I18n.tr("gallery.focus"); kind: "focus" }
                GalleryAction { label: I18n.tr("gallery.disabled"); controlEnabled: false }
                GalleryAction { label: I18n.tr("gallery.error"); kind: "danger" }
            }

            Item {
                width: parent.width
                height: 48

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Metrics.spacingSmall

                    GalleryAction {
                        label: I18n.tr("gallery.restore")
                        onTriggered: ConfigStore.restoreAppearance()
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Metrics.spacingSmall

                    GalleryAction { label: I18n.tr("gallery.cancel"); onTriggered: root.cancelAndClose() }
                    GalleryAction { label: I18n.tr("gallery.apply"); kind: "primary"; onTriggered: root.applyAndClose() }
                }
            }
        }
    }

    Component.onDestruction: {
        if (ConfigStore.previewActive)
            ConfigStore.cancel();
    }
}
