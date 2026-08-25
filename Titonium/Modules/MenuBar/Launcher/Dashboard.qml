pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation
import qs.Titonium.Platform.System

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    property string pendingSessionAction: ""
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property var launcherSettings: ConfigStore.previewState.modules?.launcher || ({})
    readonly property string displayName: root.launcherSettings.username?.trim().length > 0
        ? root.launcherSettings.username.trim() : UserIdentity.loginName
    readonly property var categories: [
        { "id": "all", "labelKey": "launcher.category.all", "icon": "apps" },
        { "id": "recent", "labelKey": "launcher.category.recent", "icon": "history" },
        { "id": "internet", "labelKey": "launcher.category.internet", "icon": "public" },
        { "id": "development", "labelKey": "launcher.category.development", "icon": "code" },
        { "id": "media", "labelKey": "launcher.category.media", "icon": "movie" },
        { "id": "system", "labelKey": "launcher.category.system", "icon": "settings" }
    ]
    readonly property var sessionActions: [
        { "id": "sleep", "icon": "bedtime", "labelKey": "launcher.action.sleep" },
        { "id": "hibernate", "icon": "ac_unit", "labelKey": "launcher.action.hibernate" },
        { "id": "logout", "icon": "logout", "labelKey": "launcher.action.logout" },
        { "id": "restart", "icon": "restart_alt", "labelKey": "launcher.action.restart" },
        { "id": "shutdown", "icon": "power_settings_new", "labelKey": "launcher.action.shutdown" }
    ]

    anchors.fill: parent
    focus: true

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    function close(): void { SurfaceCoordinator.close(root.ownerId); }

    function openLauncherSettings(): void {
        const settingsOwnerId = "settings:" + root.screen.name;
        ConfigStore.beginPreview();
        SurfaceCoordinator.open(settingsOwnerId, {
            "source": Qt.resolvedUrl("../../Settings/SettingsCenter.qml"),
            "keyboardFocus": "exclusive",
            "ownerId": settingsOwnerId,
            "page": "launcher",
            "cancelPreviewOnClose": true
        }, root.screen);
    }

    function selectCategory(categoryId: string): void {
        catalog.category = categoryId;
        pageView.currentIndex = 0;
        pageView.positionViewAtIndex(0, ListView.Beginning);
    }

    function confirmSessionAction(): void {
        const action = root.pendingSessionAction;
        root.pendingSessionAction = "";
        if (SessionActions.executeConfirmed(action))
            root.close();
    }

    function launchFirstResult(): void {
        if (catalog.filteredApplications.length === 0)
            return;
        if (catalog.launch(catalog.filteredApplications[0]))
            root.close();
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.28)
        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(panel, eventPoint.position)) root.close();
            }
        }
    }

    Controls.Panel {
        id: panel
        z: 1
        width: Math.min(1080, root.width - Metrics.spacingLarge * 2)
        height: Math.min(660, root.height - Metrics.barHeight - Metrics.spacingLarge * 2)
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Metrics.barHeight + Metrics.spacingSmall
        anchors.leftMargin: Metrics.barPadding
        padding: Metrics.spacingLarge

        RowLayout {
            anchors.fill: parent
            spacing: Metrics.spacingLarge

            ColumnLayout {
                Layout.preferredWidth: Math.floor((panel.contentItem.width - Metrics.spacingLarge - Metrics.borderWidth) / 3)
                Layout.minimumWidth: Layout.preferredWidth
                Layout.maximumWidth: Layout.preferredWidth
                Layout.fillHeight: true
                spacing: Metrics.spacingSmall

                Item {
                    id: profileSurface

                    Layout.fillWidth: true
                    implicitWidth: 1
                    implicitHeight: 72

                    FocusScope {
                        id: avatarCircle

                        anchors.left: parent.left
                        anchors.leftMargin: Metrics.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        activeFocusOnTab: true

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: avatarHover.hovered ? Theme.surfaceElevated : Theme.surfaceInteractive
                            border.width: Metrics.borderWidth
                            border.color: avatarCircle.activeFocus ? Theme.focus : Theme.borderStrong
                        }

                        Controls.Icon {
                            anchors.centerIn: parent
                            visible: !avatarHover.hovered && !avatarCircle.activeFocus
                            name: root.launcherSettings.avatarIcon || "terminal"
                            size: 32
                            tone: "accent"
                            accessibleName: ""
                        }

                        Controls.Icon {
                            anchors.centerIn: parent
                            visible: avatarHover.hovered || avatarCircle.activeFocus
                            name: "person_edit"
                            size: 24
                            tone: "accent"
                            accessibleName: ""
                        }

                        HoverHandler {
                            id: avatarHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler { onTapped: root.openLauncherSettings() }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                    || event.key === Qt.Key_Space) {
                                root.openLauncherSettings();
                                event.accepted = true;
                            }
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.tr("launcher.profile.open_settings")
                        Accessible.focusable: true
                    }

                    Rectangle {
                        id: thoughtDotTiny

                        width: 4
                        height: 4
                        radius: width / 2
                        color: Theme.surfaceInteractive
                        border.width: Metrics.borderWidth
                        border.color: Theme.borderStrong
                        anchors.left: avatarCircle.right
                        anchors.leftMargin: 1
                        anchors.verticalCenter: thoughtBubble.verticalCenter
                        anchors.verticalCenterOffset: 16
                    }

                    Rectangle {
                        id: thoughtDotSmall

                        width: 7
                        height: 7
                        radius: width / 2
                        color: Theme.surfaceInteractive
                        border.width: Metrics.borderWidth
                        border.color: Theme.borderStrong
                        anchors.left: avatarCircle.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: thoughtBubble.verticalCenter
                        anchors.verticalCenterOffset: 10
                    }

                    Rectangle {
                        id: thoughtDotLarge

                        width: 10
                        height: 10
                        radius: width / 2
                        color: Theme.surfaceInteractive
                        border.width: Metrics.borderWidth
                        border.color: Theme.borderStrong
                        anchors.left: avatarCircle.right
                        anchors.leftMargin: 16
                        anchors.verticalCenter: thoughtBubble.verticalCenter
                        anchors.verticalCenterOffset: 3
                    }

                    Canvas {
                        id: thoughtBubble

                        anchors.left: avatarCircle.right
                        anchors.leftMargin: 26
                        anchors.right: parent.right
                        anchors.rightMargin: Metrics.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        height: 52

                        property color fillColor: Theme.surfaceInteractive
                        property color outlineColor: Theme.borderStrong

                        onFillColorChanged: requestPaint()
                        onOutlineColorChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            const context = getContext("2d");
                            const w = width;
                            const h = height;
                            context.clearRect(0, 0, w, h);
                            context.beginPath();
                            context.moveTo(w * 0.14, h * 0.80);
                            context.bezierCurveTo(w * 0.02, h * 0.80, w * 0.01, h * 0.58, w * 0.12, h * 0.51);
                            context.bezierCurveTo(w * 0.08, h * 0.34, w * 0.20, h * 0.24, w * 0.31, h * 0.30);
                            context.bezierCurveTo(w * 0.35, h * 0.09, w * 0.52, h * 0.06, w * 0.61, h * 0.25);
                            context.bezierCurveTo(w * 0.73, h * 0.12, w * 0.86, h * 0.24, w * 0.84, h * 0.41);
                            context.bezierCurveTo(w * 0.98, h * 0.40, w * 1.00, h * 0.64, w * 0.89, h * 0.72);
                            context.bezierCurveTo(w * 0.92, h * 0.88, w * 0.73, h * 0.95, w * 0.62, h * 0.86);
                            context.bezierCurveTo(w * 0.49, h * 0.98, w * 0.33, h * 0.91, w * 0.29, h * 0.83);
                            context.bezierCurveTo(w * 0.24, h * 0.91, w * 0.15, h * 0.89, w * 0.14, h * 0.80);
                            context.closePath();
                            context.fillStyle = fillColor;
                            context.fill();
                            context.lineWidth = Metrics.borderWidth;
                            context.lineJoin = "round";
                            context.strokeStyle = outlineColor;
                            context.stroke();
                        }

                        Controls.TextLabel {
                            anchors.fill: parent
                            anchors.leftMargin: Metrics.spacingLarge
                            anchors.rightMargin: Metrics.spacingLarge
                            anchors.topMargin: 4
                            text: root.displayName
                            variant: "label"
                            strong: false
                            font.italic: true
                            font.capitalization: Font.MixedCase
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }

                }

                Rectangle { Layout.fillWidth: true; implicitHeight: Metrics.borderWidth; color: Theme.border }

                Repeater {
                    model: root.categories
                    Controls.Button {
                        required property var modelData
                        Layout.fillWidth: true
                        label: I18n.tr(modelData.labelKey)
                        iconName: modelData.icon
                        variant: "quiet"
                        contentAlignment: Qt.AlignLeft
                        selected: catalog.category === modelData.id
                        accessibleName: label
                        onTriggered: root.selectCategory(modelData.id)
                    }
                }

                Item { Layout.fillHeight: true }

                Controls.Surface {
                    visible: root.pendingSessionAction.length > 0
                    Layout.fillWidth: true
                    implicitWidth: 1
                    implicitHeight: visible ? 84 : 0
                    tone: "elevated"
                    radius: Metrics.radiusMedium
                    outlined: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Metrics.spacingSmall
                        spacing: Metrics.spacingSmall
                        Controls.TextLabel {
                            Layout.fillWidth: true
                            text: I18n.tr("launcher.action.confirm", {
                                "action": I18n.tr("launcher.action." + root.pendingSessionAction)
                            })
                            variant: "caption"
                            strong: true
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Controls.Button {
                                Layout.fillWidth: true
                                label: I18n.tr("launcher.action.cancel")
                                size: "small"
                                onTriggered: root.pendingSessionAction = ""
                            }
                            Controls.Button {
                                Layout.fillWidth: true
                                label: I18n.tr("launcher.action.confirm_button")
                                variant: "danger"
                                size: "small"
                                onTriggered: root.confirmSessionAction()
                            }
                        }
                    }
                }

                RowLayout {
                    visible: root.pendingSessionAction.length === 0
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXSmall
                    Repeater {
                        model: root.sessionActions
                        Controls.Button {
                            required property var modelData
                            Layout.fillWidth: true
                            iconName: modelData.icon
                            variant: modelData.id === "shutdown" ? "danger" : "quiet"
                            size: "small"
                            accessibleName: I18n.tr(modelData.labelKey)
                            onTriggered: root.pendingSessionAction = modelData.id
                        }
                    }
                }
            }

            Rectangle { Layout.fillHeight: true; implicitWidth: Metrics.borderWidth; color: Theme.border }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Metrics.spacingMedium

                RowLayout {
                    Layout.fillWidth: true
                    Controls.Surface {
                        Layout.fillWidth: true
                        implicitWidth: 1
                        implicitHeight: 40
                        tone: "elevated"
                        radius: Metrics.radiusMedium
                        outlined: true
                        borderColor: searchInput.activeFocus ? Theme.focus : Theme.border

                        Controls.Icon {
                            anchors.left: parent.left
                            anchors.leftMargin: Metrics.spacingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            name: "search"
                            size: 19
                            tone: searchInput.activeFocus ? "accent" : "secondary"
                            accessibleName: ""
                        }
                        TextInput {
                            id: searchInput
                            anchors.left: parent.left
                            anchors.leftMargin: 42
                            anchors.right: clearButton.left
                            anchors.rightMargin: Metrics.spacingSmall
                            anchors.verticalCenter: parent.verticalCenter
                            text: catalog.query
                            color: Theme.textPrimary
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentText
                            font.family: Typography.family
                            font.pixelSize: Typography.sizeFor("body")
                            selectByMouse: true
                            clip: true
                            onTextEdited: catalog.query = text
                            Keys.onReturnPressed: event => {
                                root.launchFirstResult();
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: event => {
                                root.launchFirstResult();
                                event.accepted = true;
                            }
                            Controls.TextLabel {
                                anchors.fill: parent
                                visible: searchInput.text.length === 0
                                text: I18n.tr("launcher.search_placeholder")
                                tone: "secondary"
                            }
                        }
                        Controls.Button {
                            id: clearButton
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            visible: catalog.query.length > 0
                            iconName: "close"
                            variant: "quiet"
                            size: "small"
                            accessibleName: I18n.tr("launcher.clear_search")
                            onTriggered: {
                                catalog.query = "";
                                searchInput.text = "";
                                searchInput.forceActiveFocus(Qt.ShortcutFocusReason);
                            }
                        }
                    }
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
                        highlightMoveDuration: root.launcherSettings.pageTransition === "none"
                            ? 0 : (root.launcherSettings.transitionDuration || 220)
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

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: root.launcherSettings.pageTransition === "none"
                                        ? 0 : (root.launcherSettings.transitionDuration || 220)
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: root.launcherSettings.pageTransition === "none"
                                        ? 0 : (root.launcherSettings.transitionDuration || 220)
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Flow {
                                anchors.fill: parent
                                spacing: Metrics.spacingSmall
                                Repeater {
                                    model: appPage.modelData
                                    ApplicationTile {
                                        required property var modelData
                                        width: Math.floor((appPage.width - Metrics.spacingSmall * 5) / 6)
                                        height: Math.floor((appPage.height - Metrics.spacingSmall * 3) / 4)
                                        application: modelData
                                        showSubtitle: root.launcherSettings.showSubtitles === true
                                        onTriggered: {
                                            if (catalog.launch(modelData)) root.close();
                                        }
                                    }
                                }
                            }
                        }

                        Controls.TextLabel {
                            anchors.centerIn: parent
                            visible: catalog.filteredApplications.length === 0
                            text: I18n.tr("launcher.no_results")
                            tone: "secondary"
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
                        FocusScope {
                            id: pageIndicator

                            required property int index
                            required property var modelData
                            readonly property bool currentPage: index === pageView.currentIndex
                            readonly property real fillRatio: Math.min(1,
                                Math.max(0, modelData.length / catalog.pageSize))

                            width: currentPage ? 12 + Math.round(28 * fillRatio) : 8
                            height: 20
                            activeFocusOnTab: true

                            Behavior on width {
                                NumberAnimation {
                                    duration: root.launcherSettings.pageTransition === "none"
                                        ? 0 : (root.launcherSettings.transitionDuration || 220)
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 8
                                radius: height / 2
                                color: pageIndicator.currentPage ? Theme.accent : Theme.borderStrong
                                border.width: pageIndicator.activeFocus ? Metrics.borderWidth : 0
                                border.color: Theme.focus
                            }

                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: pageView.currentIndex = pageIndicator.index }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                        || event.key === Qt.Key_Space) {
                                    pageView.currentIndex = pageIndicator.index;
                                    event.accepted = true;
                                }
                            }

                            Accessible.role: Accessible.Button
                            Accessible.name: I18n.tr("launcher.page_go", { "page": index + 1 })
                            Accessible.focusable: true
                        }
                    }
                }
            }
        }
    }

    ApplicationCatalogModel { id: catalog }

    Connections {
        target: catalog
        function onPagesChanged(): void {
            pageView.currentIndex = 0;
            pageView.positionViewAtIndex(0, ListView.Beginning);
        }
    }

    Keys.onEscapePressed: event => {
        if (root.pendingSessionAction.length > 0)
            root.pendingSessionAction = "";
        else if (catalog.query.length > 0) {
            catalog.query = "";
            searchInput.text = "";
        } else
            root.close();
        event.accepted = true;
    }

    Component.onCompleted: {
        if (root.launcherSettings.searchAutoFocus !== false)
            Qt.callLater(() => searchInput.forceActiveFocus(Qt.PopupFocusReason));
    }
}
