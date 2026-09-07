pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    readonly property bool pinned: Preferences.bar.autoHide !== true
    property bool revealed: root.pinned

    property var centerHoverByScreen: ({})

    function centerHovered(screenName: string): bool {
        return root.centerHoverByScreen[screenName] === true;
    }

    function setCenterHovered(screenName: string, hovered: bool): void {
        if (!screenName || root.centerHovered(screenName) === hovered)
            return;
        const next = Object.assign({}, root.centerHoverByScreen);
        if (hovered) next[screenName] = true;
        else delete next[screenName];
        root.centerHoverByScreen = next;
    }

    signal hideRequested()

    function setRevealed(value: bool): void {
        root.revealed = value;
    }

    function togglePinned(): bool {
        const nextAutoHide = root.pinned;
        const changed = Preferences.previewActive
            ? Preferences.patch("modules.bar.autoHide", nextAutoHide)
            : Preferences.commitPatch("modules.bar.autoHide", nextAutoHide);
        if (changed && nextAutoHide)
            root.hideRequested();
        return changed;
    }
}
