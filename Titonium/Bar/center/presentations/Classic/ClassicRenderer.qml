pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Bar.center
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "../../CenterPresentationRules.js" as PresentationRules
import "ClassicPopupTransitionRules.js" as PopupRules

FocusScope {
    id: root
    required property var snapshot
    required property var viewState
    required property var profile
    required property bool transitionOwner
    signal intentRequested(var intent)
    signal transitionFinished(int generation)
    readonly property var context: root.snapshot.contexts.find(
        item => item.id === root.viewState.selectedContextId) || root.snapshot.primary
    property var displayedContext: null
    property var pendingContext: null
    property var popupContext: null
    property var popupActions: []
    property var pendingPopupContext: null
    property var pendingPopupActions: []
    readonly property var notificationIndicator: root.snapshot.indicators.find(
        item => item.id === "notification:unread") || null
    readonly property var contextTransitionPlan:
        PresentationRules.contextTransition(root.profile, Motion.reduced)
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
    readonly property var requestedPopupGeometry: PresentationRules.classicPopupGeometry(
        root.profile, { width: root.width, height: root.height }, root.displayedPopupMode,
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
    readonly property rect primaryVisualBounds: root.popupPresented
        ? Qt.rect(root.paintedPopupBounds.x, root.paintedPopupBounds.y,
            root.paintedPopupBounds.width, root.paintedPopupBounds.height)
        : Qt.rect(classicBody.x, classicBody.y, classicBody.width, classicBody.height)
    readonly property var composedVisualBounds:
        PresentationRules.combinedVisualBounds(root.primaryVisualBounds,
            secondaryPill.visualBounds, secondaryPill.visible)
    readonly property rect visualBounds: Qt.rect(root.composedVisualBounds.x,
        root.composedVisualBounds.y, root.composedVisualBounds.width,
        root.composedVisualBounds.height)
    readonly property rect interactiveBounds: root.primaryVisualBounds

    function deadlineIntent(type: string): var {
        return { type: type, generation: root.viewState.generation,
            contextId: root.viewState.selectedContextId,
            deadline: root.viewState.deadlineToken };
    }
    function replaceDisplayedContext(nextContext: var): void {
        root.pendingContext = nextContext;
        if (!root.displayedContext || root.viewState.mode !== "banner"
                || root.contextTransitionPlan.kind === "replace") {
            contextTransition.stop();
            root.displayedContext = root.pendingContext;
            standardContent.opacity = 1;
        } else {
            contextTransition.restart();
        }
        if (root.viewState.mode === "banner" && bannerHover.hovered)
            root.intentRequested(root.deadlineIntent("pause-timeout"));
    }
    function commitPendingContext(): void { root.displayedContext = root.pendingContext; }
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
        else root.replaceDisplayedContext(root.context);
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
        if (root.viewState.mode !== "banner") root.replaceDisplayedContext(root.context);
    }
    Component.onCompleted: { root.replaceDisplayedContext(root.context); root.updatePopupTransition(); }

    Shared.Surface {
        id: classicBody
        visible: !root.popupPresented
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
        visible: root.popupPresented
        anchors.top: parent.top
        anchors.topMargin: root.popupTop
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.popupGeometry.width
        height: root.popupGeometry.height
        radius: root.requestedPopupGeometry.radius
        customColor: Theme.surface
        clipContent: true
        transformOrigin: Item.Top
        opacity: 1
        scale: 1
        transform: Translate { id: popupEntranceOffset; y: 0 }
    }

    Item {
        id: standardContent
        parent: root.displayedPopupMode === "expanded"
            ? popupPanel.contentItem : classicBody.contentItem
        anchors.fill: parent
        visible: !root.popupPresented || root.displayedPopupMode === "expanded"
        ColumnLayout {
            anchors.centerIn: parent
            width: root.popupPresented ? parent.width : Math.max(0, parent.width - 32)
            spacing: Metrics.spacingSmall
            Item {
                id: standardActivation
                Layout.fillWidth: true
                implicitHeight: standardHeading.implicitHeight
                ColumnLayout {
                    id: standardHeading
                    anchors.fill: parent
                    spacing: Metrics.spacingSmall
                    RowLayout {
                        Layout.fillWidth: true
                        Shared.SystemIcon {
                            Layout.preferredWidth: 18; Layout.preferredHeight: 18
                            sourceName: (root.popupPresented ? root.popupContext
                                : root.displayedContext)?.icon || ""
                            fallbackName: (root.popupPresented ? root.popupContext
                                : root.displayedContext)?.icon || "center_focus_strong"
                            size: 18
                        }
                        Shared.TextLabel {
                            Layout.fillWidth: true
                            text: (root.popupPresented ? root.popupContext
                                : root.displayedContext)?.title || I18n.tr("menubar.center.title")
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    Shared.TextLabel {
                        Layout.fillWidth: true
                        visible: root.popupPresented
                            && ((root.popupContext?.subtitle || "").length > 0)
                        text: root.popupContext?.subtitle || ""
                        variant: "caption"; tone: "secondary"
                        horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    }
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: root.popupPresented && root.popupActions.length > 0
                spacing: Metrics.spacingSmall
                Repeater {
                    model: root.popupActions
                    Shared.Button {
                        required property var modelData
                        size: "small"
                        variant: modelData.role === "primary" ? "primary" : "quiet"
                        iconName: modelData.icon; accessibleName: modelData.label
                        enabled: root.popupInteractive && modelData.enabled
                        onTriggered: root.intentRequested({ type: "invoke-action",
                            actionId: modelData.id, contextId: modelData.contextId })
                    }
                }
            }
        }
    }

    RowLayout {
        id: bannerContent
        parent: popupPanel.contentItem
        anchors.fill: parent
        visible: root.popupPresented && root.displayedPopupMode === "banner"
        spacing: Metrics.spacingSmall
        Shared.SystemIcon {
            Layout.preferredWidth: root.bannerLayout.iconSize
            Layout.preferredHeight: root.bannerLayout.iconSize
            sourceName: root.popupContext?.icon || ""
            fallbackName: root.popupContext?.icon || "center_focus_strong"
            size: root.bannerLayout.iconSize
        }
        Item {
            id: bannerActivation
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: root.popupContext?.title || I18n.tr("menubar.center.title")
                    elide: Text.ElideRight
                }
                Shared.TextLabel {
                    Layout.fillWidth: true
                    visible: (root.popupContext?.subtitle || "").length > 0
                    text: root.popupContext?.subtitle || ""
                    variant: "caption"; tone: "secondary"; elide: Text.ElideRight
                }
            }
        }
        Repeater {
            model: root.popupActions
            Shared.Button {
                required property var modelData
                Layout.preferredHeight: root.bannerLayout.actionHeight
                size: "small"
                variant: modelData.role === "primary" ? "primary" : "quiet"
                iconName: modelData.icon; accessibleName: modelData.label
                enabled: root.popupInteractive && modelData.enabled
                onTriggered: root.intentRequested({ type: "invoke-action",
                    actionId: modelData.id, contextId: modelData.contextId })
            }
        }
    }

    TapHandler {
        parent: standardActivation
        enabled: !root.popupClosing
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.intentRequested({ type: "request-mode",
            mode: root.viewState.mode === "expanded" ? "compact" : "expanded" })
    }
    TapHandler {
        parent: bannerActivation
        enabled: root.popupInteractive
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.intentRequested({ type: "request-mode", mode: "expanded" })
    }
    HoverHandler {
        id: bannerHover
        parent: popupPanel
        enabled: root.popupInteractive && root.viewState.mode === "banner"
        onHoveredChanged: {
            if (root.viewState.mode !== "banner") return;
            root.intentRequested(root.deadlineIntent(
                bannerHover.hovered ? "pause-timeout" : "resume-timeout"));
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
        NumberAnimation { target: standardContent; property: "opacity"; from: 1; to: 0;
            duration: root.contextTransitionPlan.exitMs }
        ScriptAction { script: root.commitPendingContext() }
        NumberAnimation { target: standardContent; property: "opacity"; from: 0; to: 1;
            duration: root.contextTransitionPlan.enterMs }
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
                root.replaceDisplayedContext(root.context);
            }
        }
    }
}
