pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Network
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property var invoker: root.descriptor?.invoker || null
    readonly property int maximumHeight: 520
    readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing
    readonly property real availableHeight: Math.max(0, root.height - root.panelTop - Metrics.barPadding)
    readonly property real contentHeight: contentColumn.implicitHeight + 2 * panel.padding

    anchors.fill: parent
    focus: true

    function returnFocus(): void {
        if (root.invoker && root.invoker.forceActiveFocus)
            root.invoker.forceActiveFocus(Qt.PopupFocusReason);
    }

    property bool closing: false

    function close(): void {
        root.returnFocus();
        if (Motion.reduced) {
            if (root.ownerId)
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

    function networksFor(section: string): var {
        return NetworkService.networks.filter(network => network.section === section);
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(panel, eventPoint.position))
                    root.close();
            }
        }
    }

    Shared.Panel {
        id: panel
        width: 380
        height: Math.min(root.maximumHeight, root.availableHeight, root.contentHeight)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.panelTop
        anchors.rightMargin: Metrics.barPadding
        customColor: Theme.surface
        clipContent: true
        transformOrigin: Item.Top
        opacity: Motion.reduced ? 1 : 0
        scale: Motion.reduced ? 1 : 0.98
        transform: Translate {
            id: panelEntranceOffset
            y: Motion.reduced ? 0 : -8
        }

        Behavior on height { NumberAnimation { duration: Motion.normal } }

        Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentColumn
                width: parent.width
                spacing: Metrics.spacingMedium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingMedium

                    Shared.Icon {
                        name: NetworkService.iconName
                        size: 24
                        tone: NetworkService.wifiEnabled ? "accent" : "disabled"
                        accessibleName: ""
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Metrics.spacingXSmall

                        Shared.TextLabel {
                            Layout.fillWidth: true
                            text: I18n.tr("wifi.title")
                            variant: "title"
                            strong: true
                        }

                        Shared.TextLabel {
                            Layout.fillWidth: true
                            text: I18n.tr(NetworkService.stateKey, { "name": NetworkService.connectedName })
                            tone: "secondary"
                            variant: "caption"
                            elide: Text.ElideRight
                        }
                    }

                    Shared.Button {
                        iconName: NetworkService.scanning ? "sync" : "refresh"
                        variant: "quiet"
                        size: "small"
                        enabled: NetworkService.available && NetworkService.wifiEnabled
                        accessibleName: I18n.tr(NetworkService.scanning
                            ? "wifi.scan.stop.accessible" : "wifi.scan.start.accessible")
                        onTriggered: NetworkService.setScanning(!NetworkService.scanning)
                    }

                    Shared.Button {
                        iconName: NetworkService.wifiEnabled ? "wifi_off" : "wifi"
                        variant: "quiet"
                        size: "small"
                        enabled: NetworkService.available && NetworkService.wifiHardwareEnabled
                        accessibleName: I18n.tr(NetworkService.wifiEnabled
                            ? "wifi.power.off.accessible" : "wifi.power.on.accessible")
                        onTriggered: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Metrics.borderWidth
                    color: Theme.border
                }

                Repeater {
                    model: ["connected", "known", "available"]

                    delegate: ColumnLayout {
                        id: section
                        required property string modelData
                        readonly property var sectionNetworks: root.networksFor(modelData)
                        readonly property string sectionTitle: I18n.tr("wifi.section." + section.modelData)

                        Layout.fillWidth: true
                        spacing: Metrics.spacingSmall
                        visible: NetworkService.wifiEnabled && sectionNetworks.length > 0

                        Shared.TextLabel {
                            Layout.fillWidth: true
                            text: section.sectionTitle
                            variant: "label"
                            strong: true
                            Accessible.role: Accessible.Heading
                            Accessible.name: section.sectionTitle
                        }

                        Repeater {
                            model: section.sectionNetworks

                            delegate: WifiNetworkRow {
                                required property var modelData
                                Layout.fillWidth: true
                                network: modelData
                            }
                        }
                    }
                }

                Shared.TextLabel {
                    Layout.fillWidth: true
                    visible: NetworkService.wifiEnabled && NetworkService.networks.length === 0
                    text: I18n.tr(NetworkService.scanning ? "wifi.networks.scanning" : "wifi.networks.empty")
                    tone: "secondary"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Shared.TextLabel {
                    Layout.fillWidth: true
                    visible: !NetworkService.available || !NetworkService.wifiHardwareEnabled
                    text: I18n.tr(!NetworkService.available ? "wifi.unavailable" : "wifi.hardware_off")
                    tone: "secondary"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    ParallelAnimation {
        id: panelEntrance
        running: !Motion.reduced

        NumberAnimation {
            target: panel
            property: "opacity"
            from: 0
            to: 1
            duration: 140
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 0.98
            to: 1
            duration: 180
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
        NumberAnimation {
            target: panelEntranceOffset
            property: "y"
            from: -8
            to: 0
            duration: 180
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
    }

    ParallelAnimation {
        id: panelExit

        NumberAnimation {
            target: panel
            property: "opacity"
            from: 1
            to: 0
            duration: 100
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 1
            to: 0.98
            duration: 100
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panelEntranceOffset
            property: "y"
            from: 0
            to: -6
            duration: 100
            easing.type: Easing.InCubic
        }
        onFinished: {
            if (root.ownerId)
                SurfaceManager.close(root.ownerId);
        }
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: {
        panel.forceActiveFocus(Qt.PopupFocusReason);
    }
    Component.onDestruction: {
        root.returnFocus();
    }
}
