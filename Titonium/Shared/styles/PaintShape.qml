import QtQuick
Rectangle {
    required property var geometry
    radius: geometry.radius
    topLeftRadius: geometry.topLeftRadius
    topRightRadius: geometry.topRightRadius
    bottomLeftRadius: geometry.bottomLeftRadius
    bottomRightRadius: geometry.bottomRightRadius
}
