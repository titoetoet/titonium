pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    required property string sourceName
    property string fallbackName: "image"
    property int size: 20
    property string tone: "secondary"
    property string accessibleName: ""
    readonly property string resolvedSource: {
        const value = root.sourceName.trim();
        if (value.length === 0)
            return "";
        if (value.indexOf("://") >= 0 || value.indexOf("qrc:") === 0)
            return value;
        if (value.indexOf("/") === 0)
            return "file://" + value;
        return Quickshell.hasThemeIcon(value) ? Quickshell.iconPath(value) : "";
    }
    readonly property bool imageReady: iconImage.status === Image.Ready

    implicitWidth: root.size
    implicitHeight: root.size

    IconImage {
        id: iconImage
        anchors.fill: parent
        source: root.resolvedSource
        implicitSize: root.size
        asynchronous: true
        mipmap: true
        visible: root.imageReady
    }

    Icon {
        anchors.centerIn: parent
        visible: !root.imageReady
        name: root.fallbackName
        size: root.size
        tone: root.tone
        accessibleName: ""
    }

    Accessible.ignored: root.accessibleName.length === 0
    Accessible.name: root.accessibleName
}
