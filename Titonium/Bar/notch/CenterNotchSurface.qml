pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Bar.islands
import qs.Titonium.Bar.right
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.AgentApproval
import qs.Titonium.Services.Notifications
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "CenterNotchState.js" as CenterNotchState

FocusScope {
    id: root

    required property ShellScreen screenModel
    required property bool ownsIsland
    required property real compactY
    property bool closeRequested: false
    signal bannerRequested(var screen, var context, bool autoDismiss)
    signal settingsRequested(var screen)
    signal closeAnimationFinished()

    readonly property string islandState: CenterNotchCoordinator.visualState
    readonly property var layoutProfile: CenterNotchState.layoutProfile(root.width, root.height)
    readonly property real compactHeight: root.layoutProfile.compactHeight
    readonly property real compactRadius: root.compactHeight / 2
    readonly property real compactPrimaryWidth: CenterNotchState.compactPrimaryWidth(
        centerIsland.implicitWidth, root.satellitePresented
            ? root.layoutProfile.nestedMaxWidth : root.layoutProfile.primaryMaxWidth)
    readonly property bool satelliteDesired: !root.ownsIsland
        && CenterNotchCoordinator.satelliteActive
    property bool satellitePresented: root.satelliteDesired
    property real satelliteExitProgress: 0
    property var presentedSecondary: CenterNotchCoordinator.activitySlots.secondary
    readonly property real bannerWidth: 480
    readonly property real expandedWidth: Math.min(720, Math.max(320, root.width - 40))
    readonly property real drag: CenterNotchCoordinator.dragProgress
    property real transitionProgress: root.ownsIsland ? 1 : 0
    readonly property real compactContentOpacity: 1
        - Math.min(1, root.transitionProgress / 0.35)
    readonly property real openContentOpacity: Math.max(0,
        Math.min(1, (root.transitionProgress - 0.15) / 0.5))
    readonly property bool draggingBanner: root.ownsIsland
        && CenterNotchCoordinator.requestedPage === "banner" && root.drag > 0
    readonly property real targetVisualWidth: root.ownsIsland
        ? (CenterNotchCoordinator.requestedPage === "banner"
            ? root.bannerWidth + (root.expandedWidth - root.bannerWidth) * root.drag
            : root.expandedWidth)
        : root.compactPrimaryWidth
    readonly property real targetHeight: root.ownsIsland
        ? (CenterNotchCoordinator.requestedPage === "banner"
            ? 72 + (440 - 72) * root.drag : 440)
        : root.compactHeight
    readonly property real targetRadius: root.ownsIsland
        ? (CenterNotchCoordinator.requestedPage === "banner"
            ? 22 + (28 - 22) * root.drag : 28)
        : root.compactRadius
    readonly property real targetBodyWidth: CenterNotchState.connectedBodyWidth(
        root.targetVisualWidth, root.targetRadius)
    readonly property real targetY: root.ownsIsland ? 0 : root.compactY
    readonly property real visualX: connectedShape.x
    readonly property real visualY: connectedShape.y
    readonly property real visualWidth: connectedShape.width
    readonly property real visualHeight: connectedShape.height
    readonly property real compactInputX: connectedShape.x
    readonly property real compactInputWidth: connectedShape.width
    readonly property real compactInputHeight: root.compactHeight + 4

    anchors.fill: parent
    focus: root.ownsIsland

    Behavior on transitionProgress {
        NumberAnimation {
            duration: Motion.reduced ? 0 : (root.ownsIsland ? 240 : 190)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
    }

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    function primaryContext(): var {
        if (AgentApprovalService.hasPending)
            return ({ source: "agent", id: AgentApprovalService.current.requestId,
                title: AgentApprovalService.current.summary
                    || AgentApprovalService.current.command
                    || I18n.tr("agent_approval.needs_approval") });
        return CenterNotchCoordinator.primaryContext;
    }

    function openPrimaryBanner(): void {
        const context = root.primaryContext();
        if (CenterNotchState.entryPage(context.source) === "overview") {
            CenterNotchCoordinator.openAgentApproval(root.screenModel.name, context);
            return;
        }
        root.bannerRequested(root.screenModel, context, false);
    }

    function settleDrag(offset: real, velocity: real): void {
        const plan = CenterNotchCoordinator.finishDrag(offset, velocity);
        dragSettle.stop();
        dragSettle.from = CenterNotchCoordinator.dragProgress;
        dragSettle.to = plan.targetProgress;
        dragSettle.duration = Motion.reduced ? 0 : plan.duration;
        dragSettle.targetState = plan.targetState;
        dragSettle.start();
    }

    function settleToExpanded(): void {
        root.settleDrag(48, 0);
    }

    NumberAnimation {
        id: dragSettle
        property string targetState: "banner"
        target: CenterNotchCoordinator
        property: "dragProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.springDamped
        onFinished: CenterNotchCoordinator.completeDragSettle(dragSettle.targetState)
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        visible: root.ownsIsland

        TapHandler {
            enabled: root.ownsIsland
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: eventPoint => {
                if (!root.pointInside(connectedShape, eventPoint.position))
                    CenterNotchCoordinator.collapse();
            }
        }
    }

    Shared.ConnectedPillShape {
        id: connectedShape
        anchors.top: parent.top
        anchors.topMargin: islandBody.y
        anchors.horizontalCenter: parent.horizontalCenter
        bodyWidth: islandBody.width
        bodyHeight: islandBody.height
        shoulderSize: islandBody.radius
        bottomRadius: islandBody.radius
        color: Theme.light ? "#ffffff" : "#000000"
    }

    StartIsland {
        z: 10
        x: 0
        y: 0
        width: Math.max(0, RightPillCoordinator.leftCompactWidth - 16)
        height: 36
        visible: root.ownsIsland
        screen: root.screenModel
    }

    EndIsland {
        z: 10
        anchors.right: parent.right
        y: 0
        width: Math.max(0, RightPillCoordinator.rightCompactWidth - 16)
        height: 36
        visible: root.ownsIsland
        screen: root.screenModel
    }

    Item {
        id: islandBody
        width: root.targetBodyWidth
        height: root.targetHeight
        y: root.targetY
        anchors.horizontalCenter: parent.horizontalCenter
        property real radius: root.targetRadius

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: root.settingsRequested(root.screenModel)
        }

        Behavior on width {
            enabled: !root.draggingBanner
            NumberAnimation { duration: Motion.reduced ? 0 : 240; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.springDamped }
        }
        Behavior on height {
            enabled: !root.draggingBanner
            NumberAnimation {
                duration: Motion.reduced ? 0 : (root.ownsIsland ? 240 : 190)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.springDamped
                onFinished: {
                    if (root.closeRequested)
                        root.closeAnimationFinished();
                }
            }
        }
        Behavior on y { NumberAnimation { duration: Motion.reduced ? 0 : Motion.fast; easing.type: Easing.OutCubic } }
        Behavior on radius { NumberAnimation { duration: Motion.reduced ? 0 : 220; easing.type: Easing.OutCubic } }

        CenterIsland {
            id: centerIsland
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: CenterNotchState.connectedBodyWidth(
                root.compactPrimaryWidth, root.compactRadius)
            height: root.compactHeight
            screen: root.screenModel
            forcedWidth: CenterNotchState.connectedBodyWidth(
                root.compactPrimaryWidth, root.compactRadius)
            forcedHeight: root.compactHeight
            trailingReservedWidth: root.satellitePresented ? 44 : 0
            visible: root.compactContentOpacity > 0
            enabled: root.transitionProgress < 0.2
            opacity: root.compactContentOpacity
            onNotchRequested: root.openPrimaryBanner()
            onSettingsRequested: screen => root.settingsRequested(screen)
        }

        CenterNotch {
            id: expandedContent
            anchors.fill: parent
            visible: root.openContentOpacity > 0
            enabled: root.transitionProgress > 0.8
            opacity: root.openContentOpacity
            scale: 0.985 + root.openContentOpacity * 0.015
            islandRadius: islandBody.radius
            entranceRequested: root.ownsIsland
            closing: root.closeRequested
            screenModel: root.screenModel
            onExpandedRequested: root.settleToExpanded()
            onDragStarted: dragSettle.stop()
            onDragFinished: (offset, velocity) => root.settleDrag(offset, velocity)
        }
        Rectangle {
            id: nestedSatellite
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: root.compactHeight / 2
            z: 2
            visible: root.satellitePresented
            width: 32
            height: 28
            radius: 14
            color: nestedHover.hovered
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
            scale: root.satelliteDesired ? 1 : 0.82
            opacity: root.satelliteDesired ? 1 : 0

            Behavior on scale {
                NumberAnimation {
                    duration: Motion.reduced ? 0 : 220
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.springDamped
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.reduced ? 0 : 140
                    easing.type: Easing.OutCubic
                }
            }

            Row {
                id: nestedEqualizer
                anchors.centerIn: parent
                visible: root.presentedSecondary?.source === "media"
                spacing: 1.5
                scale: nestedHover.hovered ? 1.14 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.reduced ? 0 : 140
                        easing.type: Easing.OutCubic
                    }
                }

                Repeater {
                    model: [4, 7, 5, 8, 3]

                    Rectangle {
                        id: equalizerBar
                        required property int index
                        required property real modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: modelData
                        radius: 1
                        color: Theme.accent

                        SequentialAnimation {
                            running: root.satelliteDesired
                                && nestedEqualizer.visible && !Motion.reduced
                            loops: 99999
                            NumberAnimation {
                                target: equalizerBar
                                property: "height"
                                from: equalizerBar.modelData
                                to: Math.min(16, equalizerBar.modelData + 7)
                                duration: 260 + equalizerBar.index * 45
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                target: equalizerBar
                                property: "height"
                                from: Math.min(16, equalizerBar.modelData + 7)
                                to: equalizerBar.modelData
                                duration: 310 + (4 - equalizerBar.index) * 40
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
            }

            Item {
                id: nestedNotificationIcon
                anchors.centerIn: parent
                width: 18
                height: 18
                visible: root.presentedSecondary?.source === "notification"
                scale: nestedHover.hovered ? 1.14 : 1

                Shared.Icon {
                    id: nestedBell
                    anchors.centerIn: parent
                    name: root.presentedSecondary?.icon || "notifications"
                    size: 18
                    tone: "accent"
                    transform: Translate { id: nestedBellLift }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: -2
                    anchors.rightMargin: -3
                    width: 9
                    height: 9
                    radius: 4.5
                    color: "#10b981"

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: "#ffffff"
                        font.pixelSize: 7
                        font.bold: true
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.reduced ? 0 : 140
                        easing.type: Easing.OutCubic
                    }
                }

                SequentialAnimation {
                    running: root.satelliteDesired
                        && nestedNotificationIcon.visible && !Motion.reduced
                    loops: 99999
                    ParallelAnimation {
                        NumberAnimation { target: nestedBell; property: "rotation"; from: 0; to: -12; duration: 90; easing.type: Easing.OutQuad }
                        NumberAnimation { target: nestedBellLift; property: "y"; from: 0; to: -2; duration: 90; easing.type: Easing.OutQuad }
                    }
                    NumberAnimation { target: nestedBell; property: "rotation"; from: -12; to: 12; duration: 150; easing.type: Easing.InOutQuad }
                    ParallelAnimation {
                        NumberAnimation { target: nestedBell; property: "rotation"; from: 12; to: 0; duration: 110; easing.type: Easing.OutQuad }
                        NumberAnimation { target: nestedBellLift; property: "y"; from: -2; to: 0; duration: 110; easing.type: Easing.OutBounce }
                    }
                    PauseAnimation { duration: 2400 }
                }
            }

            Shared.Icon {
                anchors.centerIn: parent
                visible: root.presentedSecondary?.source !== "media"
                    && root.presentedSecondary?.source !== "notification"
                name: root.presentedSecondary?.icon || "bolt"
                size: 18
                tone: "accent"
                scale: nestedHover.hovered ? 1.14 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.reduced ? 0 : 140
                        easing.type: Easing.OutCubic
                    }
                }
            }

            HoverHandler {
                id: nestedHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    const secondary = root.presentedSecondary;
                    if (secondary)
                        root.bannerRequested(root.screenModel,
                            CenterNotchCoordinator.secondaryContext, false);
                }
            }
        }
    }

    Connections {
        target: AgentApprovalService
        function onPendingChanged(): void {
            if (AgentApprovalService.hasPending
                    && AgentApprovalService.popupScreenName === root.screenModel.name) {
                CenterNotchCoordinator.openAgentApproval(root.screenModel.name, {
                    source: "agent",
                    id: AgentApprovalService.current.requestId,
                    title: AgentApprovalService.current.summary
                        || AgentApprovalService.current.command
                        || I18n.tr("agent_approval.needs_approval")
                });
            } else if (!AgentApprovalService.hasPending
                    && CenterNotchCoordinator.selectedContext?.source === "agent") {
                CenterNotchCoordinator.collapse();
            }
        }
    }

    Connections {
        target: NotificationService
        function onUrgentNotification(descriptor: var): void {
            if (CenterNotchState.shouldAutoOpen(CenterNotchCoordinator.visualState,
                    "notification", descriptor.urgency))
                root.bannerRequested(root.screenModel, descriptor, true);
        }
    }

    Keys.onEscapePressed: event => {
        CenterNotchCoordinator.collapse();
        event.accepted = true;
    }

    onOwnsIslandChanged: {
        if (root.ownsIsland)
            islandBody.forceActiveFocus(Qt.PopupFocusReason);
    }

    onSatelliteDesiredChanged: {
        if (root.satelliteDesired) {
            nestedExitRelease.stop();
            root.satelliteExitProgress = 0;
            root.presentedSecondary = CenterNotchCoordinator.activitySlots.secondary;
            root.satellitePresented = true;
        } else if (Motion.reduced) {
            root.satellitePresented = false;
        } else {
            nestedExitRelease.restart();
        }
    }

    NumberAnimation {
        id: nestedExitRelease
        target: root
        property: "satelliteExitProgress"
        from: 0
        to: 1
        duration: 140
        onFinished: {
            if (!root.satelliteDesired)
                root.satellitePresented = false;
        }
    }

    Connections {
        target: CenterNotchCoordinator
        function onSecondaryContextChanged(): void {
            if (root.satelliteDesired && CenterNotchCoordinator.activitySlots.secondary)
                root.presentedSecondary = CenterNotchCoordinator.activitySlots.secondary;
        }
    }
}
