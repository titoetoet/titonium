pragma ComponentBehavior: Bound

import QtQuick
import Titonium.Foundation
import Titonium.Platform

Item {
    id: root

    property string backend: ConfigStore.previewState.theme?.materialBackend || "auto"
    property int radius: Metrics.radiusMedium
    property bool outlined: true
    property color customColor: "transparent"
    default property alias contentData: contentItem.data

    readonly property string resolvedBackend: {
        if (root.backend === "auto")
            return Capabilities.nativeGlassAvailable ? "native" : "qml";
        if (root.backend === "native" && !Capabilities.nativeGlassAvailable)
            return "qml";
        return root.backend;
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        color: {
            if (root.customColor.a > 0)
                return root.customColor;
            if (root.resolvedBackend === "native") {
                const nativeMaterial = ConfigStore.themeState.materials?.native || {};
                return Qt.alpha(Theme.surface, nativeMaterial.maskOpacity || 0.08);
            }
            if (root.resolvedBackend === "solid")
                return Theme.surface;
            const qmlMaterial = ConfigStore.themeState.materials?.qml || {};
            return Qt.alpha(Theme.surface, qmlMaterial.opacity || 0.92);
        }
        border.width: root.outlined && root.resolvedBackend !== "native" ? 1 : 0
        border.color: Theme.border
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }
}

