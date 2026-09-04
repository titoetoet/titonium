pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Notifications
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root
    required property var notification

    width: 360
    implicitHeight: 120
    opacity: 0

    transform: Translate {
        id: toastSlide
        x: Motion.reduced ? 0 : 36
    }

    Shared.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusLarge
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.margins: Metrics.spacingLarge
        spacing: Metrics.spacingMedium

        Shared.SystemIcon {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            sourceName: root.notification.appIcon || ""
            fallbackName: "notifications"
            size: 28
            tone: "accent"
        }

        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            spacing: Metrics.spacingXSmall

            Shared.TextLabel {
                Layout.fillWidth: true
                text: root.notification.appName || I18n.tr("notification.toast.fallback_app")
                variant: "caption"
                tone: "secondary"
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                text: root.notification.summary || root.notification.appName
                    || I18n.tr("notification.toast.fallback_app")
                variant: "label"
                strong: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                visible: root.notification.body.length > 0
                text: root.notification.body
                variant: "body"
                tone: "secondary"
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 3
            }
        }

        Shared.Button {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            iconName: "close"
            size: "small"
            variant: "quiet"
            showFocusRing: false
            backgroundRadius: Metrics.radiusLarge
            accessibleName: I18n.tr("notification.toast.dismiss")
            onTriggered: root.dismiss()
        }
    }

    property bool dismissing: false

    function dismiss(): void {
        if (root.dismissing)
            return;
        root.dismissing = true;
        if (Motion.reduced) {
            NotificationService.dismiss(root.notification.id);
        } else {
            toastExit.start();
        }
    }

    ParallelAnimation {
        id: toastExit

        NumberAnimation {
            target: toastSlide
            property: "x"
            from: 0
            to: 48
            duration: 150
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root
            property: "opacity"
            from: 1
            to: 0
            duration: 130
            easing.type: Easing.InCubic
        }
        onFinished: NotificationService.dismiss(root.notification.id)
    }

    Behavior on opacity {
        enabled: !root.dismissing
        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
    }

    Timer {
        interval: Preferences.notifications.toastDuration
        repeat: false
        running: true
        onTriggered: NotificationService.expireToast(root.notification.id)
    }

    ParallelAnimation {
        id: toastEntrance
        running: !Motion.reduced

        NumberAnimation {
            target: toastSlide
            property: "x"
            from: 36
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: root.opacity = 1
}
