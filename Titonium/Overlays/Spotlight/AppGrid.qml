pragma ComponentBehavior: Bound
// Protected Spotlight vertical slice.

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Theme
import qs.Titonium.Core.Runtime
import "SpotlightLayout.js" as SpotlightLayout
import "SpotlightWheelPaging.js" as SpotlightWheelPaging

FocusScope {
    id: root

    property var spotlightModel: null
    signal activatedSuccessfully()

    readonly property int columns: SpotlightLayout.columnCount()
    readonly property int rows: SpotlightLayout.rowCount()
    readonly property int gap: Metrics.spacingSmall
    readonly property var spotlightSettings: Preferences.spotlight
    readonly property int transitionDuration: Preferences.reducedMotion
        || root.spotlightSettings.pageTransition === "none" ? 0
            : (root.spotlightSettings.transitionDuration ?? 220)
    property real wheelAccumulator: 0
    property double lastWheelConsumedAt: 0

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
                highlightMoveDuration: root.spotlightSettings.pageTransition === "fade" ? 0
                    : root.transitionDuration
                clip: true

                delegate: Item {
                    id: appPage
                    required property var modelData
                    width: pageView.width
                    height: pageView.height
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
                    const angle = wheel.angleDelta.y !== 0
                        ? wheel.angleDelta.y : wheel.angleDelta.x;
                    const pixel = wheel.pixelDelta.y !== 0
                        ? wheel.pixelDelta.y : wheel.pixelDelta.x;
                    const delta = angle !== 0 ? angle : pixel;
                    if (delta === 0)
                        return;
                    const result = SpotlightWheelPaging.update(delta, Date.now(),
                        root.spotlightModel.pageIndex, root.spotlightModel.pages.length,
                        root.lastWheelConsumedAt, root.wheelAccumulator);
                    root.wheelAccumulator = result.accumulator;
                    root.lastWheelConsumedAt = result.lastConsumedAt;
                    if (result.consumed)
                        root.spotlightModel.setPage(result.page);
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
