pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root
    property var context: null
    signal intentRequested(var intent)
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.context?.title || I18n.tr("menubar.center.title")
    Accessible.onPressAction: root.activate()
    function activate(): void {
        root.intentRequested({ type: "activate-preview", contextId: root.context?.id || "" });
    }
    Keys.onReturnPressed: root.activate()
    Keys.onSpacePressed: root.activate()
    Shared.InteractionFeedback {
        anchors.fill: parent
        anchors.margins: 4
        radius: 12
        hovered: hover.hovered
        pressed: tap.pressed
        focused: root.activeFocus
    }
    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        Shared.SystemIcon {
            Layout.preferredWidth: 24; Layout.preferredHeight: 24
            sourceName: root.context?.icon || ""
            fallbackName: root.context?.icon || "center_focus_strong"
            size: 24
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Shared.TextLabel {
                Layout.fillWidth: true
                text: root.context?.title || I18n.tr("menubar.center.title")
                strong: true
                elide: Text.ElideRight
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.context?.subtitle || ""
                variant: "caption"
                tone: "secondary"
                elide: Text.ElideRight
            }
        }
        Shared.Icon { name: "open_in_full"; size: 16; tone: "secondary" }
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: root.intentRequested({ type: hovered ? "preview-enter" : "preview-leave",
            region: "banner", contextId: root.context?.id || "" })
    }
    TapHandler { id: tap; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: root.activate() }
}
