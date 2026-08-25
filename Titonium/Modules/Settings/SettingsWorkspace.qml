pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root
    property string currentPage: "theme"
    property bool showCloseButton: true
    signal applyRequested()
    signal cancelRequested()

    readonly property bool dirty: JSON.stringify(ConfigStore.previewState) !== JSON.stringify(ConfigStore.committedState)
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
        { "id": "spotlight", "labelKey": "settings.nav.spotlight", "icon": "apps" }
    ]

    function componentFor(pageId: string): Component {
        const map = { "theme": themePage, "typography": typographyPage, "material": materialPage,
            "layout": layoutPage, "frame": framePage, "audio": audioPage,
            "system": systemPage, "spotlight": spotlightPage };
        return map[pageId] || themePage;
    }
    function selectPage(pageId: string): void {
        root.currentPage = root.pages.some(page => page.id === pageId) ? pageId : "theme";
    }

    anchors.fill: parent
    focus: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 64
            Layout.leftMargin: Metrics.spacingLarge; Layout.rightMargin: Metrics.spacingLarge
            Controls.Icon { name: "settings"; tone: "accent"; accessibleName: "" }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Controls.TextLabel { text: I18n.tr("settings.title"); variant: "title"; strong: true }
                Controls.TextLabel { text: I18n.tr("settings.preview_hint"); variant: "caption"; tone: "secondary" }
            }
            Controls.TextLabel { visible: root.dirty; text: I18n.tr("settings.unsaved"); variant: "caption"; tone: "warning"; strong: true }
            Controls.Button { visible: root.showCloseButton; iconName: "close"; variant: "quiet"; size: "small"; accessibleName: I18n.tr("settings.close"); onTriggered: root.cancelRequested() }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: Metrics.borderWidth; color: Theme.border }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
            ColumnLayout {
                Layout.preferredWidth: 208; Layout.minimumWidth: 208; Layout.maximumWidth: 208
                Layout.fillHeight: true; Layout.margins: Metrics.spacingMedium; spacing: Metrics.spacingSmall
                Repeater {
                    model: root.pages
                    Controls.Button {
                        required property var modelData
                        Layout.fillWidth: true; label: I18n.tr(modelData.labelKey); iconName: modelData.icon
                        variant: "quiet"; contentAlignment: Qt.AlignLeft; selected: root.currentPage === modelData.id
                        accessibleName: label; onTriggered: root.currentPage = modelData.id
                    }
                }
                Item { Layout.fillHeight: true }
                Controls.Surface {
                    Layout.fillWidth: true; implicitWidth: 1; implicitHeight: 76; tone: "elevated"; outlined: true
                    Column {
                        anchors.centerIn: parent; spacing: 2
                        Controls.TextLabel { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.tr(ConfigStore.themeState.nameKey || "theme.neutral.name"); variant: "label"; strong: true }
                        Controls.TextLabel { anchors.horizontalCenter: parent.horizontalCenter; text: root.materialCompatible ? I18n.tr("settings.hybrid_material") : I18n.tr("settings.solid_baseline"); variant: "caption"; tone: "secondary" }
                    }
                }
            }
            Rectangle { Layout.fillHeight: true; implicitWidth: Metrics.borderWidth; color: Theme.border }
            Loader { Layout.fillWidth: true; Layout.minimumWidth: 520; Layout.fillHeight: true; Layout.margins: Metrics.spacingLarge; sourceComponent: root.componentFor(root.currentPage) }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: Metrics.borderWidth; color: Theme.border }
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 64
            Layout.leftMargin: Metrics.spacingLarge; Layout.rightMargin: Metrics.spacingLarge; spacing: Metrics.spacingSmall
            Controls.Button { label: I18n.tr("settings.restore_appearance"); iconName: "restart_alt"; variant: "secondary"; onTriggered: ConfigStore.restoreAppearance() }
            Controls.TextLabel { Layout.fillWidth: true; text: ConfigStore.lastError; visible: ConfigStore.lastError.length > 0; variant: "caption"; tone: "danger"; elide: Text.ElideRight }
            Controls.Button { label: I18n.tr("settings.cancel"); variant: "secondary"; onTriggered: root.cancelRequested() }
            Controls.Button { label: I18n.tr("settings.apply"); iconName: "check"; variant: "primary"; enabled: root.dirty; onTriggered: root.applyRequested() }
        }
    }

    Component { id: themePage; ThemePage {} }
    Component { id: typographyPage; TypographyPage {} }
    Component { id: layoutPage; PanelLayoutPage {} }
    Component { id: framePage; FramePage {} }
    Component { id: audioPage; AudioPage {} }
    Component { id: systemPage; SystemPage {} }
    Component { id: spotlightPage; SpotlightPage {} }
    Component { id: materialPage; MaterialPage {} }
    onMaterialCompatibleChanged: if (!root.materialCompatible && root.currentPage === "material") root.currentPage = "theme"
}
