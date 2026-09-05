pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Bar.center
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "../../CenterPresentationRules.js" as PresentationRules

FocusScope {
    id: root
    required property var snapshot
    required property var viewState
    required property var profile
    signal intentRequested(var intent)
    signal transitionFinished(int generation)
    readonly property var context: root.snapshot.contexts.find(
        item => item.id === root.viewState.selectedContextId) || root.snapshot.primary
    property var displayedContext: null
    property var pendingContext: null
    readonly property var contextActions: root.snapshot.capabilities.actions.filter(
        item => root.displayedContext && item.contextId === root.displayedContext.id)
    readonly property var notificationIndicator: root.snapshot.indicators.find(
        item => item.id === "notification:unread") || null
    readonly property var contextTransitionPlan:
        PresentationRules.contextTransition(root.profile, Motion.reduced)
    readonly property bool popupMode: root.viewState.mode === "banner"
        || root.viewState.mode === "expanded"
    readonly property real popupTop: Metrics.barHeight + Metrics.barSpacing
    property string displayedPopupMode: ""
    property string previousMode: "closed"
    property bool popupClosing: false
    property int transitionGeneration: 0
    readonly property var popupGeometry: PresentationRules.classicPopupGeometry(
        root.profile, { width: root.width, height: root.height },
        root.displayedPopupMode || "banner", Metrics.barHeight, Metrics.barSpacing)
    readonly property var openMotion:
        PresentationRules.classicPopupMotion("open", Motion.reduced)
    readonly property var closeMotion:
        PresentationRules.classicPopupMotion("close", Motion.reduced)
    readonly property rect primaryVisualBounds: Qt.rect(
        root.popupMode || root.popupClosing ? popupPanel.x : classicBody.x,
        root.popupMode || root.popupClosing ? popupPanel.y : classicBody.y,
        root.popupMode || root.popupClosing ? popupPanel.width : classicBody.width,
        root.popupMode || root.popupClosing ? popupPanel.height : classicBody.height)
    readonly property var composedVisualBounds:
        PresentationRules.combinedVisualBounds(root.primaryVisualBounds,
            secondaryPill.visualBounds, secondaryPill.visible)
    readonly property rect visualBounds: Qt.rect(
        root.composedVisualBounds.x, root.composedVisualBounds.y,
        root.composedVisualBounds.width, root.composedVisualBounds.height)
    readonly property rect interactiveBounds: root.primaryVisualBounds

    function deadlineIntent(type: string): var {
        return {
            type: type,
            generation: root.viewState.generation,
            contextId: root.viewState.selectedContextId,
            deadline: root.viewState.deadlineToken,
        };
    }

    function replaceDisplayedContext(nextContext: var): void {
        root.pendingContext = nextContext;
        if (!root.displayedContext || root.viewState.mode !== "banner"
                || root.contextTransitionPlan.kind === "replace") {
            contextTransition.stop();
            root.displayedContext = root.pendingContext;
            contentStage.opacity = 1;
        } else {
            contextTransition.restart();
        }
        if (root.viewState.mode === "banner" && bannerHover.hovered)
            root.intentRequested(root.deadlineIntent("pause-timeout"));
    }

    function commitPendingContext(): void {
        root.displayedContext = root.pendingContext;
    }

    function finishTransition(): void {
        root.transitionFinished(root.transitionGeneration);
    }

    function beginPopupEntrance(generation: int): void {
        root.transitionGeneration = generation;
        root.popupClosing = false;
        popupExit.stop();
        if (Motion.reduced) {
            popupPanel.opacity = 1;
            popupPanel.scale = 1;
            popupEntranceOffset.y = 0;
            root.finishTransition();
            return;
        }
        popupEntrance.restart();
    }

    function beginPopupExit(generation: int): void {
        root.transitionGeneration = generation;
        root.popupClosing = true;
        popupEntrance.stop();
        if (Motion.reduced) {
            root.popupClosing = false;
            root.finishTransition();
            return;
        }
        popupExit.restart();
    }

    onContextChanged: root.replaceDisplayedContext(root.context)
    onViewStateChanged: {
        const nextMode = root.viewState.mode;
        const wasPopup = root.previousMode === "banner" || root.previousMode === "expanded";
        const isPopup = nextMode === "banner" || nextMode === "expanded";
        if (isPopup) {
            root.displayedPopupMode = nextMode;
            if (!wasPopup)
                root.beginPopupEntrance(root.viewState.generation);
            else if (root.previousMode !== nextMode) {
                root.transitionGeneration = root.viewState.generation;
                Qt.callLater(root.finishTransition);
            }
        } else if (wasPopup) {
            root.beginPopupExit(root.viewState.generation);
        }
        root.previousMode = nextMode;
        if (root.viewState.mode !== "banner")
            root.replaceDisplayedContext(root.context);
    }
    Component.onCompleted: {
        root.previousMode = root.viewState.mode;
        root.replaceDisplayedContext(root.context);
        if (root.popupMode) {
            root.displayedPopupMode = root.viewState.mode;
            root.beginPopupEntrance(root.viewState.generation);
        }
    }

    Shared.Surface {
        id: classicBody
        visible: !root.popupMode && !root.popupClosing
        anchors.top: parent.top
        anchors.topMargin: root.profile.compact.inset
        anchors.horizontalCenter: parent.horizontalCenter
        width: 220
        height: root.profile.compact.height
        radius: root.profile.compact.radius
        customColor: Theme.light ? "#ffffff" : "#000000"
        clipContent: true
    }

    Shared.Panel {
        id: popupPanel
        visible: root.popupMode || root.popupClosing
        anchors.top: parent.top
        anchors.topMargin: root.popupTop
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.popupGeometry.width
        height: root.popupGeometry.height
        radius: root.popupGeometry.radius
        customColor: Theme.surface
        clipContent: true
        transformOrigin: Item.Top
        opacity: Motion.reduced ? 1 : 0
        scale: Motion.reduced ? 1 : 0.94
        transform: Translate {
            id: popupEntranceOffset
            y: Motion.reduced ? 0 : -12
        }
    }

    Item {
        id: contentStage
        parent: root.popupMode || root.popupClosing
            ? popupPanel.contentItem : classicBody.contentItem
        anchors.fill: parent

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - 32)
            spacing: Metrics.spacingSmall

                Item {
                    id: activationArea
                    Layout.fillWidth: true
                    implicitHeight: headingColumn.implicitHeight

                    ColumnLayout {
                        id: headingColumn
                        anchors.fill: parent
                        spacing: Metrics.spacingSmall

                        RowLayout {
                            Layout.fillWidth: true
                            Shared.SystemIcon {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                sourceName: root.displayedContext?.icon || ""
                                fallbackName: root.displayedContext?.icon || "center_focus_strong"
                                size: 18
                            }
                            Shared.TextLabel {
                                Layout.fillWidth: true
                                text: root.displayedContext?.title
                                    || I18n.tr("menubar.center.title")
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                        Shared.TextLabel {
                            Layout.fillWidth: true
                            visible: root.viewState.mode !== "compact"
                                && (root.displayedContext?.subtitle || "").length > 0
                            text: root.displayedContext?.subtitle || ""
                            variant: "caption"
                            tone: "secondary"
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                RowLayout {
                    id: actionRow
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.viewState.mode !== "compact" && root.contextActions.length > 0
                    spacing: Metrics.spacingSmall
                    Repeater {
                        model: root.contextActions
                        Shared.Button {
                            required property var modelData
                            size: "small"
                            variant: modelData.role === "primary" ? "primary" : "quiet"
                            iconName: modelData.icon
                            accessibleName: modelData.label
                            enabled: modelData.enabled
                            onTriggered: root.intentRequested({ type: "invoke-action",
                                actionId: modelData.id, contextId: modelData.contextId })
                        }
                    }
                }
        }
    }
    TapHandler {
        parent: activationArea
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.intentRequested({ type: "request-mode",
            mode: root.viewState.mode === "expanded" ? "compact" : "expanded" })
    }
    HoverHandler {
        id: bannerHover
        enabled: root.viewState.mode === "banner"
        onHoveredChanged: {
            if (root.viewState.mode !== "banner")
                return;
            if (bannerHover.hovered)
                root.intentRequested(root.deadlineIntent("pause-timeout"));
            else
                root.intentRequested(root.deadlineIntent("resume-timeout"));
        }
    }

    CenterSecondaryPill {
        id: secondaryPill
        x: classicBody.x + classicBody.width + Metrics.spacingSmall
        y: classicBody.y
        width: implicitWidth
        height: root.profile.compact.height
        indicator: root.notificationIndicator
        rendererVisible: root.visible && root.viewState.mode === "compact"
            && !root.popupClosing
        backgroundColor: Theme.light ? "#ffffff" : "#000000"
        topLeftRadius: root.profile.compact.radius
        topRightRadius: root.profile.compact.radius
        bottomLeftRadius: root.profile.compact.radius
        bottomRightRadius: root.profile.compact.radius
    }

    SequentialAnimation {
        id: contextTransition
        NumberAnimation {
            target: contentStage
            property: "opacity"
            from: 1
            to: 0
            duration: root.contextTransitionPlan.exitMs
        }
        ScriptAction { script: root.commitPendingContext() }
        NumberAnimation {
            target: contentStage
            property: "opacity"
            from: 0
            to: 1
            duration: root.contextTransitionPlan.enterMs
        }
    }

    ParallelAnimation {
        id: popupEntrance
        NumberAnimation {
            target: popupPanel
            property: "opacity"
            from: root.openMotion.opacityFrom
            to: root.openMotion.opacityTo
            duration: root.openMotion.opacityMs
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: popupPanel
            property: "scale"
            from: root.openMotion.scaleFrom
            to: root.openMotion.scaleTo
            duration: root.openMotion.scaleMs
            easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
        }
        NumberAnimation {
            target: popupEntranceOffset
            property: "y"
            from: root.openMotion.yFrom
            to: root.openMotion.yTo
            duration: root.openMotion.yMs
            easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1]
        }
        onFinished: root.finishTransition()
    }

    ParallelAnimation {
        id: popupExit
        NumberAnimation {
            target: popupPanel
            property: "opacity"
            from: root.closeMotion.opacityFrom
            to: root.closeMotion.opacityTo
            duration: root.closeMotion.opacityMs
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: popupPanel
            property: "scale"
            from: root.closeMotion.scaleFrom
            to: root.closeMotion.scaleTo
            duration: root.closeMotion.scaleMs
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: popupEntranceOffset
            property: "y"
            from: root.closeMotion.yFrom
            to: root.closeMotion.yTo
            duration: root.closeMotion.yMs
            easing.type: Easing.InCubic
        }
        onFinished: {
            root.popupClosing = false;
            root.finishTransition();
        }
    }

    Connections {
        target: Motion
        function onReducedChanged(): void {
            if (Motion.reduced)
                root.replaceDisplayedContext(root.context);
        }
    }
}
