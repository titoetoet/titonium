pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

FocusScope {
    id: root
    property string pageId: "overview"
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
