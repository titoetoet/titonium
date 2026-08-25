import QtQuick

Item {
    required property var node
    required property var screen
    required property var context

    implicitWidth: node.size || 8
    implicitHeight: node.size || 8
}
