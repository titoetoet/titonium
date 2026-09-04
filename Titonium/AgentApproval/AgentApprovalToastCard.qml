pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.AgentApproval
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root
    readonly property var approval: AgentApprovalService.current
    width: 380
    implicitHeight: mainLayout.implicitHeight + Metrics.spacingMedium * 2
    opacity: Motion.reduced ? 1 : 0

    transform: Translate {
        id: toastSlide
        x: Motion.reduced ? 0 : 36
    }

    ParallelAnimation {
        id: toastEntrance
        running: !Motion.reduced

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: toastSlide
            property: "x"
            from: 36
            to: 0
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
    }

    Shared.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusLarge
        outlined: true
        borderColor: Theme.borderStrong
    }

    function fileBasename(path: string): string {
        if (!path)
            return "";
        const parts = String(path).split("/");
        return parts[parts.length - 1] || path;
    }

    function fileDirectory(path: string): string {
        if (!path)
            return "";
        const parts = String(path).split("/");
        if (parts.length <= 1)
            return "";
        return parts.slice(0, parts.length - 1).join("/");
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Metrics.spacingMedium
        spacing: Metrics.spacingSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSmall

            Shared.Icon {
                name: "edit_note"
                size: 20
                color: Theme.accent
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                text: {
                    const title = root.approval?.title || "Antigravity";
                    const kind = I18n.tr("agent_approval.kind.edit_file", "Sửa tệp");
                    return title + " · " + kind;
                }
                variant: "caption"
                tone: "secondary"
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Shared.TextLabel {
                visible: AgentApprovalService.pending.length > 1
                text: "(1/" + AgentApprovalService.pending.length + ")"
                variant: "caption"
                tone: "secondary"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Shared.TextLabel {
                Layout.fillWidth: true
                text: root.fileBasename(root.approval?.targetFile || root.approval?.command || "")
                variant: "label"
                strong: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.fileDirectory(root.approval?.targetFile || root.approval?.command || "")
                variant: "caption"
                tone: "secondary"
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.approval?.detail || root.approval?.summary || ""
                variant: "caption"
                tone: "primary"
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSmall

            Item { Layout.fillWidth: true }

            Shared.Button {
                label: I18n.tr("agent_approval.deny", "Từ chối")
                size: "small"
                variant: "quiet"
                onTriggered: {
                    if (root.approval)
                        AgentApprovalService.decide(root.approval.requestId, "deny");
                }
            }

            Shared.Button {
                label: I18n.tr("agent_approval.allow_session", "Phiên này")
                size: "small"
                variant: "secondary"
                onTriggered: {
                    if (root.approval)
                        AgentApprovalService.decide(root.approval.requestId, "allow_session");
                }
            }

            Shared.Button {
                label: I18n.tr("agent_approval.allow_once", "Chấp nhận")
                size: "small"
                variant: "primary"
                onTriggered: {
                    if (root.approval)
                        AgentApprovalService.decide(root.approval.requestId, "allow_once");
                }
            }
        }
    }
}
