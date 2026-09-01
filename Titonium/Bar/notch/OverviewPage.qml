pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root
    property string pageId: "overview"
    signal feedbackRequested(string key)
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        OverviewWeatherHero {
            Layout.fillWidth: true
            Layout.preferredHeight: 82
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 180
            spacing: 10
            OverviewFocusCard { Layout.fillWidth: true; Layout.fillHeight: true }
            OverviewMediaCard { Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }
}
