pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
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
    readonly property var contextTransitionPlan:
        PresentationRules.contextTransition(root.profile, Motion.reduced)
    readonly property real shoulderSize: 18
    readonly property real visualWidth: root.viewState.mode === "expanded"
        ? Math.min(720, parent.width - 40)
        : (root.viewState.mode === "banner" ? Math.min(480, parent.width - 24) : 220)
    readonly property real bodyWidth: Math.max(1, root.visualWidth - root.shoulderSize * 2)
    readonly property real bodyHeight: root.viewState.mode === "expanded" ? 440
        : (root.viewState.mode === "banner" ? 72 : root.profile.compact.height)
    readonly property real bodyRadius: root.viewState.mode === "expanded"
        ? root.profile.expanded.radius : (root.viewState.mode === "banner"
        ? root.profile.banner.radius : root.profile.compact.radius)
    readonly property rect visualBounds: Qt.rect(shape.x, shape.y, shape.width, shape.height)
    readonly property rect interactiveBounds: root.visualBounds

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

    onContextChanged: root.replaceDisplayedContext(root.context)
    onViewStateChanged: {
        if (root.viewState.mode !== "banner")
            root.replaceDisplayedContext(root.context);
    }
    Component.onCompleted: root.replaceDisplayedContext(root.context)

    Shared.ConnectedPillShape {
        id: shape
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        bodyWidth: root.bodyWidth
        bodyHeight: root.bodyHeight
        shoulderSize: root.shoulderSize
        bottomRadius: root.bodyRadius
        color: Theme.light ? "#ffffff" : "#000000"

        Item {
            id: contentStage
            x: shape.bodyLeft
            width: shape.bodyWidth
            height: shape.bodyHeight

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
                            Shared.Icon {
                                name: root.displayedContext?.icon || "center_focus_strong"
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
        Behavior on bodyWidth { NumberAnimation { duration: Motion.reduced ? 0 : 240 } }
        Behavior on bodyHeight {
            NumberAnimation {
                duration: Motion.reduced ? 0 : 240
                onFinished: root.transitionFinished(root.viewState.generation)
            }
        }
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

    Connections {
        target: Motion
        function onReducedChanged(): void {
            if (Motion.reduced)
                root.replaceDisplayedContext(root.context);
        }
    }
}
