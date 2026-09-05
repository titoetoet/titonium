pragma ComponentBehavior: Bound

import QtQuick
import "presentations/Classic" as Classic
import "presentations/Connected" as Connected
import "presentations/Notch" as Notch
import "presentations/Pill" as Pill

Item {
    id: root
    required property var snapshot
    required property var viewState
    required property var profile
    required property bool transitionOwner
    required property bool presentationActive
    signal intentRequested(var intent)
    signal transitionFinished(int generation)
    readonly property var activeRenderer: root.profile.id === "pill" ? pill
        : (root.profile.id === "notch" ? notch
        : (root.profile.id === "classic" ? classic : connected))
    readonly property rect visualBounds: root.activeRenderer.visualBounds
    readonly property rect interactiveBounds: root.activeRenderer.interactiveBounds
    readonly property bool transitionActive: root.profile.id === "classic"
        && classic.transitionActive

    Connected.ConnectedRenderer {
        id: connected
        anchors.fill: parent
        visible: root.profile.id === "connected"
        snapshot: root.snapshot
        viewState: root.viewState
        profile: root.profile
        onIntentRequested: intent => root.intentRequested(intent)
        onTransitionFinished: generation => {
            if (root.presentationActive && root.profile.id === "connected")
                root.transitionFinished(generation);
        }
    }
    Pill.PillRenderer { id: pill; anchors.fill: parent; visible: root.profile.id === "pill"; snapshot: root.snapshot; viewState: root.viewState; profile: root.profile; onIntentRequested: intent => root.intentRequested(intent); onTransitionFinished: generation => { if (root.presentationActive && root.profile.id === "pill") root.transitionFinished(generation); } }
    Notch.NotchRenderer { id: notch; anchors.fill: parent; visible: root.profile.id === "notch"; snapshot: root.snapshot; viewState: root.viewState; profile: root.profile; onIntentRequested: intent => root.intentRequested(intent); onTransitionFinished: generation => { if (root.presentationActive && root.profile.id === "notch") root.transitionFinished(generation); } }
    Classic.ClassicRenderer { id: classic; anchors.fill: parent; visible: root.profile.id === "classic"; snapshot: root.snapshot; viewState: root.viewState; profile: root.profile; transitionOwner: root.transitionOwner && root.profile.id === "classic"; onIntentRequested: intent => root.intentRequested(intent); onTransitionFinished: generation => { if (root.presentationActive && root.transitionOwner && root.profile.id === "classic") root.transitionFinished(generation); } }
}
