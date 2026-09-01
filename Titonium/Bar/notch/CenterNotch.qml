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
    signal settingsRequested()

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.width: Metrics.borderWidth
        border.color: Theme.border
        topLeftRadius: 20
        topRightRadius: 20
        bottomLeftRadius: 20
        bottomRightRadius: 20
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingLarge
        spacing: Metrics.spacingMedium

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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.borderWidth
            color: Theme.border
        }

        CenterNotchRail {
            id: rail
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            currentPage: viewport.currentPage
            onPageRequested: pageId => {
                root.feedbackKey = "";
                CenterNotchCoordinator.requestPage(pageId);
            }
            onSettingsRequested: root.settingsRequested()
        }
    }
}
