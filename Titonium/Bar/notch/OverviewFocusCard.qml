pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Shared.Surface {
    id: root
    property bool editing: false
    tone: "elevated"
    radius: Metrics.radiusMedium
    padding: Metrics.spacingMedium
    Accessible.name: I18n.tr("center_notch.overview.focus.title")

    function beginEditing(): void {
        focusInput.text = CenterFocusStore.text;
        root.editing = true;
        Qt.callLater(() => {
            focusInput.forceActiveFocus(Qt.MouseFocusReason);
            focusInput.selectAll();
        });
    }

    function cancelEditing(): void {
        root.editing = false;
        focusInput.text = CenterFocusStore.text;
    }

    function commitEditing(): void {
        if (CenterFocusStore.saveToday(focusInput.text))
            root.editing = false;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSmall
            Shared.Icon {
                name: "center_focus_strong"
                size: 20
                tone: "accent"
                accessibleName: I18n.tr("center_notch.overview.focus.title")
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("center_notch.overview.focus.title").toUpperCase()
                variant: "label"
                strong: true
                font.letterSpacing: 0.4
            }
            Shared.Button {
                visible: !root.editing
                iconName: "edit"
                size: "small"
                variant: "quiet"
                accessibleName: I18n.tr("center_notch.overview.focus.edit")
                onTriggered: root.beginEditing()
            }
            Shared.Button {
                visible: !root.editing
                iconName: "open_in_new"
                size: "small"
                variant: "quiet"
                accessibleName: I18n.tr("center_notch.overview.daily_focus.open")
                onTriggered: CenterFocusStore.openScratchpad()
            }
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.editing
            text: CenterFocusStore.text
            variant: "bodyLarge"
            strong: true
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.editing
            spacing: Metrics.spacingXSmall
            QtControls.TextField {
                id: focusInput
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: Theme.textPrimary
                placeholderText: I18n.tr("center_notch.overview.focus.placeholder")
                placeholderTextColor: Theme.textSecondary
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                font.family: Typography.family
                font.pixelSize: Typography.bodyLargeSize
                leftPadding: Metrics.spacingMedium
                rightPadding: Metrics.spacingMedium
                background: Rectangle {
                    radius: Metrics.radiusSmall
                    color: Theme.surfaceInteractive
                    border.width: Metrics.borderWidth
                    border.color: focusInput.activeFocus ? Theme.focus : Theme.border
                }
                Accessible.name: I18n.tr("center_notch.overview.focus.placeholder")
                onAccepted: root.commitEditing()
                Keys.onEscapePressed: event => {
                    root.cancelEditing();
                    event.accepted = true;
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Metrics.spacingXSmall
                Shared.Button {
                    label: I18n.tr("center_notch.overview.focus.cancel")
                    size: "small"
                    variant: "quiet"
                    onTriggered: root.cancelEditing()
                }
                Shared.Button {
                    label: I18n.tr("center_notch.overview.focus.save")
                    iconName: "check"
                    size: "small"
                    variant: "primary"
                    enabled: !CenterFocusStore.saveInProgress
                    onTriggered: root.commitEditing()
                }
            }
        }
    }
}
