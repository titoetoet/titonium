pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

FocusScope {
    id: root
    focus: true
    property string feedbackKey: ""

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.width: Metrics.borderWidth
        border.color: Theme.border
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 20
        bottomRightRadius: 20
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingLarge
        spacing: Metrics.spacingMedium

        CenterNotchRail {
            id: rail
            Layout.preferredWidth: 48
            Layout.fillHeight: true
            currentPage: viewport.currentPage
            onPageRequested: pageId => {
                root.feedbackKey = "";
                CenterNotchCoordinator.requestPage(pageId);
            }
            onSettingsRequested: root.feedbackKey = "center_notch.settings.unavailable"
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: Metrics.borderWidth
            color: Theme.border
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Metrics.spacingSmall

            CenterNotchViewport {
                id: viewport
                Layout.fillWidth: true
                Layout.fillHeight: true
                requestedPage: CenterNotchCoordinator.requestedPage
                onFeedbackRequested: key => root.feedbackKey = key
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                visible: root.feedbackKey.length > 0
                Layout.preferredHeight: visible ? 24 : 0
                text: visible ? I18n.tr(root.feedbackKey) : ""
                tone: "secondary"
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
