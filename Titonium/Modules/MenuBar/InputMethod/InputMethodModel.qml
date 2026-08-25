pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Foundation
import qs.Titonium.Platform.Input

QtObject {
    id: root

    readonly property string token: FcitxAdapter.engineToken
    readonly property bool vietnamese: ["lotus", "unikey", "bamboo", "vietnam", "vi-vn"]
        .some(fragment => root.token.includes(fragment))
    readonly property bool english: ["keyboard-us", "english", "en-us", "xkb:us"]
        .some(fragment => root.token.includes(fragment))
    readonly property string shortLabel: root.vietnamese ? "VI" : (root.english ? "EN" : "IM")
    readonly property string displayName: FcitxAdapter.available && FcitxAdapter.title.length > 0
        ? FcitxAdapter.title
        : I18n.tr("menubar.input_method.unavailable")
}
