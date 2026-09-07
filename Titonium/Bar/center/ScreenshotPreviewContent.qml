pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root
    required property var context
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingLarge
        spacing: Metrics.spacingSmall

        Shared.TextLabel {
            Layout.fillWidth: true
            text: root.context?.title || ""
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Image {
                id: previewImage
                objectName: "screenshotPreviewImage"
                anchors.fill: parent
                source: root.context?.details?.imageUrl || ""
                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectFit
                sourceSize.width: Math.max(1, Math.ceil(width))
                sourceSize.height: Math.max(1, Math.ceil(height))
                visible: status === Image.Ready
            }
            Shared.TextLabel {
                objectName: "screenshotPreviewStatus"
                anchors.centerIn: parent
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                tone: "secondary"
                visible: previewImage.status !== Image.Ready
                text: I18n.tr(previewImage.status === Image.Loading
                    ? "capture.preview_loading" : "capture.preview_unavailable")
            }
        }
    }
}
