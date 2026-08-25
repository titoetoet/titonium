pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design

Surface {
    id: root

    property bool interactive: false
    property bool selected: false
    property string accessibleName: ""
    signal triggered()

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed

    tone: root.interactive && (root.hovered || root.pressed || root.activeFocus || root.selected) ? "interactive" : "elevated"
    radius: Metrics.radiusMedium
    padding: Metrics.spacingMedium
    outlined: true
    borderColor: root.activeFocus ? Theme.focus : Theme.border
    activeFocusOnTab: root.interactive && root.enabled
    opacity: root.enabled ? 1.0 : 0.55

    HoverHandler {
        id: hoverHandler
        enabled: root.interactive && root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        enabled: root.interactive && root.enabled
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.triggered();
        }
    }

    Keys.onPressed: event => {
        if (root.interactive && root.enabled
                && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            root.triggered();
            event.accepted = true;
        }
    }

    Accessible.role: root.interactive ? Accessible.Button : Accessible.Pane
    Accessible.name: root.accessibleName
    Accessible.focusable: root.interactive && root.enabled
    Accessible.selected: root.selected
}
