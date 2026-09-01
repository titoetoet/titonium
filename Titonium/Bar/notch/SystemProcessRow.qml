pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Applications
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var process
    required property string memoryText
    property int rank: 0

    readonly property bool hovered: hoverHandler.hovered
    readonly property real cpuUsage: Math.max(0, Number(root.process.cpuPercent) || 0)
    readonly property string cleanName: {
        const raw = String(root.process.name || "").trim();
        return raw.toLowerCase();
    }
    readonly property string executableName: {
        const raw = String(root.process.name || "").trim();
        return raw.length > 0 ? raw : I18n.tr("center_notch.monitoring.process");
    }
    readonly property string appTitle: {
        const lookedUp = ApplicationService.nameForAppId(root.cleanName);
        return lookedUp && lookedUp !== root.cleanName && lookedUp !== "Application"
            ? lookedUp : root.executableName;
    }
    readonly property string subtitle: Number(root.process.processCount) > 1
        ? root.appTitle + " · " + I18n.tr("center_notch.monitoring.process_count", {
            count: root.process.processCount
        }) : root.appTitle
    readonly property string iconSource: {
        const direct = ApplicationService.iconForAppId(root.cleanName);
        if (direct)
            return direct;
        const iconMap = {
            "chrome": "google-chrome",
            "google-chrome": "google-chrome",
            "code": "visual-studio-code",
            "obs64": "com.obsproject.Studio",
            "obs": "com.obsproject.Studio",
            "discord": "discord",
            "vlc": "vlc",
            "explorer": "system-file-manager",
            "ghostty": "com.mitchellh.ghostty",
            "antigravity-ide": "antigravity-ide",
            "chatgpt": "chatgpt"
        };
        const candidate = iconMap[root.cleanName] || root.cleanName;
        if (Quickshell.hasThemeIcon(candidate))
            return Quickshell.iconPath(candidate);
        return "";
    }

    Layout.fillWidth: true
    Layout.preferredHeight: 48
    Layout.minimumHeight: 48
    Accessible.name: root.appTitle
    Accessible.description: Math.round(root.process.cpuPercent) + "% · " + root.memoryText

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusSmall
        color: root.hovered ? Theme.surfaceInteractive : "transparent"
        border.width: root.hovered ? 1 : 0
        border.color: root.hovered ? Theme.borderStrong : "transparent"

        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
    }

    HoverHandler {
        id: hoverHandler
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 8

        // 1. Rank Number (1., 2., 3., ...)
        Shared.TextLabel {
            Layout.preferredWidth: 14
            text: root.rank > 0 ? (root.rank + ".") : ""
            variant: "body"
            tone: "secondary"
            color: root.hovered ? Theme.textPrimary : Theme.textSecondary
            font.pixelSize: 12
        }

        // 2. Circular Icon Container + Name & Subtitle
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: root.hovered ? Theme.surfaceInteractive : Theme.surface
                border.width: 1
                border.color: root.hovered ? Theme.borderStrong : Theme.border

                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                IconImage {
                    id: procIconImage
                    anchors.centerIn: parent
                    source: root.iconSource
                    implicitSize: 18
                    asynchronous: true
                    mipmap: true
                    visible: root.iconSource.length > 0 && status === Image.Ready
                }

                Shared.Icon {
                    anchors.centerIn: parent
                    visible: !procIconImage.visible
                    name: "terminal"
                    size: 16
                    tone: "accent"
                    accessibleName: root.appTitle
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: root.executableName
                    variant: "body"
                    strong: true
                    color: Theme.textPrimary
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: root.subtitle
                    variant: "caption"
                    tone: "secondary"
                    color: root.hovered ? Theme.textPrimary : Theme.textSecondary
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }

        // 3. CPU %
        Shared.TextLabel {
            Layout.preferredWidth: 46
            text: root.cpuUsage.toFixed(1) + "%"
            variant: "body"
            strong: true
            color: root.cpuUsage >= 90 ? Theme.danger
                : (root.cpuUsage >= 70 ? Theme.warning : Theme.accent)
            font.pixelSize: 12
            horizontalAlignment: Text.AlignRight
        }

        // 4. Memory
        Shared.TextLabel {
            Layout.preferredWidth: 56
            text: root.memoryText
            variant: "body"
            color: Theme.textPrimary
            font.pixelSize: 12
            horizontalAlignment: Text.AlignRight
        }

    }
}
