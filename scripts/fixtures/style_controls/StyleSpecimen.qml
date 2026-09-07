pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Shared as Shared
import qs.Titonium.Services.Appearance

Item {
    id: root
    property string mode: "dark"
    property string styleId: "modern-flat"
    readonly property var tokens: {
        const t = AppearanceService.resolveCandidate({appearance:{themeId:styleId,mode:mode},reducedMotion:true});
        // Hold palette constant so silhouette and depth carry the comparison.
        const base = AppearanceService.resolveCandidate({appearance:{themeId:"modern-flat",mode:mode},reducedMotion:true});
        t.colors = base.colors;
        return t;
    }
    width: 260; height: 370
    Shared.StylePaint { anchors.fill: parent; tokens:root.tokens; role:"panel";radius:16 }
    Text { x:18;y:16;text:root.styleId;color:root.tokens.colors.textPrimary;font.pixelSize:17;font.bold:true }
    Text { x:18;y:41;text:root.mode+" · same palette";color:root.tokens.colors.textSecondary;font.pixelSize:12 }
    Shared.Button { x:18;y:68;width:105;label:"Primary";variant:"primary";tokens:root.tokens }
    Shared.Button { x:136;y:68;width:106;label:"Secondary";tokens:root.tokens }
    Shared.Button { x:18;y:113;width:105;label:"Quiet";variant:"quiet";tokens:root.tokens }
    Shared.Button { x:136;y:113;width:106;label:"Disabled";enabled:false;tokens:root.tokens }
    Item {
        x:18;y:160;width:224;height:38
        Shared.StylePaint { anchors.fill:parent; tokens:root.tokens;role:"field";radius:10 }
        TextInput { anchors.fill:parent;anchors.margins:10;text:"Editable field";color:root.tokens.colors.textPrimary;font.pixelSize:13 }
    }
    Shared.Toggle { x:18;y:214;tokens:root.tokens;checked:true }
    Shared.Slider { x:90;y:208;width:152;tokens:root.tokens;value:.62 }
    Row {
        x:18;y:253;spacing:7
        Repeater {
            model:["Rest","Hover","Press"]
            Item {
                required property int index
                required property string modelData
                width:70;height:38
                Shared.StylePaint {
                    anchors.fill:parent;tokens:root.tokens;role:"button";radius:10
                    interaction:({hovered:parent.index===1,pressed:parent.index===2})
                }
                Text { anchors.centerIn:parent;text:parent.modelData;color:root.tokens.colors.textPrimary;font.pixelSize:12 }
            }
        }
    }
    Item {
        x:18;y:310;width:224;height:38
        Shared.StylePaint { anchors.fill:parent;tokens:root.tokens;role:"menu-row";radius:8;interaction:({selected:true,focused:true}) }
        Text { anchors.centerIn:parent;text:"Selected · focused";color:root.tokens.colors.textPrimary;font.pixelSize:13 }
    }
}
