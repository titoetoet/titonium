pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme

Item {
    id: root
    property var tokens: Theme.tokens
    readonly property bool legacyPaint: tokens.legacy !== false
    property string styleRole: "surface"
    property string tone: "surface"
    property int radius: Math.round((root.legacyPaint ? Metrics.radiusSmall : root.tokens.design.panelRadius) * root.tokens.material.radiusScale)
    property int topLeftRadius: root.radius
    property int topRightRadius: root.radius
    property int bottomLeftRadius: root.radius
    property int bottomRightRadius: root.radius
    property int padding: 0
    property bool outlined: true
    property color borderColor: root.tokens.colors.border
    property bool clipContent: false
    property color customColor: "transparent"
    default property alias contentData: contentItem.data
    readonly property alias contentItem: contentItem
    readonly property color resolvedColor: root.customColor.a > 0 ? root.customColor
        : ({ background: root.tokens.colors.background, surface: root.tokens.colors.surface,
            elevated: root.tokens.colors.surfaceElevated, interactive: root.tokens.colors.surfaceInteractive })[root.tone]
            || root.tokens.colors.surface

    implicitWidth: contentItem.childrenRect.width + root.padding * 2
    implicitHeight: contentItem.childrenRect.height + root.padding * 2

    // Fixed primitive shadows do not create layers or change content/input geometry.
    Rectangle {
        objectName: "appearanceShadow"
        anchors.fill: parent
        anchors.leftMargin: -3
        anchors.rightMargin: -3
        anchors.topMargin: 0
        anchors.bottomMargin: -6
        radius: root.radius + 3
        color: Qt.alpha("#000000", 0.14 * root.tokens.material.shadowStrength)
        visible: root.legacyPaint && root.tokens.material.shadowStrength > 0
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: root.radius + 1
        color: Qt.alpha("#000000", 0.10 * root.tokens.material.shadowStrength)
        visible: root.legacyPaint && root.tokens.material.shadowStrength > 0
    }
    Rectangle {
        objectName: "appearancePaint"
        visible: root.legacyPaint
        anchors.fill: parent
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: Qt.alpha(root.resolvedColor, root.resolvedColor.a * root.tokens.material.backgroundOpacity)
        opacity: 1.0
        border.width: root.outlined ? Metrics.borderWidth : 0
        border.color: Qt.alpha(root.borderColor, root.borderColor.a * root.tokens.material.borderStrength)
    }

    Rectangle {
        objectName: "appearanceSheen"
        anchors.fill: parent
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        visible: root.legacyPaint && root.tokens.material.sheenStrength > 0
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha("#ffffff", 0.12 * root.tokens.material.sheenStrength) }
            GradientStop { position: 0.55; color: "transparent" }
            GradientStop { position: 1; color: Qt.alpha("#000000", 0.025 * root.tokens.material.sheenStrength) }
        }
    }

    StylePaint {
        objectName: "styleSurfacePaint"
        anchors.fill: parent
        visible: !root.legacyPaint
        tokens: root.tokens
        role: root.styleRole
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        customColor: root.resolvedColor
        outlined: root.outlined
        borderColor: root.borderColor
    }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: root.padding
        clip: root.clipContent
    }
}
