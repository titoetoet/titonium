import QtQuick
import QtTest
import qs.Titonium.Shared as Shared
import qs.Titonium.Services.Appearance
import qs.Titonium.Theme
Item {
 id:scene; width:640;height:380
 function candidate(id) {return AppearanceService.resolveCandidate({appearance:{themeId:id,mode:"light"},reducedMotion:true});}
 Shared.Surface {id:surface;x:30;y:30;width:220;height:120;tokens:scene.candidate("glass")}
 Shared.Select {id:select;x:30;y:200;tokens:surface.tokens;model:[{label:"One",value:1}];currentIndex:0}
 TestCase {
  name:"StyleIntegrationCompatibility";when:windowShown
  function test_candidate_surface_isolation() {
   const candidate=scene.candidate("glass");candidate.colors.border="#ff00ff";candidate.material.backgroundOpacity=.73;candidate.material.sheenStrength=.3;candidate.material.shadowStrength=.2;
   surface.tokens=candidate;wait(20);
   compare(surface.borderColor,Qt.rgba(1,0,1,1));
   fuzzyCompare(findChild(surface,"appearancePaint").color.a,.73,.001);
   fuzzyCompare(findChild(surface,"appearanceShadow").color.a,.14*.2,.001);
   compare(findChild(surface,"appearanceSheen").visible,true);
  }
  function test_legacy_select_popup_stays_plain() {
   for(const id of ["neutral","glass","soft","graphite"]) {
    surface.tokens=scene.candidate(id);wait(20);
    const popup=select.children[0].popup;
    popup.open();wait(30);
    const background=popup.background;
    const legacy=findChild(background,"legacySelectPopupPaint");
    verify(legacy!==null,"legacy popup must retain a plain paint rectangle");
    verify(legacy.visible);compare(legacy.color,surface.tokens.colors.surface);
    compare(legacy.border.color,surface.tokens.colors.borderStrong);compare(legacy.border.width,Metrics.borderWidth);popup.close();
   }
  }
 }
}
