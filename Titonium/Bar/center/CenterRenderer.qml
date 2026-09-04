pragma ComponentBehavior: Bound

import QtQuick
import "presentations/Connected" as Connected

Item {
    id: root
    required property var snapshot
    required property var viewState
    required property var profile
    signal intentRequested(var intent)
    signal transitionFinished(int generation)
    readonly property rect visualBounds: renderer.visualBounds
    readonly property rect interactiveBounds: renderer.interactiveBounds

    Connected.ConnectedRenderer {
        id: renderer
        anchors.fill: parent
        snapshot: root.snapshot
        viewState: root.viewState
        profile: root.profile
        onIntentRequested: intent => root.intentRequested(intent)
        onTransitionFinished: generation => root.transitionFinished(generation)
    }
}
