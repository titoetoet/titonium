pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.MediaSpectrum
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "CompactGeometry.js" as Geometry
import "MediaTitleRules.js" as TitleRules

Rectangle {
    id: root
    required property var snapshot
    property real monitorWidth: parent ? parent.width : 0
    property bool interactionEnabled: true
    property bool connected: false
    property bool backgroundVisible: true
    property bool mediaContentVisible: true
    readonly property rect mediaTitleBounds: Qt.rect(mediaTitle.mapToItem(root, 0, 0).x,
        mediaTitle.mapToItem(root, 0, 0).y, mediaTitle.width, mediaTitle.height)
    readonly property real shoulderSize: root.connected ? 18 : 0
    property var audioLevels: MediaSpectrumService.levels
    signal intentRequested(var intent)
    readonly property var compact: root.snapshot.compact || ({ idle: false,
        primary: root.snapshot.primary, secondary: root.snapshot.secondary })
    readonly property var primary: root.compact.primary
    readonly property var secondary: root.compact.secondary
    readonly property bool idle: root.compact.idle
    // An idle mascot owns hover; only an actual activity can request a preview.
    readonly property string hoveredPrimaryContextId: root.interactionEnabled && primaryHover.hovered && !root.idle
        ? root.primary?.id || "" : ""
    onHoveredPrimaryContextIdChanged: root.intentRequested({
        type: root.hoveredPrimaryContextId ? "preview-enter" : "preview-leave",
        region: "primary", contextId: root.hoveredPrimaryContextId })
    property var privacyContext: null
    readonly property bool privacyMenuVisible: privacyMenu.visible
    readonly property var privacyActions: (root.snapshot.capabilities?.actions || []).filter(
        action => action.contextId === root.privacyContext?.id && action.enabled === true)
    onCompactChanged: {
        if (root.privacyContext && ![root.compact.primary, root.compact.secondary].some(
                item => item?.id === root.privacyContext.id && item.occurredAt === root.privacyContext.occurredAt))
            privacyMenu.close();
    }
    onInteractionEnabledChanged: { if (!root.interactionEnabled) privacyMenu.close(); }
    Menu {
        id: privacyMenu
        popupType: Popup.Window
        implicitWidth: 220
        padding: 6
        background: Item {
            Rectangle {
                anchors.fill: parent
                visible: Theme.legacy
                color: Theme.surface
                radius: 8
                border.color: Theme.border
            }
            Shared.StylePaint {
                anchors.fill: parent
                visible: !Theme.legacy
                tokens: Theme.tokens
                role: "surface"
                radius: 8
            }
        }
        Instantiator {
            model: root.privacyActions
            delegate: MenuItem {
                id: actionItem
                required property var modelData
                implicitHeight: 34
                text: modelData.label
                contentItem: Shared.TextLabel {
                    text: actionItem.text
                    color: actionItem.modelData.role === "destructive" ? Theme.danger : Theme.textPrimary
                    verticalAlignment: Text.AlignVCenter
                }
                background: Item {
                    Rectangle {
                        anchors.fill: parent
                        visible: Theme.legacy
                        color: Theme.textPrimary
                        radius: 5
                        opacity: actionItem.highlighted ? 0.1 : 0
                    }
                    Shared.StylePaint {
                        anchors.fill: parent
                        visible: !Theme.legacy
                        tokens: Theme.tokens
                        role: "menu-row"
                        radius: 5
                        outlined: false
                        interaction: ({ hovered: actionItem.highlighted,
                            enabled: actionItem.enabled })
                    }
                }
                onTriggered: root.intentRequested({ type: "compact-privacy-action",
                    contextId: root.privacyContext.id, occurredAt: root.privacyContext.occurredAt,
                    actionId: modelData.id })
            }
            onObjectAdded: (index, object) => privacyMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => privacyMenu.removeItem(object)
        }
        MenuItem {
            visible: root.privacyActions.length === 0
            height: visible ? implicitHeight : 0
            enabled: false
            text: I18n.tr("center.privacy.no_actions")
        }
    }
    property double now: Date.now()
    readonly property string numericValue: root.primary?.details?.feedbackKind ? "" : root.primary?.source === "focus"
        ? Geometry.duration((Number(root.primary.details?.deadline || 0) - root.now) / 1000)
        : root.primary?.source === "capture" && root.primary?.kind !== "screenshot" ? Geometry.duration((root.now - root.primary.occurredAt) / 1000)
        : ""
    readonly property string primaryLabel: root.primary?.details?.feedbackKind
        ? I18n.tr(root.primary.details.feedbackKind === "screenshot_saved" ? "capture.screenshot_saved" : "capture.recording_started")
        : root.primary?.source === "media"
        ? TitleRules.formatSongDisplay(root.primary.title, root.primary.subtitle) || I18n.tr("menubar.center.media_unknown") : root.primary?.title || ""
    readonly property rect visualBounds: Qt.rect(root.x - root.shoulderSize,
        root.y - (root.connected ? 4 : 0), root.width + root.shoulderSize * 2,
        root.height + (root.connected ? 4 : 0))
    implicitWidth: Geometry.widthFor(root.monitorWidth, root.height,
        (root.primary?.source === "media" ? Math.min(200, labelMetrics.advanceWidth) : labelMetrics.advanceWidth) + 28 + (root.numericValue ? numericMetrics.advanceWidth + 8 : 0),
        !!root.secondary, root.idle)
    width: implicitWidth
    height: Math.max(24, Metrics.barHeight - 8)
    radius: height / 2
    color: Theme.legacy && !root.connected ? Theme.surface : "transparent"
    border.color: Theme.border
    border.width: Theme.legacy && !root.connected ? 1 : 0
    readonly property bool dogVisible: root.idle && Preferences.bar.mascotEnabled !== false
        && Preferences.bar.mascot === "dog"
    clip: !root.connected && !root.dogVisible
    Behavior on width { NumberAnimation { duration: Motion.reduced ? 0 : 220; easing.type: Easing.OutCubic } }
    Shared.StylePaint {
        anchors.fill: parent
        visible: !Theme.legacy && !root.connected && root.backgroundVisible
        tokens: Theme.tokens
        role: "surface"
        radius: root.radius
    }
    Shared.ConnectedPillShape {
        objectName: "connectedCompactNotch"
        visible: root.connected && root.backgroundVisible
        x: -root.shoulderSize
        y: -4
        bodyWidth: root.width
        bodyHeight: root.height + 4
        shoulderSize: root.shoulderSize
        bottomRadius: 18
        color: Theme.centerSurface
    }
    TextMetrics { id: labelMetrics; font: root.primary?.source === "media" ? mediaTitle.font : titleLabel.font; text: root.primaryLabel }
    TextMetrics { id: numericMetrics; font: numberLabel.font; text: root.numericValue.replace(/[0-9]/g, "0") }
    Timer {
        interval: 1000
        running: root.visible && (root.primary?.source === "focus" || root.primary?.source === "capture")
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }
    IdleMascot {
        z: 1
        anchors.centerIn: parent
        width: parent.width - 12
        height: parent.height
        visible: root.idle && Preferences.bar.mascotEnabled !== false
        hovered: primaryHover.hovered
        templateId: Preferences.bar.mascot || "pig"
    }
    Item {
        id: primaryTarget
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(0, parent.width - (root.secondary ? parent.height : 0))
        enabled: root.interactionEnabled
        Accessible.role: Accessible.Button
        Accessible.name: root.idle ? I18n.tr("center.idle.open") : root.primaryLabel
        Accessible.onPressAction: root.intentRequested({ type: "activate-compact" })
        activeFocusOnTab: true
        Keys.onReturnPressed: root.intentRequested({ type: "activate-compact" })
        Keys.onSpacePressed: root.intentRequested({ type: "activate-compact" })
        Shared.InteractionFeedback {
            anchors.fill: parent
            radius: root.radius
            hovered: !root.idle && primaryHover.hovered
            pressed: primaryTap.pressed
            focused: primaryTarget.activeFocus
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.height * 0.4
            anchors.rightMargin: 8
            spacing: 8
            visible: !root.idle
            CompactActivityIcon {
                context: root.primary
                opacity: root.primary?.source === "media" && !root.mediaContentVisible ? 0 : 1
                audioLevels: root.audioLevels
                Layout.preferredWidth: 24; Layout.preferredHeight: 24
            }
            CompactMediaTitle {
                id: mediaTitle
                objectName: "compactMediaInk"
                opacity: root.mediaContentVisible ? 1 : 0
                visible: root.primary?.source === "media"
                Layout.fillWidth: true
                Layout.maximumWidth: 200
                text: root.primaryLabel
                playing: root.mediaContentVisible && root.primary?.details?.playing === true
                engaged: root.mediaContentVisible && (primaryHover.hovered || primaryTarget.activeFocus)
            }
            Shared.TextLabel {
                id: titleLabel
                visible: root.primary?.source !== "media"
                Layout.fillWidth: true
                text: root.primaryLabel
                elide: Text.ElideRight
            }
            Shared.TextLabel {
                id: numberLabel
                visible: root.numericValue.length > 0
                Layout.preferredWidth: numericMetrics.advanceWidth
                text: root.numericValue
                font.family: Typography.monoFamily
                font.features: ({ "tnum": 1 })
            }
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            enabled: root.primary?.source === "capture" && root.primary?.kind !== "screenshot"
            onTapped: root.openPrivacy(root.primary, primaryTarget)
        }
        WheelHandler {
            enabled: root.interactionEnabled && root.primary?.source === "media"
            onWheel: event => root.adjustVolume(root.primary, event.angleDelta.y)
        }
        HoverHandler {
            id: primaryHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: primaryTap
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.intentRequested({ type: "activate-compact" })
        }
    }
    Item {
        id: satelliteTarget
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.secondary ? parent.height : 0
        visible: !!root.secondary
        enabled: root.interactionEnabled
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: I18n.tr("center.compact.open", { title: root.secondary?.title || "" })
        Accessible.onPressAction: root.openSatellite()
        Keys.onReturnPressed: root.openSatellite()
        Keys.onSpacePressed: root.openSatellite()
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: height / 2
            color: Theme.textPrimary
            opacity: 0.05
        }
        Shared.InteractionFeedback {
            anchors.fill: parent
            anchors.margins: 4
            radius: height / 2
            hovered: satelliteHover.hovered
            pressed: satelliteTap.pressed
            focused: satelliteTarget.activeFocus
        }
        CompactActivityIcon {
            anchors.centerIn: parent
            width: 24; height: 24
            context: root.secondary
            audioLevels: root.audioLevels
            satellite: true
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            enabled: root.secondary?.source === "capture"
            onTapped: root.openPrivacy(root.secondary, satelliteTarget)
        }
        WheelHandler {
            enabled: root.interactionEnabled && root.secondary?.source === "media"
            onWheel: event => root.adjustVolume(root.secondary, event.angleDelta.y)
        }
        HoverHandler {
            id: satelliteHover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: root.intentRequested({ type: hovered ? "preview-enter" : "preview-leave",
                region: "satellite", contextId: root.secondary?.id || "" })
        }
        TapHandler { id: satelliteTap; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: root.openSatellite() }
    }
    CompactActivityIcon {
        objectName: "persistentRecordingIndicator"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 3
        width: 12; height: 12
        visible: !!root.compact.recordingIndicator
        context: root.compact.recordingIndicator || null
    }
    function openPrivacy(context: var, target: Item): void {
        root.privacyContext = context;
        privacyMenu.popup(target, 0, target.height);
    }
    function adjustVolume(context: var, angle: real): void {
        if (context?.source === "media" && angle !== 0)
            root.intentRequested({ type: "compact-volume", contextId: context.id,
                identity: context.details?.identity || "", delta: angle / 120 * 0.05 });
    }
    function openSatellite(): void {
        if (root.secondary) root.intentRequested({ type: "activate-compact", contextId: root.secondary.id });
    }
}
