pragma ComponentBehavior: Bound
// Protected Spotlight vertical slice.

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Theme
import qs.Titonium.Core.Runtime
import "SpotlightLayout.js" as SpotlightLayout

FocusScope {
    id: root

    property var spotlightModel: null
    signal activatedSuccessfully()

    readonly property int columns: SpotlightLayout.columnCount()
    readonly property int rows: SpotlightLayout.rowCount()
    readonly property int gap: Metrics.spacingSmall
    readonly property var spotlightSettings: Preferences.spotlight
    readonly property int transitionDuration: Preferences.reducedMotion
        || root.spotlightSettings.pageTransition === "none" ? 0 : (root.spotlightSettings.transitionDuration || 220)

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingSmall

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: pageView
                anchors.fill: parent
                orientation: ListView.Horizontal
                model: root.spotlightModel?.pages || []
                currentIndex: root.spotlightModel?.pageIndex || 0
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
                    opacity: root.spotlightSettings.pageTransition === "slide-fade"
                        ? (ListView.isCurrentItem ? 1.0 : 0.18) : 1.0
                    scale: root.spotlightSettings.pageTransition === "slide-scale"
                        ? (ListView.isCurrentItem ? 1.0 : 0.94) : 1.0

                    Behavior on opacity {
                        NumberAnimation { duration: root.transitionDuration; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: root.transitionDuration; easing.type: Easing.OutCubic }
                    }

                    Grid {
                        anchors.fill: parent
                        columns: root.columns
                        rowSpacing: root.gap
                        columnSpacing: root.gap

                        Repeater {
                            model: appPage.modelData

                            ApplicationTile {
                                required property int index
                                required property var modelData
                                width: Math.floor((appPage.width - root.gap * (root.columns - 1)) / root.columns)
                                height: Math.floor((appPage.height - root.gap * (root.rows - 1)) / root.rows)
                                application: modelData
                                onTriggered: {
                                    if (root.spotlightModel.activateApplication(modelData.id))
                                        root.activatedSuccessfully();
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
                    if (delta < 0)
                        root.spotlightModel.setPage(root.spotlightModel.pageIndex + 1);
                    else if (delta > 0)
                        root.spotlightModel.setPage(root.spotlightModel.pageIndex - 1);
                    else
                        return;
                    wheel.accepted = true;
                }
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            visible: (root.spotlightModel?.pages.length || 0) > 1
            spacing: SpotlightLayout.indicatorSpacing()

            Repeater {
                model: root.spotlightModel?.pages || []

                PageIndicator {
                    required property int index
                    required property var modelData
                    pageIndex: index
                    page: modelData
                    current: index === (root.spotlightModel?.pageIndex || 0)
                    onTriggered: root.spotlightModel.setPage(index)
                }
            }
        }
    }
}
