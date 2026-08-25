pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Composition
import qs.Titonium.Design
import qs.Titonium.Foundation

Item {
    id: root

    required property var screenModel

    readonly property var screenLayout: ConfigStore.screenLayout(root.screenModel.name)
    readonly property var slots: root.screenLayout.slots || ({})
    readonly property var widgetContext: ({
        "surface": "menubar",
        "openSurface": function(ownerId, descriptor) {
            SurfaceCoordinator.open(ownerId, descriptor, root.screenModel);
        }
    })

    MaterialSurface {
        anchors.fill: parent
        radius: 0
        outlined: false
    }

    LayoutRenderer {
        anchors.left: root.left
        anchors.leftMargin: Metrics.barPadding
        anchors.verticalCenter: root.verticalCenter
        nodes: root.slots.start || []
        screen: root.screenModel
        context: root.widgetContext
    }

    LayoutRenderer {
        anchors.centerIn: root
        nodes: root.slots.center || []
        screen: root.screenModel
        context: root.widgetContext
    }

    LayoutRenderer {
        anchors.right: root.right
        anchors.rightMargin: Metrics.barPadding
        anchors.verticalCenter: root.verticalCenter
        nodes: root.slots.end || []
        screen: root.screenModel
        context: root.widgetContext
    }
}
