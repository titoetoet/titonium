pragma ComponentBehavior: Bound
// Protected Spotlight vertical slice.

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import qs.Titonium.Theme
import qs.Titonium.Shared as Controls
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import "SpotlightGeometry.js" as SpotlightGeometry
import "SpotlightHeader.js" as SpotlightHeader
import "SpotlightLayout.js" as SpotlightLayout
import "SpotlightTransition.js" as SpotlightTransition
import "SpotlightVisual.js" as SpotlightVisual

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    property string loadedBodyMode: ""
    property int activeBodyTransitionDuration: 0
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property var spotlightSettings: Preferences.spotlight
    readonly property var scopeActions: SpotlightHeader.scopeActions()
    signal clipboardMoveRequested(int delta)
    signal clipboardActivateRequested()

    anchors.fill: parent
    focus: true

    property bool closing: false

    function close(): void {
        if (Motion.reduced) {
            SurfaceManager.close(root.ownerId);
            return;
        }
        if (root.closing)
            return;
        root.closing = true;
        panelExit.restart();
    }

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    function handleEscape(): void {
        if (spotlightModel.handleEscape())
            root.close();
    }

    function publishState(): void {
        if (!root.descriptor || SurfaceManager.ownerId !== root.ownerId)
            return;
        if (root.descriptor?.stateMode === spotlightModel.mode
                && root.descriptor?.query === spotlightModel.query
                && root.descriptor?.selectedIndex === spotlightModel.selectedIndex)
            return;
        SurfaceManager.open(root.ownerId, {
            "source": root.descriptor.source,
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": root.ownerId,
            "mode": spotlightModel.scope,
            "query": spotlightModel.query,
            "stateMode": spotlightModel.mode,
            "selectedIndex": spotlightModel.selectedIndex
        }, root.screen);
    }

    function configureLoadedBody(item: var): void {
        if (!item)
            return;
        root.bodyTransition.stop();
        const nextMode = spotlightModel.mode;
        const transitionPlan = SpotlightTransition.plan(
            root.loadedBodyMode,
            nextMode,
            Preferences.reducedMotion,
            root.spotlightSettings.pageTransition || "slide-fade",
            root.spotlightSettings.transitionDuration ?? 220
        );
        root.loadedBodyMode = nextMode;
        root.activeBodyTransitionDuration = transitionPlan.duration;
        item.opacity = transitionPlan.startOpacity;
        item.y = transitionPlan.startOffset;
        if ("spotlightModel" in item)
            item.spotlightModel = spotlightModel;
        if ("spotlightSurface" in item)
            item.spotlightSurface = root;
        if (transitionPlan.animated) {
            Qt.callLater(() => {
                if (bodyLoader.item === item)
                    root.bodyTransition.restart();
            });
        }
    }

    property ParallelAnimation bodyTransition: ParallelAnimation {
        NumberAnimation {
            target: bodyLoader.item
            property: "opacity"
            to: 1
            duration: root.activeBodyTransitionDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: bodyLoader.item
            property: "y"
            to: 0
            duration: root.activeBodyTransitionDuration
            easing.type: Easing.OutCubic
        }
    }

    onDescriptorChanged: {
        const descriptorMode = root.descriptor?.mode || "applications";
        if (descriptorMode !== spotlightModel.scope)
            spotlightModel.open(descriptorMode);
        const descriptorQuery = root.descriptor?.query || "";
        if (descriptorQuery !== spotlightModel.query)
            spotlightModel.setQuery(descriptorQuery);
    }

    SpotlightModel { id: spotlightModel }

    Connections {
        target: spotlightModel
        function onModeChanged(): void { Qt.callLater(root.publishState); }
        function onQueryChanged(): void { Qt.callLater(root.publishState); }
        function onSelectedIndexChanged(): void { Qt.callLater(root.publishState); }
    }

    Rectangle {
        id: backdropScrim
        anchors.fill: parent
        color: "#000000"
        opacity: Motion.reduced ? 0.42 : 0

        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(panel, eventPoint.position))
                    root.close();
            }
        }
    }

    Controls.Panel {
        id: panel
        z: 1
        width: SpotlightGeometry.panelWidth(root.width, Metrics.spacingLarge)
        height: SpotlightGeometry.panelHeight(
            root.height, Metrics.spacingLarge)
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: SpotlightGeometry.panelTop()
        customColor: Theme.background
        transformOrigin: Item.Top
        opacity: Motion.reduced ? 1 : 0
        scale: Motion.reduced ? 1 : 0.96
        transform: Translate {
            id: panelTranslate
            y: Motion.reduced ? 0 : -14
        }

        ParallelAnimation {
            id: panelEntrance
            running: !Motion.reduced

            NumberAnimation {
                target: backdropScrim
                property: "opacity"
                from: 0
                to: 0.42
                duration: 180
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: panel
                property: "opacity"
                from: 0
                to: 1
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: panel
                property: "scale"
                from: 0.96
                to: 1
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.springDamped
            }
            NumberAnimation {
                target: panelTranslate
                property: "y"
                from: -10
                to: 0
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.springDamped
            }
        }

        ParallelAnimation {
            id: panelExit

            NumberAnimation {
                target: backdropScrim
                property: "opacity"
                from: 0.42
                to: 0
                duration: 120
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: panel
                property: "opacity"
                from: 1
                to: 0
                duration: 110
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: panel
                property: "scale"
                from: 1
                to: 0.97
                duration: 130
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: panelTranslate
                property: "y"
                from: 0
                to: -8
                duration: 130
                easing.type: Easing.InCubic
            }
            onFinished: SurfaceManager.close(root.ownerId)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: SpotlightLayout.panelContentTopInset()
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: SpotlightLayout.headerCategoryGap()
                spacing: Metrics.spacingMedium

                Controls.Icon {
                    name: "rocket_launch"
                    size: SpotlightHeader.identityIconSize()
                    tone: "secondary"
                    accessibleName: I18n.tr("spotlight.identity")
                }

                QtControls.TextField {
                id: searchField
                Layout.preferredWidth: SpotlightHeader.searchFieldWidth()
                Layout.maximumWidth: SpotlightHeader.searchFieldWidth()
                implicitHeight: SpotlightHeader.searchFieldHeight()
                activeFocusOnTab: true
                text: spotlightModel.query
                placeholderText: I18n.tr(spotlightModel.mode === "clipboard"
                    ? "spotlight.clipboard.search_placeholder"
                    : (spotlightModel.mode === "system"
                        ? "spotlight.system.search_placeholder" : "spotlight.search_placeholder"))
                color: Theme.textPrimary
                placeholderTextColor: Theme.textSecondary
                font.family: Typography.family
                font.pixelSize: SpotlightVisual.searchTextSize()
                leftPadding: 44
                rightPadding: Metrics.spacingLarge
                selectByMouse: true

                background: Rectangle {
                    radius: searchField.height / 2
                    color: Theme.surfaceElevated
                    border.width: Metrics.borderWidth
                    border.color: searchField.activeFocus ? Theme.borderStrong : Theme.border
                }

                Controls.Icon {
                    anchors.left: parent.left
                    anchors.leftMargin: Metrics.spacingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 20
                    tone: "secondary"
                    accessibleName: ""
                }

                onTextEdited: spotlightModel.setQuery(text)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        const reverse = event.key === Qt.Key_Backtab
                            || (event.modifiers & Qt.ShiftModifier) !== 0;
                        spotlightModel.cycleScope(reverse ? -1 : 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        if (spotlightModel.mode === "clipboard" && bodyLoader.item)
                            root.clipboardMoveRequested(1);
                        else
                            spotlightModel.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        if (spotlightModel.mode === "clipboard" && bodyLoader.item)
                            root.clipboardMoveRequested(-1);
                        else
                            spotlightModel.moveSelection(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (spotlightModel.mode === "clipboard" && bodyLoader.item)
                            root.clipboardActivateRequested();
                        else if (spotlightModel.activateSelected())
                            root.close();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.handleEscape();
                        event.accepted = true;
                    }
                }

                Accessible.role: Accessible.EditableText
                Accessible.name: I18n.tr(spotlightModel.mode === "clipboard"
                    ? "spotlight.clipboard.search_accessible"
                    : (spotlightModel.mode === "system"
                        ? "spotlight.system.search_accessible" : "spotlight.search_accessible"))
                Accessible.focusable: true
                }

                Item {
                    id: scopeGroup
                    Layout.preferredWidth: SpotlightHeader.scopeGroupWidth()
                    Layout.preferredHeight: SpotlightHeader.scopeButtonSize()
                    Layout.alignment: Qt.AlignVCenter

                    Row {
                        id: scopeStrip
                        anchors.centerIn: parent
                        spacing: Metrics.spacingSmall

                        Repeater {
                            model: root.scopeActions

                            Controls.Button {
                                required property var modelData
                                width: SpotlightHeader.scopeButtonSize()
                                height: SpotlightHeader.scopeButtonSize()
                                iconName: modelData.icon
                                iconSize: modelData.iconSize
                                variant: "secondary"
                                selected: spotlightModel.scope === modelData.id
                                backgroundRadius: Metrics.radiusLarge
                                activeFocusOnTab: false
                                accessibleName: I18n.tr(modelData.accessibleKey)
                                QtControls.ToolTip.visible: hovered
                                QtControls.ToolTip.text: accessibleName
                                QtControls.ToolTip.delay: 500
                                onTriggered: {
                                    spotlightModel.setScope(modelData.id);
                                    searchField.forceActiveFocus(Qt.MouseFocusReason);
                                }
                            }
                        }
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.leftMargin: SpotlightLayout.categoryHorizontalInset()
                Layout.bottomMargin: SpotlightLayout.categoryGridGap()
                implicitHeight: categoryRow.implicitHeight
                contentWidth: categoryRow.implicitWidth
                contentHeight: height
                visible: spotlightModel.scope === "applications" && spotlightModel.mode === "browse"
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: categoryRow
                    spacing: SpotlightLayout.categorySpacing()

                    Repeater {
                        model: spotlightModel.categories

                        Controls.Button {
                            required property var modelData
                            label: I18n.tr("spotlight.category." + modelData.id)
                            variant: "quiet"
                            size: SpotlightVisual.categoryControlSize()
                            width: implicitWidth + SpotlightLayout.categoryWidthBonus()
                            height: SpotlightLayout.categoryControlHeight()
                            labelPixelSize: SpotlightVisual.categoryLabelSize()
                            selected: spotlightModel.categoryId === modelData.id
                            backgroundRadius: height / 2
                            accessibleName: I18n.tr("spotlight.category_accessible", { "name": label })
                            onTriggered: {
                                spotlightModel.setCategory(modelData.id);
                                searchField.forceActiveFocus(Qt.ShortcutFocusReason);
                            }
                        }
                    }
                }
            }

            Loader {
                id: bodyLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: spotlightModel.mode === "browse" || spotlightModel.mode === "results"
                    || spotlightModel.mode === "clipboard" || spotlightModel.mode === "system"
                source: spotlightModel.mode === "browse"
                    ? Qt.resolvedUrl("AppGrid.qml")
                    : (spotlightModel.mode === "results" ? Qt.resolvedUrl("SearchResults.qml")
                        : (spotlightModel.mode === "clipboard" ? Qt.resolvedUrl("ClipboardView.qml")
                            : (spotlightModel.mode === "system" ? Qt.resolvedUrl("SystemSearchMock.qml") : "")))
                onLoaded: root.configureLoadedBody(item)
            }

            Connections {
                target: bodyLoader.item || null
                ignoreUnknownSignals: true
                function onActivatedSuccessfully(): void { root.close(); }
            }
        }
    }

    Keys.onEscapePressed: event => {
        root.handleEscape();
        event.accepted = true;
    }

    Component.onCompleted: {
        spotlightModel.open(root.descriptor?.mode || "applications");
        spotlightModel.setQuery(root.descriptor?.query || "");
        searchField.forceActiveFocus(Qt.PopupFocusReason);
    }
}
