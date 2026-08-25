pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property var node
    required property var screen
    required property var context

    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight

    Loader {
        id: loader
        anchors.fill: parent
        source: ""

        function loadWidget(): void {
            loader.setSource(WidgetRegistry.sourceFor(root.node.widgetType || ""), {
                "node": root.node,
                "screen": root.screen,
                "context": root.context
            });
        }

        Component.onCompleted: loader.loadWidget()
    }
}
