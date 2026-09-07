pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    property bool focused: false
    property color focusColor: "#8bb8ff"
    objectName: "styleFocusRing"
    color: "transparent"
    border.width: 2
    border.color: focusColor
    visible: focused && enabled
}
