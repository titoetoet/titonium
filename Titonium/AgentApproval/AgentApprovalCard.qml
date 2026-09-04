pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.AgentApproval
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root
    focus: true
    readonly property var approval: AgentApprovalService.current
    opacity: Motion.reduced ? 1 : 0
    scale: Motion.reduced ? 1 : 0.97
    transform: Translate {
        id: cardOffset
        y: Motion.reduced ? 0 : -8
    }

    ParallelAnimation {
        id: cardEntrance
        running: !Motion.reduced

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: 140
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
        NumberAnimation {
            target: root
            property: "scale"
            from: 0.97
            to: 1
            duration: 180
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
        NumberAnimation {
            target: cardOffset
            property: "y"
            from: -8
            to: 0
            duration: 180
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Theme.surface
        border.width: Metrics.borderWidth
        border.color: Theme.borderStrong
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingLarge
        spacing: Metrics.spacingMedium

        RowLayout {
            Layout.fillWidth: true
            Shared.Icon {
                name: (root.approval?.kind === "write_to_file" || root.approval?.kind === "replace_file_content" || root.approval?.kind === "multi_replace_file_content")
                    ? "edit_note" : ((root.approval?.kind === "run_command" || root.approval?.kind === "run_shell_command") ? "terminal" : "smart_toy")
                size: 22
                color: Theme.warning
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                text: {
                    const title = root.approval ? root.approval.title : "";
                    let kindLabel = "";
                    if (root.approval?.kind) {
                        const kind = root.approval.kind;
                        if (kind === "run_command" || kind === "run_shell_command")
                            kindLabel = I18n.tr("agent_approval.kind.run_command");
                        else if (kind === "write_to_file")
                            kindLabel = I18n.tr("agent_approval.kind.write_to_file");
                        else if (kind === "replace_file_content" || kind === "multi_replace_file_content")
                            kindLabel = I18n.tr("agent_approval.kind.edit_file");
                        else
                            kindLabel = kind;
                    }
                    return kindLabel ? (title + " · " + kindLabel) : title;
                }
                variant: "title"
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }
            Shared.TextLabel {
                Layout.maximumWidth: 220
                text: {
                    const label = root.approval?.summary || I18n.tr("agent_approval.needs_approval");
                    return AgentApprovalService.pending.length > 1
                        ? label + " (1/" + AgentApprovalService.pending.length + ")"
                        : label;
                }
                color: Theme.warning
                variant: "label"
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            text: {
                if (root.approval?.detail && root.approval?.cwd)
                    return root.approval.detail + " (" + root.approval.cwd + ")";
                if (root.approval?.detail)
                    return root.approval.detail;
                if (root.approval?.cwd)
                    return root.approval.cwd;
                return I18n.tr("agent_approval.command");
            }
            tone: "secondary"
            elide: Text.ElideMiddle
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Metrics.radiusSmall
            color: Theme.background
            border.width: Metrics.borderWidth
            border.color: Theme.border
            Shared.TextLabel {
                anchors.fill: parent
                anchors.margins: Metrics.spacingMedium
                text: root.approval?.command || root.approval?.reason || ""
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                maximumLineCount: 7
                verticalAlignment: Text.AlignTop
                font.family: "monospace"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSmall
            Item { Layout.fillWidth: true }
            Shared.Button {
                label: I18n.tr("agent_approval.deny")
                variant: "danger"
                onTriggered: AgentApprovalService.decide(root.approval.requestId, "deny")
            }
            Shared.Button {
                label: root.approval?.source === "chatgpt"
                    ? I18n.tr("agent_approval.review_in_chatgpt")
                    : I18n.tr("agent_approval.ask_in_agent")
                visible: root.approval?.source === "antigravity" || root.approval?.source === "chatgpt"
                onTriggered: AgentApprovalService.decide(root.approval.requestId, "ask")
            }
            Shared.Button {
                label: I18n.tr("agent_approval.allow_session")
                onTriggered: AgentApprovalService.decide(root.approval.requestId, "allow_session")
            }
            Shared.Button {
                label: I18n.tr("agent_approval.allow_once")
                variant: "primary"
                onTriggered: AgentApprovalService.decide(root.approval.requestId, "allow_once")
            }
        }
    }

    Keys.onEscapePressed: {
        if (root.approval)
            AgentApprovalService.decide(root.approval.requestId, "ask");
    }
    Keys.onReturnPressed: {
        if (root.approval)
            AgentApprovalService.decide(root.approval.requestId, "allow_once");
    }
}
