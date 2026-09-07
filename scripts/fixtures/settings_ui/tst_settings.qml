import QtQuick
import QtQuick.Controls as Controls
import QtTest
import qs.Titonium.Settings
import qs.Titonium.Shared as Shared
import qs.Titonium.Services.Appearance
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme

TestCase {
    id: testCase
    name: "SettingsRelease"
    when: windowShown
    visible: true
    width: 980; height: 700
    Rectangle { anchors.fill: parent; color: Theme.background; z: -1 }
    Component { id: workspaceFactory; SettingsWorkspace { width: 980; height: 700 } }
    Component { id: buttonFactory; Shared.Button { label: "Apply"; variant: "primary" } }
    Component { id: selectFactory; Shared.Select {
        model: [{label:"Vietnamese",value:"vi"},{label:"English",value:"en"}]
        currentIndex: Preferences.locale === "en" ? 1 : 0
        onSelected: (index, value) => Preferences.patch("locale", value)
    } }
    function descendants(item) {
        let result = [];
        for (const child of item.children || []) result = result.concat([child], descendants(child));
        return result;
    }
    function textItem(item, text) { return descendants(item).find(child => child.text === text && child.variant === "titleLarge"); }
    function luminance(c) {
        return [c.r,c.g,c.b].map(v=>v<=.04045?v/12.92:Math.pow((v+.055)/1.055,2.4)).reduce((a,v,i)=>a+v*[.2126,.7152,.0722][i],0);
    }
    function test_primary_label_contrast_after_theme_change() {
        const button = createTemporaryObject(buttonFactory, testCase);
        for (const theme of AppearanceService.catalog) for (const mode of ["dark","light"]) {
            button.tokens = AppearanceService.resolveCandidate({appearance:{themeId:theme.id,mode:mode}});
            for (const enabled of [true,false]) {
                button.enabled = enabled;
                const a=luminance(button.foregroundColor), b=luminance(button.backgroundColor);
                verify((Math.max(a,b)+.05)/(Math.min(a,b)+.05)>=4.5, theme.id+" "+mode+" enabled="+enabled);
            }
        }
    }
    function test_select_follows_external_reset_after_activation() {
        Preferences.patch("locale", "en");
        const select=createTemporaryObject(selectFactory,testCase);
        const combo=descendants(select).find(item=>item instanceof Controls.ComboBox);
        verify(combo !== undefined);
        combo.forceActiveFocus();keyClick(Qt.Key_Up);
        compare(select.currentIndex,0);compare(combo.currentIndex,0);
        Preferences.patch("locale", "en");compare(select.currentIndex,1);compare(combo.currentIndex,1);
    }
    function test_all_pages_layout_data() {
        return [
            {tag:"dark-full",mode:"dark",w:980,h:700},
            {tag:"light-full",mode:"light",w:980,h:700},
            {tag:"dark-small",mode:"dark",w:820,h:600},
            {tag:"light-small",mode:"light",w:820,h:600}
        ];
    }
    function test_all_pages_layout(data) {
        Preferences.patch("appearance.mode", data.mode);
        const workspace=createTemporaryObject(workspaceFactory,testCase,{width:data.w,height:data.h});
        for (const locale of ["en","vi"]) {
            Preferences.patch("locale", locale);
            for (const page of ["general","appearance","bar","dock","spotlight","notifications","audio","about"]) {
                SettingsCoordinator.requestedPage=page;wait(50);
                const title=textItem(workspace,I18n.tr("settings."+page+".title"));
                verify(title !== undefined, page+" title");
                if(page!=="about") {
                    const reset=descendants(workspace).find(item=>item.label===I18n.tr("settings.reset.page"));
                    const titleY=title.mapToItem(workspace,0,title.height/2).y;
                    const resetY=reset.mapToItem(workspace,0,reset.height/2).y;
                    verify(Math.abs(titleY-resetY)<4,page+" reset must align with title");
                }
                const loader=findChild(workspace,"settingsPageLoader");
                verify(loader !== undefined);
                for (const child of descendants(loader.item)) {
                    if (!child.visible || !child.label || !child.foregroundColor) continue;
                    verify(child.width+1>=child.implicitWidth, page+" button clipped: "+child.label);
                }
                if (page === "dock") {
                    const lists=descendants(loader.item).filter(item=>item instanceof ListView);
                    const catalog=lists[lists.length-1];
                    verify(catalog.height>=44,"Dock catalog must keep at least one reachable application row");
                    const scroll=descendants(loader.item).find(item=>item instanceof Flickable);
                    verify(scroll !== undefined);
                    scroll.contentY=Math.max(0,scroll.contentHeight-scroll.height);wait(20);
                    verify(catalog.mapToItem(loader,0,catalog.height).y<=loader.height+1,"Dock catalog reachable above footer");
                }
                if (page === "bar") {
                    const scroll=descendants(loader.item).find(item=>item instanceof Flickable);
                    verify(scroll !== undefined, "Bar must scroll instead of overflowing the footer");
                    scroll.contentY=Math.max(0,scroll.contentHeight-scroll.height);
                    wait(20);
                    const last=descendants(loader.item).find(item=>item.title===I18n.tr("settings.bar.mascot"));
                    const bottom=last.mapToItem(loader,0,last.height).y;
                    verify(bottom<=loader.height+1,"last Bar row reachable above footer");
                }
                grabImage(workspace).save("/tmp/settings-"+data.tag+"-"+locale+"-"+page+".png");
            }
        }
    }
}
