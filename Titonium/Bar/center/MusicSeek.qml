pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Controls.Slider {
    id: root
    property var playback: ({})
    property string contextId: ""
    property string pressedIdentity: ""
    property int pressedToken: -1
    signal intentRequested(var intent)
    from: 0; to: 1
    implicitHeight: 28
    enabled: root.playback.canSeek === true && root.playback.length > 0
    activeFocusOnTab: enabled
    Accessible.name: I18n.tr("center.music.seek")
    stepSize: root.playback.length > 0 ? Math.min(1, 5 / root.playback.length) : 0.01
    snapMode: Controls.Slider.NoSnap
    Binding {
        target: root; property: "value"
        value: Math.max(0, Math.min(1, (root.playback.position || 0) / Math.max(1, root.playback.length || 0)))
        when: !root.pressed
        restoreMode: Binding.RestoreNone
    }
    function seek(identity: string, token: int): void {
        root.intentRequested({ type: "media-seek", contextId: root.contextId,
            identity: identity, trackToken: token, fraction: root.value });
    }
    onPressedChanged: {
        if (pressed) {
            root.pressedIdentity = root.playback.identity || "";
            root.pressedToken = root.playback.trackToken ?? -1;
        } else if (root.pressedIdentity) {
            root.seek(root.pressedIdentity, root.pressedToken);
            root.pressedIdentity = "";
        }
    }
    onMoved: {
        if (!pressed) root.seek(root.playback.identity || "", root.playback.trackToken ?? -1);
    }
    background: Item {
        x: root.leftPadding
        y: (root.height - height) / 2
        width: root.availableWidth
        height: 3
        Rectangle {
            anchors.fill: parent
            visible: Theme.legacy
            radius: 2
            color: Theme.surfaceInteractive
        }
        Shared.StylePaint {
            anchors.fill: parent
            visible: !Theme.legacy
            tokens: Theme.tokens
            role: "field"
            radius: 2
            customColor: Theme.surfaceInteractive
            outlined: false
            showFocus: false
        }
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height; radius: 2
            color: root.enabled ? Theme.accent : Theme.textDisabled
        }
    }
    handle: Item {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: (root.height - height) / 2
        width: root.pressed || root.activeFocus ? 12 : 9
        height: width
        Rectangle {
            anchors.fill: parent
            visible: Theme.legacy
            radius: width / 2
            color: root.enabled ? Theme.accent : Theme.textDisabled
            border.width: root.activeFocus ? 1 : 0
            border.color: Theme.textPrimary
        }
        Shared.StylePaint {
            anchors.fill: parent
            visible: !Theme.legacy
            tokens: Theme.tokens
            role: "button"
            radius: width / 2
            customColor: root.enabled ? Theme.accent : Theme.textDisabled
            interaction: ({ pressed: root.pressed, focused: root.activeFocus,
                enabled: root.enabled })
        }
    }
}
