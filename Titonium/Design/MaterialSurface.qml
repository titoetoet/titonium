pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Foundation
import qs.Titonium.Platform

Item {
    id: root

    property string backend: ""
    property int radius: Metrics.radiusMedium
    property bool outlined: true
    property color borderColor: Theme.border
    property color customColor: "transparent"
    default property alias contentData: contentItem.data

    readonly property var materialPolicy: ConfigStore.themeState.material || ({
        "defaultBackend": "solid",
        "allowedBackends": ["solid"],
        "compositorIntegration": false,
        "opacity": 1.0
    })
    readonly property string resolvedBackend: {
        const requested = root.backend.length > 0 ? root.backend : (root.materialPolicy.defaultBackend || "solid");
        const allowed = root.materialPolicy.allowedBackends || ["solid"];
        const qmlFallback = allowed.indexOf("qml") >= 0 ? "qml" : "solid";
        if (requested === "auto")
            return root.materialPolicy.compositorIntegration && Capabilities.nativeGlassAvailable
                && allowed.indexOf("native") >= 0 ? "native" : qmlFallback;
        if (allowed.indexOf(requested) < 0)
            return qmlFallback;
        if (requested === "native" && (!root.materialPolicy.compositorIntegration || !Capabilities.nativeGlassAvailable))
            return qmlFallback;
        return requested;
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        color: {
            if (root.customColor.a > 0)
                return root.customColor;
            return Theme.surface;
        }
        opacity: root.resolvedBackend === "solid" ? 1.0
            : (root.materialPolicy.opacity === undefined ? 0.82 : root.materialPolicy.opacity)
        border.width: root.outlined && root.resolvedBackend !== "native" ? Metrics.borderWidth : 0
        border.color: Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b,
            root.resolvedBackend === "qml" ? (root.materialPolicy.borderOpacity ?? 0.7) : root.borderColor.a)
    }

    // Static optical highlight for the QML fallback. It has no shader, blur,
    // animation or render loop and disappears completely for solid/native.
    Rectangle {
        visible: root.resolvedBackend === "qml"
        anchors.fill: parent
        anchors.margins: Metrics.borderWidth
        radius: Math.max(0, root.radius - Metrics.borderWidth)
        color: Theme.surfaceElevated
        opacity: (root.materialPolicy.tintOpacity ?? 0.78) * 0.18
    }

    Rectangle {
        visible: root.resolvedBackend === "qml"
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Metrics.borderWidth }
        height: 1
        radius: root.radius
        color: Qt.rgba(1, 1, 1, root.materialPolicy.specularOpacity ?? 0.2)
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
