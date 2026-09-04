pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var indicator
    required property bool rendererVisible
    property color backgroundColor: Theme.light ? "#ffffff" : "#000000"
    property int topLeftRadius: Metrics.radiusLarge
    property int topRightRadius: Metrics.radiusLarge
    property int bottomLeftRadius: Metrics.radiusLarge
    property int bottomRightRadius: Metrics.radiusLarge
    property var displayedIndicator: null
    property bool presented: false
    readonly property bool requestedVisible: root.rendererVisible
        && root.indicator?.active === true
    readonly property rect visualBounds: Qt.rect(root.x, root.y, root.width, root.height)
    // This slice is display-only: the exact input region is intentionally empty.
    readonly property rect interactiveBounds: Qt.rect(root.x, root.y, 0, 0)

    implicitWidth: 52
    implicitHeight: Metrics.widgetHeight
    visible: root.presented && root.rendererVisible
    opacity: 0

    function stopMotion(): void {
        wobble.stop();
        bellIcon.rotation = 0;
    }

    function clearPresentation(): void {
        root.stopMotion();
        root.opacity = 0;
        root.presented = false;
        root.displayedIndicator = null;
    }

    function syncIndicator(): void {
        if (!root.requestedVisible) {
            root.stopMotion();
            if (!root.presented)
                return;
            if (Motion.reduced || !root.rendererVisible)
                root.clearPresentation();
            else
                exitAnimation.restart();
            return;
        }

        const previousCount = Number(root.displayedIndicator?.count || 0);
        const nextCount = Number(root.indicator.count || 0);
        const hadIndicator = root.displayedIndicator !== null;
        exitAnimation.stop();
        root.displayedIndicator = root.indicator;
        root.presented = true;
        root.opacity = 1;
        if (hadIndicator && nextCount > previousCount && !Motion.reduced)
            wobble.restart();
    }

    onIndicatorChanged: root.syncIndicator()
    onRendererVisibleChanged: root.syncIndicator()
    onVisibleChanged: {
        if (!root.visible)
            root.stopMotion();
    }
    Component.onCompleted: root.syncIndicator()

    Shared.Surface {
        anchors.fill: parent
        outlined: false
        customColor: root.backgroundColor
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius

        RowLayout {
            anchors.centerIn: parent
            spacing: Metrics.spacingXSmall

            Shared.Icon {
                id: bellIcon
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                name: "notifications"
                size: 18
                tone: "primary"
                transformOrigin: Item.Top
            }

            Shared.TextLabel {
                text: root.displayedIndicator
                    ? (root.displayedIndicator.count > 99
                        ? "99+" : String(root.displayedIndicator.count)) : ""
                variant: "caption"
                strong: true
                Accessible.name: root.displayedIndicator
                    ? root.displayedIndicator.accessibleName : ""
            }
        }
    }

    SequentialAnimation {
        id: wobble
        loops: 3
        NumberAnimation {
            target: bellIcon
            property: "rotation"
            from: 0
            to: -10
            duration: 45
        }
        NumberAnimation {
            target: bellIcon
            property: "rotation"
            to: 10
            duration: 90
        }
        NumberAnimation {
            target: bellIcon
            property: "rotation"
            to: 0
            duration: 45
        }
        onStopped: bellIcon.rotation = 0
    }

    SequentialAnimation {
        id: exitAnimation
        NumberAnimation {
            target: root
            property: "opacity"
            from: 1
            to: 0
            duration: Motion.reduced ? 0 : Motion.normal
        }
        ScriptAction { script: root.clearPresentation() }
    }

    Connections {
        target: Motion
        function onReducedChanged(): void {
            if (!Motion.reduced)
                return;
            root.stopMotion();
            if (!root.requestedVisible)
                root.clearPresentation();
        }
    }
}
