pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    required property var screen

    readonly property var eventPresentation: CenterAttentionService.presentation
    readonly property var indicators: CenterAttentionService.indicators
    readonly property string primaryText: root.eventPresentation
        ? root.eventPresentation.title
        : (CenterFocusStore.text || I18n.tr("menubar.center.focus_fallback"))
    readonly property string textTone: !root.eventPresentation
        ? "secondary"
        : (root.eventPresentation.priority >= 70 ? "danger" : "primary")

    implicitWidth: Math.min(480, contentRow.implicitWidth + Metrics.spacingLarge * 2)
    implicitHeight: Metrics.controlHeight
    activeFocusOnTab: true

    function activate(): void {
        CenterFocusStore.openScratchpad();
    }

    Shared.Surface {
        anchors.fill: parent
        tone: centerHover.hovered ? "interactive" : "elevated"
        radius: Metrics.radiusLarge
        outlined: false
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingLarge
        anchors.rightMargin: Metrics.spacingLarge
        spacing: Metrics.spacingSmall

        Repeater {
            model: root.indicators

            delegate: Shared.Icon {
                required property var modelData

                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                name: modelData.icon
                size: 18
                tone: "secondary"
                accessibleName: modelData.accessibleName
            }
        }

        Shared.TextLabel {
            id: primaryLabel
            Layout.maximumWidth: 320
            text: root.primaryText
            variant: "label"
            tone: root.textTone
            strong: root.eventPresentation !== null
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }
    }

    HoverHandler {
        id: centerHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            CenterFocusStore.openScratchpad();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter) {
            root.activate();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr("menubar.center.accessible") + ": " + root.primaryText
    Accessible.focusable: true
}
