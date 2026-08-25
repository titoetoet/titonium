pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    property string currentPage: root.descriptor?.page || "theme"
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property bool dirty: JSON.stringify(ConfigStore.previewState)
        !== JSON.stringify(ConfigStore.committedState)
        || JSON.stringify(ConfigStore.previewLayout) !== JSON.stringify(ConfigStore.committedLayout)
    readonly property bool materialCompatible: {
        const allowed = ConfigStore.themeState.material?.allowedBackends || [];
        return Theme.id !== "titonium-neutral" && (allowed.indexOf("qml") >= 0 || allowed.indexOf("native") >= 0);
    }
    readonly property var pages: [
        { "id": "theme", "labelKey": "settings.nav.theme", "icon": "palette" },
        { "id": "typography", "labelKey": "settings.nav.typography", "icon": "text_fields" },
        ...(root.materialCompatible ? [{ "id": "material", "labelKey": "settings.nav.material", "icon": "blur_on" }] : []),
        { "id": "layout", "labelKey": "settings.nav.layout", "icon": "view_quilt" },
        { "id": "frame", "labelKey": "settings.nav.frame", "icon": "crop_free" },
        { "id": "audio", "labelKey": "settings.nav.audio", "icon": "volume_up" },
        { "id": "system", "labelKey": "settings.nav.system", "icon": "tune" },
        { "id": "launcher", "labelKey": "settings.nav.launcher", "icon": "apps" }
    ]

    anchors.fill: parent
    focus: true

    function cancelAndClose(): void {
        ConfigStore.cancel();
        SurfaceCoordinator.close(root.ownerId);
    }

    function applyAndClose(): void {
        if (ConfigStore.apply())
            SurfaceCoordinator.close(root.ownerId);
    }

    function componentFor(pageId: string): Component {
        const components = {
            "theme": themePageComponent,
            "typography": typographyPageComponent,
            "layout": layoutPageComponent,
            "frame": framePageComponent,
            "audio": audioPageComponent,
            "system": systemPageComponent,
            "launcher": launcherPageComponent,
            "material": materialPageComponent
        };
        return components[pageId] || themePageComponent;
    }

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.42)
        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(panel, eventPoint.position)) root.cancelAndClose();
            }
        }
    }

    Controls.Panel {
        id: panel
        z: 1
        width: Math.min(980, root.width - Metrics.spacingLarge * 4)
        height: Math.min(700, root.height - Metrics.spacingLarge * 4)
        anchors.centerIn: parent
        padding: 0
        customColor: Theme.background

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                Layout.leftMargin: Metrics.spacingLarge
                Layout.rightMargin: Metrics.spacingLarge
                spacing: Metrics.spacingMedium

                Controls.Icon {
                    name: "settings"
                    tone: "accent"
                    accessibleName: ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Controls.TextLabel {
                        text: I18n.tr("settings.title")
                        variant: "title"
                        strong: true
                    }

                    Controls.TextLabel {
                        text: I18n.tr("settings.preview_hint")
                        variant: "caption"
                        tone: "secondary"
                    }
                }

                Controls.TextLabel {
                    visible: root.dirty
                    text: I18n.tr("settings.unsaved")
                    variant: "caption"
                    tone: "warning"
                    strong: true
                }

                Controls.Button {
                    iconName: "close"
                    variant: "quiet"
                    size: "small"
                    accessibleName: I18n.tr("settings.close")
                    onTriggered: root.cancelAndClose()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Metrics.borderWidth
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                ColumnLayout {
                    Layout.preferredWidth: 208
                    Layout.minimumWidth: 208
                    Layout.maximumWidth: 208
                    Layout.fillHeight: true
                    Layout.margins: Metrics.spacingMedium
                    spacing: Metrics.spacingSmall

                    Repeater {
                        model: root.pages

                        Controls.Button {
                            required property var modelData
                            Layout.fillWidth: true
                            label: I18n.tr(modelData.labelKey)
                            iconName: modelData.icon
                            variant: "quiet"
                            selected: root.currentPage === modelData.id
                            accessibleName: label
                            onTriggered: root.currentPage = modelData.id
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Controls.Surface {
                        Layout.fillWidth: true
                        implicitWidth: 1
                        implicitHeight: 76
                        tone: "elevated"
                        radius: Metrics.radiusMedium
                        outlined: true

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Controls.TextLabel {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr(ConfigStore.themeState.nameKey || "theme.neutral.name")
                                variant: "label"
                                strong: true
                            }

                            Controls.TextLabel {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.materialCompatible
                                    ? I18n.tr("settings.hybrid_material")
                                    : I18n.tr("settings.solid_baseline")
                                variant: "caption"
                                tone: "secondary"
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: Metrics.borderWidth
                    color: Theme.border
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 640
                    Layout.fillHeight: true
                    Layout.margins: Metrics.spacingLarge
                    sourceComponent: root.componentFor(root.currentPage)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Metrics.borderWidth
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                Layout.leftMargin: Metrics.spacingLarge
                Layout.rightMargin: Metrics.spacingLarge
                spacing: Metrics.spacingSmall

                Controls.Button {
                    label: I18n.tr("settings.restore_appearance")
                    iconName: "restart_alt"
                    variant: "secondary"
                    onTriggered: ConfigStore.restoreAppearance()
                }

                Controls.TextLabel {
                    Layout.fillWidth: true
                    text: ConfigStore.lastError
                    visible: ConfigStore.lastError.length > 0
                    variant: "caption"
                    tone: "danger"
                    elide: Text.ElideRight
                }

                Controls.Button {
                    label: I18n.tr("settings.cancel")
                    variant: "secondary"
                    onTriggered: root.cancelAndClose()
                }

                Controls.Button {
                    label: I18n.tr("settings.apply")
                    iconName: "check"
                    variant: "primary"
                    enabled: root.dirty
                    onTriggered: root.applyAndClose()
                }
            }
        }
    }

    Component { id: themePageComponent; ThemePage {} }
    Component { id: typographyPageComponent; TypographyPage {} }
    Component { id: layoutPageComponent; PanelLayoutPage {} }
    Component { id: framePageComponent; FramePage {} }
    Component { id: audioPageComponent; AudioPage {} }
    Component { id: systemPageComponent; SystemPage {} }
    Component { id: launcherPageComponent; LauncherPage {} }
    Component { id: materialPageComponent; MaterialPage {} }

    onMaterialCompatibleChanged: {
        if (!root.materialCompatible && root.currentPage === "material")
            root.currentPage = "theme";
    }

    Keys.onEscapePressed: event => {
        root.cancelAndClose();
        event.accepted = true;
    }

    Component.onCompleted: {
        if (root.currentPage === "material" && !root.materialCompatible)
            root.currentPage = "theme";
        root.forceActiveFocus(Qt.PopupFocusReason);
    }
}
