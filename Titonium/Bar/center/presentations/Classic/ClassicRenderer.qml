pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Bar.center
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "../../CenterPresentationRules.js" as PresentationRules
import "../../MusicPlayerRules.js" as MusicRules
import "ClassicPopupTransitionRules.js" as PopupRules

FocusScope {
    id: root
    required property var snapshot
    required property var viewState
    required property var profile
    required property bool presentationActive
    required property bool transitionOwner
    signal intentRequested(var intent)
    signal transitionFinished(int generation)
    readonly property var context: root.viewState.previewContext || root.snapshot.contexts.find(
        item => item.id === root.viewState.selectedContextId) || null
    property var popupContext: null
    property var popupActions: []
    property var pendingPopupContext: null
    property var pendingPopupActions: []
    readonly property bool popupMode: root.viewState.mode === "banner"
        || root.viewState.mode === "expanded"
    readonly property bool popupClosing: root.transitionState.phase === "closing"
    readonly property bool transitionActive: root.transitionOwner
        && (root.transitionState.phase === "opening" || root.popupClosing)
    readonly property bool popupPresented: root.popupMode || root.popupClosing
    readonly property bool popupInteractive: root.popupMode && !root.popupClosing
    readonly property real popupTop: Metrics.barHeight + Metrics.barSpacing
    property var transitionState: PopupRules.initialState()
    property int animationToken: 0
    property real animationOpacityFrom: 1
    property real animationOpacityTo: 1
    property real animationScaleFrom: 1
    property real animationScaleTo: 1
    property real animationYFrom: 0
    property real animationYTo: 0
    property int animationOpacityDuration: 0
    property int animationScaleDuration: 0
    property int animationYDuration: 0
    readonly property string displayedPopupMode: root.transitionState.presentedMode
        || (root.popupMode ? root.viewState.mode : "banner")
    readonly property var requestedPopupGeometry: root.displayedPopupMode === "expanded"
        ? ({width: Math.max(1, Math.min(720, root.width - 40)), height: Math.max(1, Math.min(500, root.height - root.popupTop - 16)), radius: root.profile.expanded.radius})
        : PresentationRules.classicPopupGeometry(root.profile,
            { width: root.width, height: root.height }, root.displayedPopupMode,
            Metrics.barHeight, Metrics.barSpacing)
    readonly property var popupGeometry: PopupRules.popupGeometry(
        { width: root.requestedPopupGeometry.width,
            height: root.requestedPopupGeometry.height },
        { width: root.width, height: root.height }, root.popupTop)
    readonly property var bannerLayout: PopupRules.bannerLayout(
        popupPanel.width, popupPanel.height, popupPanel.padding)
    readonly property var paintedPopupBounds: PopupRules.transformedBounds({
        x: popupPanel.x, y: popupPanel.y, width: popupPanel.width, height: popupPanel.height,
    }, popupPanel.scale, popupEntranceOffset.y)
    readonly property rect compactPrimaryBounds: Qt.rect(
        classicBody.x, classicBody.y, classicBody.width, classicBody.height)
    readonly property var composedCompactBounds:
        PresentationRules.normalizedBounds(root.compactPrimaryBounds)
    readonly property rect popupVisualBounds: Qt.rect(
        root.paintedPopupBounds.x, root.paintedPopupBounds.y,
        root.paintedPopupBounds.width, root.paintedPopupBounds.height)
    readonly property var composedVisualBounds: root.popupPresented
        ? PresentationRules.combinedVisualBounds(root.composedCompactBounds,
            root.popupVisualBounds, true) : root.composedCompactBounds
    readonly property rect visualBounds: Qt.rect(root.composedVisualBounds.x,
        root.composedVisualBounds.y, root.composedVisualBounds.width,
        root.composedVisualBounds.height)
    readonly property rect interactiveBounds: Qt.rect(root.composedCompactBounds.x,
        root.composedCompactBounds.y, root.composedCompactBounds.width,
        root.composedCompactBounds.height)

    function deadlineIntent(type: string): var {
        return { type: type, generation: root.viewState.generation,
            contextId: root.viewState.selectedContextId,
            deadline: root.viewState.deadlineToken };
    }
    function commitPendingPopupContext(): void {
        root.popupContext = root.pendingPopupContext;
        root.popupActions = root.pendingPopupActions;
    }
    function updatePopupContext(): void {
        if (!root.popupMode)
            return;
        const nextContext = root.context;
        const nextActions = root.snapshot.capabilities.actions.filter(
            item => nextContext && item.contextId === nextContext.id);
        const plan = PopupRules.bannerContextReplacement(
            root.popupContext?.id || "", nextContext?.id || "", Motion.reduced);
        root.pendingPopupContext = nextContext;
        root.pendingPopupActions = nextActions;
        if (root.viewState.mode === "banner" && plan.kind === "crossfade") {
            bannerContextTransition.stop();
            bannerContextTransition.restart();
        } else if (plan.kind !== "unchanged" || root.viewState.mode === "expanded") {
            bannerContextTransition.stop();
            root.commitPendingPopupContext();
            bannerContent.opacity = 1;
        } else {
            root.popupContext = nextContext;
            root.popupActions = nextActions;
        }
    }
    function stopPopupAnimations(): void { popupEntrance.stop(); popupExit.stop(); }
    function completeToken(token: int): void {
        const result = PopupRules.complete(root.transitionState, token);
        root.transitionState = result.state;
        root.applyEffects(result.effects);
    }
    function applyEffects(effects: var): void {
        for (const effect of effects) {
            if (effect.type === "cancel-animation") {
                root.stopPopupAnimations();
            } else if (effect.type === "animate") {
                root.animationToken = effect.token;
                root.animationOpacityFrom = effect.from.opacity;
                root.animationOpacityTo = effect.to.opacity;
                root.animationScaleFrom = effect.from.scale;
                root.animationScaleTo = effect.to.scale;
                root.animationYFrom = effect.from.y;
                root.animationYTo = effect.to.y;
                root.animationOpacityDuration = effect.duration.opacity;
                root.animationScaleDuration = effect.duration.scale;
                root.animationYDuration = effect.duration.y;
                if (effect.phase === "opening") popupEntrance.restart();
                else popupExit.restart();
            } else if (effect.type === "complete") {
                const token = effect.token;
                Qt.callLater(() => root.completeToken(token));
            } else if (effect.type === "normalize") {
                popupPanel.opacity = effect.opacity;
                popupPanel.scale = effect.scale;
                popupEntranceOffset.y = effect.y;
            } else if (effect.type === "emit-completion" && root.transitionOwner) {
                root.transitionFinished(effect.generation);
            }
        }
    }
    function updatePopupTransition(): void {
        root.updatePopupContext();
        const result = PopupRules.transition(root.transitionState, {
            mode: root.viewState.mode, generation: root.viewState.generation,
            transitionOwner: root.transitionOwner, reducedMotion: Motion.reduced,
            contextId: root.context?.id || "",
            visual: { opacity: popupPanel.opacity, scale: popupPanel.scale,
                y: popupEntranceOffset.y },
        });
        root.transitionState = result.state;
        root.applyEffects(result.effects);
    }

    onContextChanged: {
        if (root.popupMode) root.updatePopupContext();
    }
    onTransitionOwnerChanged: {
        if (!root.transitionOwner) {
            root.stopPopupAnimations();
            bannerContextTransition.stop();
            root.transitionState = PopupRules.initialState();
            popupPanel.opacity = 1;
            popupPanel.scale = 1;
            popupEntranceOffset.y = 0;
        } else
            root.updatePopupTransition();
    }
    onViewStateChanged: {
        root.updatePopupTransition();
    }
    Component.onCompleted: root.updatePopupTransition()

    CenterCompactCapsule {
        id: classicBody
        visible: root.presentationActive
        y: 4
        anchors.horizontalCenter: parent.horizontalCenter
        snapshot: root.snapshot
        monitorWidth: root.width
        interactionEnabled: root.presentationActive
        onIntentRequested: intent => root.intentRequested(intent)
    }
    Shared.Panel {
        id: popupPanel
        visible: root.presentationActive && root.popupPresented
        anchors.top: parent.top
        anchors.topMargin: root.popupTop
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.popupGeometry.width
        height: root.popupGeometry.height
        radius: root.requestedPopupGeometry.radius
        customColor: Theme.surface
        padding: 0
        clipContent: true
        transformOrigin: Item.Top
        opacity: 1
        scale: 1
        transform: Translate { id: popupEntranceOffset; y: 0 }
    }

    Loader {
        objectName: "classicExpandedContent"
        parent: popupPanel.contentItem
        anchors.fill: parent
        active: root.visible && root.popupPresented && root.displayedPopupMode === "expanded"
        sourceComponent: Component {
            ExpandedContent {
                snapshot: root.snapshot
                viewState: root.viewState
                enabled: root.popupInteractive
                onIntentRequested: intent => root.intentRequested(intent)
            }
        }
    }
    NormalBannerContent {
        id: bannerContent
        parent: popupPanel.contentItem
        anchors.fill: parent
        visible: root.popupPresented && root.displayedPopupMode === "banner"
        enabled: root.popupInteractive && visible
        context: root.popupContext
        onIntentRequested: intent => root.intentRequested(intent)
    }

    SequentialAnimation {
        id: bannerContextTransition
        NumberAnimation { target: bannerContent; property: "opacity"; from: 1; to: 0;
            duration: 80 }
        ScriptAction { script: root.commitPendingPopupContext() }
        NumberAnimation { target: bannerContent; property: "opacity"; from: 0; to: 1;
            duration: 120 }
    }
    ParallelAnimation {
        id: popupEntrance
        NumberAnimation { target: popupPanel; property: "opacity";
            from: root.animationOpacityFrom; to: root.animationOpacityTo;
            duration: root.animationOpacityDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: popupPanel; property: "scale";
            from: root.animationScaleFrom; to: root.animationScaleTo;
            duration: root.animationScaleDuration;
            easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] }
        NumberAnimation { target: popupEntranceOffset; property: "y";
            from: root.animationYFrom; to: root.animationYTo;
            duration: root.animationYDuration;
            easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }
        onFinished: root.completeToken(root.animationToken)
    }
    ParallelAnimation {
        id: popupExit
        NumberAnimation { target: popupPanel; property: "opacity";
            from: root.animationOpacityFrom; to: root.animationOpacityTo;
            duration: root.animationOpacityDuration; easing.type: Easing.InCubic }
        NumberAnimation { target: popupPanel; property: "scale";
            from: root.animationScaleFrom; to: root.animationScaleTo;
            duration: root.animationScaleDuration; easing.type: Easing.InCubic }
        NumberAnimation { target: popupEntranceOffset; property: "y";
            from: root.animationYFrom; to: root.animationYTo;
            duration: root.animationYDuration; easing.type: Easing.InCubic }
        onFinished: root.completeToken(root.animationToken)
    }
    Connections {
        target: Motion
        function onReducedChanged(): void {
            const result = PopupRules.setReducedMotion(root.transitionState, Motion.reduced);
            root.transitionState = result.state;
            root.applyEffects(result.effects);
            if (Motion.reduced) {
                bannerContextTransition.stop();
                root.commitPendingPopupContext();
                bannerContent.opacity = 1;
            }
        }
    }
}
