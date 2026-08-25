pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property var node
    required property var screen
    required property var context

    signal invoked(var descriptor)
    signal actionRequested(string action, var payload)

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
}
