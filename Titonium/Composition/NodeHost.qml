pragma ComponentBehavior: Bound

import QtQuick

Loader {
    id: root

    required property var node
    required property var screen
    required property var context

    readonly property url nodeSource: {
        switch (root.node.type) {
        case "widget": return Qt.resolvedUrl("WidgetNode.qml");
        case "group": return Qt.resolvedUrl("GroupNode.qml");
        case "panel": return Qt.resolvedUrl("PanelNode.qml");
        case "tabs": return Qt.resolvedUrl("TabsNode.qml");
        case "spacer": return Qt.resolvedUrl("SpacerNode.qml");
        default: return Qt.resolvedUrl("WidgetNode.qml");
        }
    }

    function loadNode(): void {
        const safeNode = root.node.type ? root.node : {
            "type": "widget",
            "id": root.node.id || "invalid-node",
            "widgetType": "invalid.node",
            "label": "Invalid node"
        };
        root.setSource(root.nodeSource, {
            "node": safeNode,
            "screen": root.screen,
            "context": root.context
        });
    }

    Component.onCompleted: root.loadNode()
}
