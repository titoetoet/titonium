pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

FocusScope {
    id: root
    required property var descriptor
    required property var tokens
    property bool selected: false
    property bool applied: false
    signal selectedTheme(string themeId)
    implicitHeight: 218
    implicitWidth: 150
    activeFocusOnTab: enabled
    Accessible.role: Accessible.RadioButton
    Accessible.name: I18n.tr(descriptor.nameKey)
    Accessible.checked: selected
    Accessible.focusable: enabled
    function activate(): void {
        if (enabled) selectedTheme(descriptor.id);
    }
    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusMedium
        color: root.selected ? Theme.surfaceInteractive : Theme.surface
        border.width: root.selected || root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Theme.focus : root.selected ? Theme.accent : Theme.border
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 8
        spacing: 6
        ThemePreview {
            Layout.fillWidth: true
            Layout.preferredHeight: 110
            tokens: root.tokens
            compact: true
        }
        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr(root.descriptor.nameKey)
            strong: true
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            Layout.minimumHeight: 36
        }
        Shared.TextLabel {
            Layout.fillWidth: true
            Layout.minimumHeight: 34
            text: root.descriptor.descriptionKey ? I18n.tr(root.descriptor.descriptionKey)
                : I18n.tr("settings.appearance.style_description." + root.descriptor.id)
            tone: "secondary"
            variant: "bodySmall"
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Shared.TextLabel {
            Layout.fillWidth: true
            text: root.applied ? I18n.tr("settings.appearance.applied")
                    + (root.selected ? " · " + I18n.tr("settings.appearance.editing") : "")
                    : root.selected ? I18n.tr("settings.appearance.editing") : ""
            tone: root.selected ? "accent" : "secondary"
            variant: "bodySmall"
        }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler {
        enabled: root.enabled
        onTapped: { root.forceActiveFocus(Qt.MouseFocusReason); root.activate(); }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activate(); event.accepted = true;
        }
    }
}
