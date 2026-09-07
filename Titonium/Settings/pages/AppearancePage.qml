pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import qs.Titonium.Settings
import qs.Titonium.Settings.components
import qs.Titonium.Services.Appearance
import qs.Titonium.Services.Wallpapers

Item {
    id: root
    objectName: "appearancePage"
    readonly property var appearance: AppearanceCoordinator.candidate.appearance || ({})
    readonly property string mode: appearance.mode || "dark"
    readonly property string themeId: appearance.themeId || "neutral"
    property string previewLayout: Preferences.effectiveState.modules?.bar?.style || "connected"
    readonly property var selectedDescriptor: AppearanceService.themeDescriptor(root.themeId)
    readonly property bool hasThemeWallpaper: !!selectedDescriptor?.wallpapers?.[AppearanceCoordinator.tokens.mode]
    readonly property bool missingThemeWallpaper: root.wallpaper.policy === "theme" && !root.hasThemeWallpaper
    readonly property var wallpaperOptions: {
        const options = [{label:I18n.tr("settings.appearance.wallpaper_keep"),value:"keep"}];
        if (root.hasThemeWallpaper) options.push({label:I18n.tr("settings.appearance.wallpaper_theme"),value:"theme"});
        options.push({label:I18n.tr("settings.appearance.wallpaper_custom"),value:"custom"});
        return options;
    }
    readonly property var wallpaper: appearance.wallpaper || ({policy: "keep", customPath: ""})
    readonly property var overrides: appearance.themeOverrides?.[themeId]?.[AppearanceCoordinator.editMode] || ({})
    readonly property var advancedAppearance: Object.assign({}, root.appearance, {mode: AppearanceCoordinator.editMode})
    readonly property var advancedTokens: AppearanceService.resolveCandidate({
        appearance: root.advancedAppearance, reducedMotion: AppearanceCoordinator.candidate.reducedMotion})
    readonly property string committedTheme: Preferences.committedState.appearance?.themeId || "neutral"
    readonly property bool editable: !AppearanceCoordinator.busy && !AppearanceCoordinator.trialActive
        && !AppearanceCoordinator.finalizationPending
    // A shared demo palette makes material differences comparable across cards.
    function cardTokens(id: string): var {
        const mode = AppearanceCoordinator.tokens.mode;
        const value = AppearanceService.resolveCandidate({appearance:{mode:mode,themeId:id},reducedMotion:true});
        const palette = AppearanceService.resolveCandidate({appearance:{mode:mode,themeId:"modern-flat"},reducedMotion:true});
        return Object.assign({}, value, {colors:palette.colors});
    }
    readonly property var modes: [
        {id: "dark", key: "settings.appearance.dark", icon: "dark_mode"},
        {id: "light", key: "settings.appearance.light", icon: "light_mode"},
        {id: "system", key: "settings.appearance.system", icon: "desktop_windows"}
    ]
    readonly property url previewWallpaper: {
        if (wallpaper.policy === "custom" && wallpaper.customPath)
            return "file://" + wallpaper.customPath.split("/").map(encodeURIComponent).join("/");
        if (wallpaper.policy === "theme") {
            const descriptor = AppearanceService.themeDescriptor(root.themeId);
            const path = descriptor?.wallpapers?.[AppearanceCoordinator.tokens.mode] || "";
            return path ? Qt.resolvedUrl("../../../" + path) : "";
        }
        return "";
    }
    Keys.onEscapePressed: event => {
        if (AppearanceCoordinator.trialActive) {
            AppearanceCoordinator.cancelTrial(); event.accepted = true;
        } else event.accepted = false;
    }
    Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar {}
        ColumnLayout {
            id: content
            width: scroll.width - 12
            spacing: Metrics.spacingMedium
            Shared.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("settings.appearance.description")
                tone: "secondary"; wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: root.modes
                    Shared.Button {
                        required property var modelData
                        Layout.fillWidth: true
                        label: I18n.tr(modelData.key)
                        iconName: modelData.icon
                        selected: root.mode === modelData.id
                        checkable: true; autoToggle: false
                        checked: selected
                        Accessible.role: Accessible.RadioButton
                        enabled: root.editable
                        onTriggered: AppearanceCoordinator.setMode(modelData.id)
                    }
                }
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                visible: root.mode === "system"
                text: I18n.tr("settings.appearance.system_resolved", {mode: I18n.tr("settings.appearance." + AppearanceCoordinator.tokens.mode)})
                tone: "secondary"; variant: "bodySmall"
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("settings.appearance.design_styles")
                variant: "titleSmall"; strong: true
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                visible: AppearanceCoordinator.tokens.legacy === true
                text: I18n.tr("settings.appearance.legacy_current", {name: I18n.tr(root.selectedDescriptor?.nameKey || "settings.appearance.theme.neutral")})
                tone: "secondary"; wrapMode: Text.WordWrap
            }
            GridLayout {
                objectName: "designStyleGrid"
                Layout.fillWidth: true
                columns: width < 650 ? 2 : 3
                columnSpacing: Metrics.spacingSmall
                rowSpacing: Metrics.spacingSmall
                Repeater {
                    model: AppearanceService.catalog
                    ThemeCard {
                        required property var modelData
                        Layout.fillWidth: true
                        descriptor: modelData
                        selected: root.themeId === modelData.id
                        applied: root.committedTheme === modelData.id
                        enabled: root.editable
                        tokens: root.cardTokens(modelData.id)
                        onSelectedTheme: themeId => AppearanceCoordinator.selectTheme(themeId)
                    }
                }
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                visible: AppearanceCoordinator.tokens.legacy === false
                    && AppearanceCoordinator.tokens.design?.requiredBackdrop !== "none"
                text: I18n.tr("settings.appearance.glass_limited")
                tone: "secondary"; wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                Shared.TextLabel { Layout.fillWidth: true; text:I18n.tr("settings.appearance.preview_layout"); tone:"secondary" }
                Shared.Button {
                    label:I18n.tr("settings.bar.style.connected"); size:"small"
                    selected:root.previewLayout === "connected"
                    onTriggered:root.previewLayout="connected"
                }
                Shared.Button {
                    label:I18n.tr("settings.bar.style.classic"); size:"small"
                    selected:root.previewLayout === "classic"
                    onTriggered:root.previewLayout="classic"
                }
            }
            ThemePreview {
                objectName: "designStylePreview"
                layoutStyle: root.previewLayout
                Layout.fillWidth: true
                Layout.preferredHeight: 290
                tokens: AppearanceCoordinator.tokens
                wallpaperSource: root.previewWallpaper
            }
            RowLayout {
                Layout.fillWidth: true
                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: AppearanceCoordinator.trialActive
                        ? I18n.tr("settings.appearance.trial_countdown", {seconds: AppearanceCoordinator.remainingSeconds})
                        : I18n.tr("settings.appearance.preview_hint")
                    tone: AppearanceCoordinator.trialActive ? "accent" : "secondary"
                    wrapMode: Text.WordWrap
                }
                Shared.Button {
                    visible: !AppearanceCoordinator.trialActive
                    label: I18n.tr("settings.appearance.try")
                    enabled: root.editable && !root.missingThemeWallpaper
                    onTriggered: AppearanceCoordinator.startTrial()
                }
                Shared.Button {
                    visible: AppearanceCoordinator.trialActive
                    label: I18n.tr("settings.appearance.keep")
                    variant: "primary"
                    enabled: !AppearanceCoordinator.busy
                    onTriggered: AppearanceCoordinator.keepTrial()
                }
                Shared.Button {
                    visible: AppearanceCoordinator.trialActive
                    label: I18n.tr("settings.appearance.revert")
                    enabled: !AppearanceCoordinator.busy
                    onTriggered: AppearanceCoordinator.cancelTrial()
                }
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                visible: AppearanceCoordinator.trialActive
                text: I18n.tr("settings.appearance.keep_hint")
                tone: "secondary"; variant: "bodySmall"; wrapMode: Text.WordWrap
            }
            Shared.Button {
                Layout.fillWidth: true
                objectName: "advancedButton"
                label: I18n.tr("settings.appearance.advanced")
                iconName: AppearanceCoordinator.advancedOpen ? "expand_less" : "expand_more"
                selected: AppearanceCoordinator.advancedOpen
                onTriggered: AppearanceCoordinator.setAdvancedOpen(!AppearanceCoordinator.advancedOpen)
            }
            Loader {
                objectName: "advancedLoader"
                Layout.fillWidth: true
                active: AppearanceCoordinator.advancedOpen
                visible: active
                sourceComponent: Component {
                    AppearanceAdvanced {
                        enabled: root.editable
                        tokens: root.advancedTokens
                        configuredMotionScale: AppearanceService.resolveCandidate({appearance: root.advancedAppearance, reducedMotion: false}).motionScale
                        overrides: root.overrides
                        editMode: AppearanceCoordinator.editMode
                        reducedMotion: AppearanceCoordinator.candidate.reducedMotion
                        onFieldEdited: (key, value) => AppearanceCoordinator.setOverride(key, value)
                        onFieldReset: key => AppearanceCoordinator.resetOverride(key)
                        onResetAll: AppearanceCoordinator.resetThemeOverrides()
                        onReducedMotionEdited: value => AppearanceCoordinator.setReducedMotion(value)
                    }
                }
            }
            Shared.TextLabel {
                text: I18n.tr("settings.appearance.wallpaper")
                variant: "titleSmall"; strong: true
            }
            Shared.Select {
                Layout.fillWidth: true
                enabled: root.editable && WallpapersService.appearanceAvailable
                accessibleName: I18n.tr("settings.appearance.wallpaper")
                model: root.wallpaperOptions
                currentIndex: root.wallpaperOptions.findIndex(option => option.value === root.wallpaper.policy)
                onSelected: (index, value) => AppearanceCoordinator.setWallpaper(value, root.wallpaper.customPath || "")
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                visible: root.missingThemeWallpaper
                text: I18n.tr("settings.appearance.no_style_wallpaper")
                tone: "warning"; wrapMode: Text.WordWrap
            }
            Shared.Button {
                visible: root.missingThemeWallpaper
                label: I18n.tr("settings.appearance.wallpaper_keep")
                enabled: root.editable
                onTriggered: AppearanceCoordinator.setWallpaper("keep", root.wallpaper.customPath || "")
            }
            Controls.TextField {
                id: wallpaperPath
                Layout.fillWidth: true
                visible: root.wallpaper.policy === "custom"
                enabled: root.editable
                text: root.wallpaper.customPath || ""
                placeholderText: I18n.tr("settings.appearance.wallpaper_path")
                selectByMouse: true
                color: Theme.textPrimary
                Accessible.name: I18n.tr("settings.appearance.wallpaper_path")
                onEditingFinished: AppearanceCoordinator.setWallpaper("custom", text.trim())
                background: Rectangle {
                    radius: Metrics.radiusSmall; color: Theme.surfaceElevated
                    border.width: 1
                    border.color: wallpaperPath.activeFocus ? Theme.focus : Theme.border
                }
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                text: WallpapersService.appearanceAvailable ? I18n.tr("settings.appearance.wallpaper_hint")
                    : I18n.tr("settings.appearance.wallpaper_unavailable")
                tone: "secondary"; variant: "bodySmall"; wrapMode: Text.WordWrap
            }
            Shared.Button {
                visible: !WallpapersService.appearanceAvailable
                label: I18n.tr("settings.appearance.retry_wallpaper")
                enabled: root.editable
                onTriggered: WallpapersService.refreshAppearanceCapability()
            }
            Shared.TextLabel {
                Layout.fillWidth: true
                visible: AppearanceCoordinator.error.length > 0
                text: I18n.tr(AppearanceCoordinator.error)
                tone: "danger"; wrapMode: Text.WordWrap
            }
            Shared.Button {
                visible: AppearanceCoordinator.finalizationPending
                label: I18n.tr("settings.appearance.retry_finalize")
                enabled: !AppearanceCoordinator.busy
                onTriggered: AppearanceCoordinator.retryFinalization()
            }
            Shared.Button {
                visible: (AppearanceCoordinator.error.length > 0 || !WallpapersService.appearanceAvailable)
                    && root.wallpaper.policy !== "keep"
                label: I18n.tr("settings.appearance.wallpaper_keep")
                enabled: root.editable
                onTriggered: AppearanceCoordinator.setWallpaper("keep", "")
            }
            Shared.Button {
                label: I18n.tr("settings.appearance.undo")
                iconName: "undo"
                enabled: AppearanceCoordinator.canUndo && !AppearanceCoordinator.dirty && root.editable
                onTriggered: AppearanceCoordinator.undoLastApply()
            }
            Item { Layout.preferredHeight: 8 }
        }
    }
}
