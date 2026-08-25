pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Foundation
import qs.Titonium.Platform

Item {
    id: root

    property string backend: ""
    property int radius: Metrics.radiusMedium
    property bool outlined: true
    property color customColor: "transparent"
    default property alias contentData: contentItem.data

    readonly property var materialPolicy: ConfigStore.themeState.material || ({
        "defaultBackend": "solid",
        "allowedBackends": ["solid"],
        "compositorIntegration": false,
        "opacity": 1.0
    })
    readonly property string resolvedBackend: {
        const fallback = root.materialPolicy.defaultBackend || "solid";
        const requested = root.backend.length > 0 ? root.backend : fallback;
        const allowed = root.materialPolicy.allowedBackends || ["solid"];
        if (allowed.indexOf(requested) < 0)
            return fallback;
        if (requested === "native" && (!root.materialPolicy.compositorIntegration || !Capabilities.nativeGlassAvailable))
            return allowed.indexOf("solid") >= 0 ? "solid" : fallback;
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
        opacity: root.materialPolicy.opacity === undefined ? 1.0 : root.materialPolicy.opacity
        border.width: root.outlined && root.resolvedBackend !== "native" ? Metrics.borderWidth : 0
        border.color: Theme.border
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
