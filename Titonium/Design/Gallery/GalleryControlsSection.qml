pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Column {
    id: root

    spacing: Metrics.spacingSmall

    Controls.TextLabel {
        text: I18n.tr("gallery.controls")
        variant: "label"
        strong: true
    }

    Controls.TextLabel {
        text: I18n.tr("gallery.icons")
        variant: "caption"
        tone: "secondary"
    }

    Row {
        spacing: Metrics.spacingMedium
        Controls.Icon { name: "search"; accessibleName: I18n.tr("gallery.icon.search") }
        Controls.Icon { name: "apps"; accessibleName: I18n.tr("gallery.icon.apps") }
        Controls.Icon { name: "wifi"; accessibleName: I18n.tr("gallery.icon.wifi") }
        Controls.Icon { name: "volume_up"; accessibleName: I18n.tr("gallery.icon.volume") }
        Controls.Icon { name: "notifications"; accessibleName: I18n.tr("gallery.icon.notifications") }
        Controls.Icon { name: "check_circle"; tone: "success"; accessibleName: I18n.tr("gallery.icon.success") }
        Controls.Icon { name: "warning"; tone: "warning"; accessibleName: I18n.tr("gallery.icon.warning") }
        Controls.Icon { name: "error"; tone: "danger"; accessibleName: I18n.tr("gallery.icon.error") }
    }

    Controls.TextLabel {
        text: I18n.tr("gallery.button_variants")
        variant: "caption"
        tone: "secondary"
    }

    Row {
        spacing: Metrics.spacingSmall
        Controls.Button { label: I18n.tr("gallery.button.primary"); iconName: "save"; variant: "primary" }
        Controls.Button { label: I18n.tr("gallery.button.secondary"); variant: "secondary" }
        Controls.Button { label: I18n.tr("gallery.button.quiet"); iconName: "more_horiz"; variant: "quiet" }
        Controls.Button { label: I18n.tr("gallery.button.danger"); iconName: "delete"; variant: "danger" }
    }

    Controls.TextLabel {
        text: I18n.tr("gallery.button_states")
        variant: "caption"
        tone: "secondary"
    }

    Row {
        spacing: Metrics.spacingSmall
        Controls.Button {
            id: focusButton
            label: I18n.tr("gallery.focus")
            iconName: "keyboard"
            Component.onCompleted: focusButton.forceActiveFocus(Qt.TabFocusReason)
        }
        Controls.Button {
            label: I18n.tr("gallery.button.checked")
            iconName: "check"
            checkable: true
            checked: true
        }
        Controls.Button {
            label: I18n.tr("gallery.disabled")
            iconName: "block"
            enabled: false
        }
        Controls.Button {
            iconName: "settings"
            variant: "secondary"
            accessibleName: I18n.tr("gallery.button.icon_only")
        }
    }
}
