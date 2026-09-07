pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

ColumnLayout {
    id: root
    required property var tokens
    property var overrides: ({})
    property string editMode: "dark"
    property bool reducedMotion: false
    property real configuredMotionScale: tokens.motionScale || 1
    signal fieldEdited(string key, var value)
    signal fieldReset(string key)
    signal resetAll()
    signal reducedMotionEdited(bool value)
    spacing: Metrics.spacingMedium
    readonly property var fields: [
        {key: "backgroundOpacity", label: "settings.appearance.opacity", min: 0.85, max: 1},
        {key: "borderStrength", label: "settings.appearance.border", min: 0, max: 1},
        {key: "shadowStrength", label: "settings.appearance.shadow", min: 0, max: 1},
        {key: "sheenStrength", label: "settings.appearance.sheen", min: 0, max: 1},
        {key: "radiusScale", label: "settings.appearance.radius", min: 0.75, max: 1.25},
        {key: "motionScale", label: "settings.appearance.motion", min: 0.5, max: 1.5}
    ]
    function fieldEnabled(key: string): bool {
        if (key === "motionScale") return !root.reducedMotion;
        if (tokens.legacy !== false) return true;
        const id = tokens.design?.renderer || "modern-flat";
        if (key === "backgroundOpacity") return id === "glassmorphism" || id === "liquid-glass";
        if (key === "shadowStrength") return id !== "modern-flat";
        if (key === "sheenStrength") return id === "glassmorphism" || id === "liquid-glass";
        return true;
    }
    function fieldValue(key: string): real {
        if (overrides[key] !== undefined) return overrides[key];
        if (key === "motionScale") return configuredMotionScale;
        return tokens.material?.[key] ?? 1;
    }
    Shared.TextLabel {
        Layout.fillWidth: true
        text: I18n.tr("settings.appearance.edit_mode", {mode: I18n.tr("settings.appearance." + root.editMode)})
        tone: "secondary"; wrapMode: Text.WordWrap
    }
    RowLayout {
        Layout.fillWidth: true
        Shared.TextLabel { Layout.fillWidth: true; text: I18n.tr("settings.appearance.accent") }
        Controls.TextField {
            id: accentInput
            objectName: "accentInput"
            Layout.preferredWidth: 126
            text: root.overrides.accent || root.tokens.colors?.accent || "#5b9cff"
            color: Theme.textPrimary
            selectByMouse: true
            maximumLength: 7
            validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}/ }
            Accessible.name: I18n.tr("settings.appearance.accent")
            onEditingFinished: {
                if (acceptableInput) root.fieldEdited("accent", text.toUpperCase());
            }
            background: Rectangle {
                radius: Metrics.radiusSmall; color: Theme.surfaceElevated
                border.width: 1
                border.color: accentInput.activeFocus ? Theme.focus : Theme.border
            }
        }
        Shared.Button {
            size: "small"; iconName: "restart_alt"
            accessibleName: I18n.tr("settings.appearance.reset_field", {field: I18n.tr("settings.appearance.accent")})
            enabled: root.overrides.accent !== undefined
            onTriggered: root.fieldReset("accent")
        }
    }
    Repeater {
        model: root.fields
        RowLayout {
            id: fieldRow
            required property var modelData
            Layout.fillWidth: true
            Shared.TextLabel { Layout.fillWidth: true; text: I18n.tr(fieldRow.modelData.label) }
            Shared.TextLabel {
                Layout.preferredWidth: 44
                text: Math.round(root.fieldValue(fieldRow.modelData.key) * 100) + "%"
                tone: "secondary"
            }
            Shared.Slider {
                objectName: fieldRow.modelData.key + "Slider"
                Layout.preferredWidth: 155
                from: fieldRow.modelData.min; to: fieldRow.modelData.max; stepSize: 0.01
                value: root.fieldValue(fieldRow.modelData.key)
                enabled: root.fieldEnabled(fieldRow.modelData.key)
                accessibleName: I18n.tr(fieldRow.modelData.label)
                onMoved: value => root.fieldEdited(fieldRow.modelData.key, value)
            }
            Shared.Button {
                size: "small"; iconName: "restart_alt"
                accessibleName: I18n.tr("settings.appearance.reset_field", {field: I18n.tr(fieldRow.modelData.label)})
                enabled: root.overrides[fieldRow.modelData.key] !== undefined
                onTriggered: root.fieldReset(fieldRow.modelData.key)
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Shared.TextLabel { Layout.fillWidth: true; text: I18n.tr("settings.appearance.reduced_motion") }
        Shared.Toggle {
            checked: root.reducedMotion
            accessibleName: I18n.tr("settings.appearance.reduced_motion")
            onToggled: checked => root.reducedMotionEdited(checked)
        }
    }
    Shared.TextLabel {
        Layout.fillWidth: true
        text: I18n.tr("settings.appearance.reduced_motion_hint")
        tone: "secondary"; variant: "bodySmall"; wrapMode: Text.WordWrap
    }
    Shared.Button {
        label: I18n.tr("settings.appearance.reset_theme")
        iconName: "restart_alt"
        onTriggered: root.resetAll()
    }
}
