pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Column {
    id: root

    spacing: Metrics.spacingSmall

    Controls.TextLabel {
        text: I18n.tr("gallery.typography")
        variant: "label"
        strong: true
    }

    Controls.TextLabel {
        text: I18n.tr("gallery.type.display")
        variant: "display"
    }

    Row {
        spacing: Metrics.spacingLarge
        Controls.TextLabel { text: I18n.tr("gallery.type.title_large"); variant: "titleLarge" }
        Controls.TextLabel { text: I18n.tr("gallery.type.title"); variant: "title" }
        Controls.TextLabel { text: I18n.tr("gallery.type.title_small"); variant: "titleSmall" }
    }

    Row {
        spacing: Metrics.spacingLarge
        Controls.TextLabel { text: I18n.tr("gallery.type.body_large"); variant: "bodyLarge" }
        Controls.TextLabel { text: I18n.tr("gallery.type.body"); variant: "body" }
        Controls.TextLabel { text: I18n.tr("gallery.type.caption"); variant: "caption"; tone: "secondary" }
    }

    Controls.TextLabel {
        text: "theme.id = " + Theme.id
        variant: "mono"
        tone: "secondary"
    }
}
