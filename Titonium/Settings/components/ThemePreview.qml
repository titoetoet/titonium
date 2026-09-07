pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared

// Candidate-only scene. Real paint and controls, no live desktop or action services.
Rectangle {
    id: root
    required property var tokens
    property url wallpaperSource: ""
    property bool compact: false
    property string layoutStyle: "connected"
    readonly property var previewPalette: tokens.colors || ({})
    readonly property var material: tokens.material || ({})
    readonly property real radiusScale: material.radiusScale || 1
    readonly property color accent: previewPalette.accent || "#5b9cff"
    readonly property color foreground: previewPalette.textPrimary || "#f2f4f7"
    implicitWidth: 600
    implicitHeight: compact ? 110 : 290
    radius: 14
    clip: true
    color: previewPalette.background || "#111318"
    Accessible.role: Accessible.Graphic
    Accessible.name: I18n.tr("settings.appearance.preview")

    Image {
        anchors.fill: parent
        source: root.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
    }
    Rectangle {
        width: parent.width * .65; height: width; radius: width / 2
        x: parent.width * .55; y: -parent.height * .3
        color: root.accent; opacity: .09
    }
    Item {
        x: 12; y: 8; width: parent.width - 24; height: root.compact ? 14 : 28
        Repeater {
            model: 3
            Item {
                id: miniIsland
                required property int index
                x: index === 0 ? 0 : index === 1 ? (parent.width-width)/2 : parent.width-width
                width: index === 1 ? parent.width * .22 : parent.width * .27
                height: parent.height
                Shared.StylePaint {
                    anchors.fill: parent; tokens:root.tokens;role:"surface"
                    radius: height/2
                    topLeftRadius: root.layoutStyle === "connected" && miniIsland.index !== 2 ? 0 : radius
                    topRightRadius: root.layoutStyle === "connected" && miniIsland.index !== 0 ? 0 : radius
                }
                Rectangle { anchors.centerIn:parent;width:parent.width*.42;height:3;radius:2;color:root.foreground;opacity:.7 }
            }
        }
    }
    Shared.Surface {
        id: demoPanel
        x: root.compact ? 10 : 24
        y: root.compact ? 30 : 54
        width: parent.width - x*2
        height: root.compact ? 70 : 210
        tokens: root.tokens
        radius: root.compact ? 12 : root.tokens.design?.panelRadius || 12
        topLeftRadius: root.layoutStyle === "connected" ? 0 : radius
        topRightRadius: root.layoutStyle === "connected" ? 0 : radius
        ColumnLayout {
            anchors.fill:parent;anchors.margins:root.compact ? 8 : 18
            spacing:root.compact ? 5 : 12
            Text {
                Layout.fillWidth:true;visible:!root.compact
                text:I18n.tr("settings.appearance.preview_title")
                color:root.foreground;font.pixelSize:17;font.weight:Font.DemiBold
                elide:Text.ElideRight
            }
            Item {
                Layout.fillWidth:true;Layout.preferredHeight:root.compact ? 17 : 34
                Shared.StylePaint {
                    anchors.fill:parent;tokens:root.tokens;role:"field"
                    radius:root.compact ? 4 : 10
                    interaction:({focused:!root.compact})
                }
                TextInput {
                    anchors.fill:parent;anchors.leftMargin:12;anchors.rightMargin:12
                    visible:!root.compact
                    text:I18n.tr("settings.appearance.preview_focus")
                    color:root.foreground;font.pixelSize:12
                    verticalAlignment:TextInput.AlignVCenter
                    selectByMouse:true;clip:true
                    Accessible.name:I18n.tr("settings.appearance.preview_focus")
                }
            }
            RowLayout {
                Layout.fillWidth:true
                spacing:root.compact ? 6 : 20
                Shared.Button {
                    Layout.fillWidth:true
                    Layout.maximumWidth:root.compact ? 45 : 160
                    Layout.preferredHeight:root.compact ? 18 : 36
                    enabled:!root.compact
                    tokens:root.tokens;label:root.compact ? "" : I18n.tr("settings.appearance.preview_selected")
                    variant:"primary";size:root.compact ? "small" : "medium"
                    activeFocusOnTab:!root.compact
                }
                Shared.Toggle {
                    enabled:!root.compact
                    tokens:root.tokens;checked:true
                    accessibleName:I18n.tr("settings.appearance.preview_toggle")
                    activeFocusOnTab:!root.compact
                    onToggled: value => checked=value
                }
                Shared.Slider {
                    id: demoSlider
                    Layout.fillWidth:true;Layout.maximumWidth:root.compact ? 45 : 180
                    enabled:!root.compact
                    activeFocusOnTab:!root.compact
                    tokens:root.tokens;value:.62
                    accessibleName:I18n.tr("settings.appearance.preview_slider")
                    onMoved:value=>demoSlider.value=value
                }
            }
            Text {
                Layout.fillWidth:true;visible:!root.compact
                text:I18n.tr("settings.appearance.preview_local")
                color:root.previewPalette.textSecondary;font.pixelSize:11
                elide:Text.ElideRight
            }
        }
    }
    // Compact cards are a single keyboard/click target; demos must not steal it.

}
