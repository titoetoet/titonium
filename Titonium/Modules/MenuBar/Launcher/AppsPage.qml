pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation
import "LauncherLayout.js" as LauncherLayout

FocusScope {
    id: root

    signal applicationLaunched()

    readonly property var launcherSettings: ConfigStore.previewState.modules?.launcher || ({})
    readonly property int gap: Metrics.spacingSmall
    readonly property int columns: LauncherLayout.columnCount()
    readonly property int rows: LauncherLayout.rowCount()
    readonly property int capacity: LauncherLayout.pageSize()
    readonly property int transitionDuration: ConfigStore.previewState.accessibility?.reducedMotion === true
        || root.launcherSettings.pageTransition === "none" ? 0 : (root.launcherSettings.transitionDuration || 220)

    ApplicationCatalogModel {
        id: catalog
        pageCapacity: root.capacity
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingLarge
        spacing: Metrics.spacingSmall

        Controls.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("launcher.title")
            variant: "title_large"
            strong: true
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Metrics.borderWidth
            color: Theme.border
            opacity: 0.55
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: pageView
                anchors.fill: parent
                orientation: ListView.Horizontal
                model: catalog.pages
                currentIndex: 0
                snapMode: ListView.SnapOneItem
                boundsBehavior: Flickable.StopAtBounds
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: width
                highlightMoveDuration: root.transitionDuration
                clip: true

                delegate: Item {
                    id: appPage
                    required property var modelData
                    width: pageView.width
                    height: pageView.height
                    opacity: root.launcherSettings.pageTransition === "slide-fade"
                        ? (ListView.isCurrentItem ? 1.0 : 0.18) : 1.0
                    scale: root.launcherSettings.pageTransition === "slide-scale"
                        ? (ListView.isCurrentItem ? 1.0 : 0.94) : 1.0

                    Behavior on opacity { NumberAnimation { duration: root.transitionDuration; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: root.transitionDuration; easing.type: Easing.OutCubic } }

                    Grid {
                        anchors.fill: parent
                        columns: root.columns
                        rowSpacing: root.gap
                        columnSpacing: root.gap

                        Repeater {
                            model: appPage.modelData

                            ApplicationTile {
                                required property var modelData
                                width: Math.floor((appPage.width - root.gap * (root.columns - 1)) / root.columns)
                                height: Math.floor((appPage.height - root.gap * (root.rows - 1)) / root.rows)
                                application: modelData
                                onTriggered: {
                                    if (catalog.launch(modelData))
                                        root.applicationLaunched();
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                propagateComposedEvents: true
                onWheel: wheel => {
                    const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                    if (delta < 0 && pageView.currentIndex < catalog.pages.length - 1)
                        pageView.currentIndex++;
                    else if (delta > 0 && pageView.currentIndex > 0)
                        pageView.currentIndex--;
                    else
                        return;
                    wheel.accepted = true;
                }
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            visible: catalog.pages.length > 1
            spacing: Metrics.spacingSmall

            Repeater {
                model: catalog.pages

                PageIndicator {
                    required property int index
                    required property var modelData
                    pageIndex: index
                    fillRatio: LauncherLayout.fillRatio(modelData, catalog.pageCapacity)
                    current: index === pageView.currentIndex
                    onTriggered: pageView.currentIndex = index
                }
            }
        }
    }

}
