pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces.Center
import Quickshell
import qs.Titonium.Bar.islands
import qs.Titonium.Overlays.SystemTray
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "EdgeMenuGeometry.js" as EdgeMenuGeometry
import "RightPillState.js" as RightPillState

FocusScope {
    id: root

    required property ShellScreen screenModel
    required property real compactY
    signal notificationsRequested(var screen, var invoker)
    readonly property bool ownsConnectedSurface:
        RightPillCoordinator.connectedSurfacePresented
        && RightPillCoordinator.connectedScreen === root.screenModel
    readonly property bool ownsMenu: root.ownsConnectedSurface
        || RightPillCoordinator.ownerScreenName === root.screenModel.name
    readonly property bool closing:
        RightPillCoordinator.exitingScreenName === root.screenModel.name
        || (root.ownsConnectedSurface && RightPillCoordinator.connectedClosing)
    readonly property string presentedEdge: root.ownsConnectedSurface ? "right"
        : (root.ownsMenu ? RightPillCoordinator.activeEdge : RightPillCoordinator.exitingEdge)
    readonly property real presentedProgress: root.ownsMenu || root.closing
        ? RightPillCoordinator.transitionProgress : 0
    readonly property rect connectivityAnchor: root.ownsConnectedSurface
        ? root.connectedAnchorRect(
            RightPillCoordinator.connectedDescriptor?.anchor || "")
        : Qt.rect(0, 0, 0, 0)
    readonly property real activeContentHeight: root.ownsConnectedSurface
        ? connectedLoader.implicitHeight : menuView.implicitContentHeight
    readonly property real activeContentWidth: root.ownsConnectedSurface
        ? connectedLoader.implicitWidth : menuView.implicitContentWidth
    readonly property real targetMenuHeight: RightPillState.menuHeight(
        root.activeContentHeight, root.height)
    readonly property real leftTargetMenuWidth: RightPillState.menuWidth(
        menuView.implicitContentWidth, root.leftSourceWidth)
    readonly property real rightTargetMenuWidth: root.ownsConnectedSurface
        ? Math.max(240, Math.min(520,
            Math.max(root.activeContentWidth, root.rightSourceWidth)))
        : RightPillState.menuWidth(menuView.implicitContentWidth, root.rightSourceWidth)
    readonly property real liveLeftSourceX: leftContent.menuAnchorX
    readonly property real liveRightSourceX: root.ownsConnectedSurface
        ? rightContent.x + root.connectivityAnchor.x
        : rightContent.x + rightContent.menuAnchorX
    readonly property real liveRightSourceWidth: root.ownsConnectedSurface
        ? Math.max(1, root.connectivityAnchor.width) : rightContent.menuAnchorWidth
    property real frozenLeftSourceX: 0
    property real frozenLeftSourceWidth: 1
    property real frozenRightSourceX: 0
    property real frozenRightSourceWidth: 1
    readonly property real leftSourceX: root.presentedEdge === "left"
        ? root.frozenLeftSourceX : root.liveLeftSourceX
    readonly property real leftSourceWidth: root.presentedEdge === "left"
        ? root.frozenLeftSourceWidth : leftContent.menuAnchorWidth
    readonly property real rightSourceX: root.presentedEdge === "right"
        ? root.frozenRightSourceX : root.liveRightSourceX
    readonly property real rightSourceWidth: root.presentedEdge === "right"
        ? root.frozenRightSourceWidth : root.liveRightSourceWidth
    readonly property var leftMenuBounds: EdgeMenuGeometry.branchRect("left",
        root.leftSourceX, root.leftSourceWidth,
        RightPillCoordinator.leftCompactWidth, root.width, root.leftTargetMenuWidth,
        root.targetMenuHeight, 1)
    readonly property var rightMenuBounds: EdgeMenuGeometry.branchRect("right",
        root.rightSourceX, root.rightSourceWidth,
        RightPillCoordinator.rightCompactWidth, root.width, root.rightTargetMenuWidth,
        root.targetMenuHeight, 1)
    readonly property real leftSourceOffset: root.presentedEdge === "left"
        ? EdgeMenuGeometry.sourceOffset(root.leftSourceX, root.leftSourceWidth,
            root.leftMenuBounds, root.presentedProgress) : 0
    readonly property real rightSourceOffset: root.presentedEdge === "right"
        ? EdgeMenuGeometry.sourceOffset(root.rightSourceX, root.rightSourceWidth,
            root.rightMenuBounds, root.presentedProgress) : 0
    readonly property var leftBranch: EdgeMenuGeometry.branchRect("left",
        root.leftSourceX, root.leftSourceWidth,
        RightPillCoordinator.leftCompactWidth, root.width, root.leftTargetMenuWidth,
        root.targetMenuHeight, root.presentedEdge === "left" ? root.presentedProgress : 0)
    readonly property var rightBranch: EdgeMenuGeometry.branchRect("right",
        root.rightSourceX, root.rightSourceWidth,
        RightPillCoordinator.rightCompactWidth, root.width, root.rightTargetMenuWidth,
        root.targetMenuHeight, root.presentedEdge === "right" ? root.presentedProgress : 0)
    readonly property var activeBranch: root.presentedEdge === "left"
        ? root.leftBranch : root.rightBranch
    readonly property real presentedLeftCompactWidth: {
        const compact = RightPillCoordinator.leftCompactWidth;
        if (root.presentedEdge !== "left")
            return compact;
        const target = root.leftMenuBounds.x + root.leftMenuBounds.width + 16;
        return compact + (target - compact) * root.presentedProgress;
    }
    readonly property real presentedRightCompactWidth: {
        const compact = RightPillCoordinator.rightCompactWidth;
        if (root.presentedEdge !== "right")
            return compact;
        const target = root.width - root.rightMenuBounds.x + 16;
        return compact + (target - compact) * root.presentedProgress;
    }
    readonly property real presentedRightCompactX: root.width
        - root.presentedRightCompactWidth

    anchors.fill: parent
    focus: root.ownsMenu

    function closePresentedMenu(): void {
        if (root.ownsConnectedSurface)
            RightPillCoordinator.closeConnectedSurface();
        else
            RightPillCoordinator.close();
    }

    function connectedAnchorRect(name: string): rect {
        if (name === "notifications")
            return rightContent.anchorRect(name);
        return rightContent.connectivityAnchorRect(name);
    }

    function freezeRightAnchor(): void {
        root.frozenRightSourceX = root.liveRightSourceX;
        root.frozenRightSourceWidth = root.liveRightSourceWidth;
    }

    onOwnsMenuChanged: {
        if (root.ownsMenu) {
            root.frozenLeftSourceX = root.liveLeftSourceX;
            root.frozenLeftSourceWidth = leftContent.menuAnchorWidth;
            root.freezeRightAnchor();
        }
    }

    Connections {
        target: RightPillCoordinator
        function onConnectedGenerationChanged(): void {
            if (root.ownsConnectedSurface)
                root.freezeRightAnchor();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        visible: root.ownsMenu
        TapHandler {
            enabled: root.ownsMenu
            onTapped: eventPoint => {
                const point = eventPoint.position;
                const centerWidth = 220;
                const inCenter = point.x >= (root.width - centerWidth) / 2
                    && point.x <= (root.width + centerWidth) / 2
                    && point.y <= 40;
                if (inCenter) {
                    CenterSurfaceController.dispatch({ type: "request-open",
                        screenName: root.screenModel.name, mode: "expanded" });
                    return;
                }
                const inLeft = point.x <= root.presentedLeftCompactWidth
                    && point.y <= 36;
                const inRight = point.x >= root.presentedRightCompactX
                    && point.y <= 36;
                const branch = root.activeBranch;
                const inBranch = point.x >= branch.x && point.x <= branch.x + branch.width
                    && point.y >= branch.y && point.y <= branch.y + branch.height;
                if (RightPillState.shouldDismissTap(root.presentedEdge,
                        inLeft, inRight, inBranch))
                    root.closePresentedMenu();
            }
        }
    }

    Shared.AnchoredMenuPillShape {
        x: 0
        y: root.ownsMenu || root.closing ? 0 : root.compactY
        width: root.width
        height: root.height - y
        edge: "left"
        compactX: 0
        compactWidth: root.presentedLeftCompactWidth
        branchX: root.leftBranch.x
        branchY: root.leftBranch.y
        branchWidth: root.leftBranch.width
        branchHeight: root.leftBranch.height
        color: Theme.light ? "#ffffff" : "#0d0e12"
    }

    Shared.AnchoredMenuPillShape {
        x: 0
        y: root.ownsMenu || root.closing ? 0 : root.compactY
        width: root.width
        height: root.height - y
        edge: "right"
        compactX: root.presentedRightCompactX
        compactWidth: root.presentedRightCompactWidth
        branchX: root.rightBranch.x
        branchY: root.rightBranch.y
        branchWidth: root.rightBranch.width
        branchHeight: root.rightBranch.height
        color: Theme.light ? "#ffffff" : "#0d0e12"
    }

    // Keep the menu body independent from the shoulder path. The body overlaps
    // the compact pill by 8px, so both pieces remain one connected surface even
    // when the native Shape renderer drops the tall concave section.
    Rectangle {
        x: root.activeBranch.x
        y: root.activeBranch.y
        width: root.activeBranch.width
        height: root.activeBranch.height
        visible: root.presentedProgress > 0
        radius: Math.max(0, Math.min(20, width / 2, height / 2))
        color: Theme.light ? "#ffffff" : "#0d0e12"
    }

    StartIsland {
        id: leftContent
        z: 2
        x: 0
        y: root.compactY
        width: Math.max(0, RightPillCoordinator.leftCompactWidth - 16)
        height: 36
        screen: root.screenModel
        menuAnchorOffset: root.leftSourceOffset
    }

    EndIsland {
        id: rightContent
        z: 2
        anchors.right: parent.right
        y: root.compactY
        width: Math.max(0, RightPillCoordinator.rightCompactWidth - 16)
        height: 36
        screen: root.screenModel
        menuAnchorOffset: root.ownsConnectedSurface ? 0
            : root.rightSourceOffset
        onNotificationsRequested: (screen, invoker) =>
            root.notificationsRequested(screen, invoker)
    }

    Item {
        id: menuClip
        x: root.activeBranch.x
        y: root.activeBranch.y
        width: root.activeBranch.width
        height: root.activeBranch.height
        clip: true
        visible: root.presentedProgress > 0

        SystemTrayMenuView {
            id: menuView
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 20
            anchors.bottomMargin: 16
            opacity: RightPillState.contentOpacity(root.presentedProgress, "menu")
            visible: !root.ownsConnectedSurface
            enabled: root.ownsMenu && root.presentedProgress > 0.7
            transform: Translate { y: (1 - menuView.opacity) * 8 }
            onDismissRequested: RightPillCoordinator.close()
        }

        Loader {
            id: connectedLoader
            property string loadOwnerId: ""
            property int loadGeneration: 0
            property var loadDescriptor: null
            property var loadScreen: null

            function captureSnapshot(): void {
                if (!root.ownsConnectedSurface)
                    return;
                loadOwnerId = RightPillCoordinator.connectedOwnerId;
                loadGeneration = RightPillCoordinator.connectedGeneration;
                loadDescriptor = RightPillCoordinator.connectedDescriptor;
                loadScreen = RightPillCoordinator.connectedScreen;
            }

            function clearSnapshot(): void {
                loadOwnerId = "";
                loadGeneration = 0;
                loadDescriptor = null;
                loadScreen = null;
            }

            function releaseSnapshot(): void {
                RightPillCoordinator.releaseConnectedSurface(loadOwnerId, loadGeneration,
                    loadDescriptor, loadScreen);
                clearSnapshot();
            }

            anchors.fill: parent
            active: root.ownsConnectedSurface
            source: active ? RightPillCoordinator.connectedDescriptor.source : ""
            opacity: RightPillState.contentOpacity(root.presentedProgress, "menu")
            enabled: !RightPillCoordinator.connectedClosing
                && root.ownsConnectedSurface && root.presentedProgress > 0.7
            transform: Translate { y: (1 - connectedLoader.opacity) * 8 }

            onStatusChanged: {
                if (status === Loader.Loading)
                    captureSnapshot();
                else if (status === Loader.Error)
                    releaseSnapshot();
            }
            onActiveChanged: {
                if (active)
                    captureSnapshot();
                else
                    clearSnapshot();
            }
        }

        Binding {
            target: connectedLoader.item || null
            property: "availableViewportHeight"
            value: menuClip.height
            when: connectedLoader.item !== null
                && connectedLoader.item.hasOwnProperty("availableViewportHeight")
        }

        Connections {
            target: connectedLoader.item
            ignoreUnknownSignals: true
            function onDismissRequested(): void {
                root.closePresentedMenu();
            }
        }
    }

    Binding {
        target: RightPillCoordinator
        property: "leftHovered"
        value: leftHover.hovered
    }
    Binding {
        target: RightPillCoordinator
        property: "rightHovered"
        value: rightHover.hovered
    }
    Item {
        anchors.fill: leftContent
        HoverHandler { id: leftHover; enabled: !root.ownsMenu }
    }
    Item {
        anchors.fill: rightContent
        HoverHandler { id: rightHover; enabled: !root.ownsMenu }
    }

    Keys.onEscapePressed: event => {
        if (root.ownsMenu) {
            root.closePresentedMenu();
            event.accepted = true;
        }
    }
}
