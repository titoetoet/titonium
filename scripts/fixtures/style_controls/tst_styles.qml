import QtQuick
import QtTest
import qs.Titonium.Shared as Shared
import qs.Titonium.Services.Appearance
import qs.Titonium.Theme

Item {
    id: scene
    width: 720; height: 520
    Rectangle { anchors.fill: parent; color: "#151820" }
    property int generation: 1000
    readonly property var ids: ["glassmorphism","material","liquid-glass","modern-flat","neumorphism"]
    function resolve(id, mode) { return AppearanceService.resolveCandidate({appearance:{themeId:id,mode:mode || "dark"},reducedMotion:true}); }
    Shared.StylePaint { id: paint; x:20; y:20; width:180; height:80; role:"button"; tokens:scene.resolve("modern-flat"); radius:12 }
    TextInput { id: editor; x:30;y:45;width:160;height:30;color:"white";text:"Titonium" }
    Shared.Button { id:button; x:20;y:130;label:"Action";tokens:paint.tokens }
    Shared.Toggle { id:toggle; x:160;y:135;tokens:paint.tokens }
    Shared.Slider { id:slider; x:220;y:130;tokens:paint.tokens;value:.4 }
    Shared.Select { id:select; x:420;y:130;tokens:paint.tokens;model:[{label:"One",value:1},{label:"Two",value:2}];currentIndex:0 }
    SignalSpy { id:buttonSpy; target:button; signalName:"triggered" }
    SignalSpy { id:toggleSpy; target:toggle; signalName:"toggled" }
    TestCase {
        name:"DesignStylePaint"; when:windowShown
        function cleanup() { paint.interaction={};button.enabled=true;toggle.enabled=true;buttonSpy.clear();toggleSpy.clear(); }
        function test_controls_keyboard_and_disabled() {
            for(const id of scene.ids) {
                paint.tokens=scene.resolve(id);wait(20);
                button.forceActiveFocus();keyClick(Qt.Key_Space);compare(buttonSpy.count,1);buttonSpy.clear();
                toggle.forceActiveFocus();keyClick(Qt.Key_Return);compare(toggleSpy.count,1);compare(toggleSpy.signalArguments[0][0],true);toggleSpy.clear();
                button.enabled=false;button.activate();compare(buttonSpy.count,0);button.enabled=true;
                toggle.enabled=false;toggle.activate();compare(toggleSpy.count,0);toggle.enabled=true;
                compare(slider.value,.4);compare(select.currentIndex,0);
            }
        }
        function test_style_switch_preserves_editing_and_geometry() {
            editor.forceActiveFocus(); editor.select(1,4);
            const bounds=[paint.x,paint.y,paint.width,paint.height];
            for(const id of scene.ids) {
                paint.tokens=scene.resolve(id); wait(25);
                verify(paint.paintItem !== null);
                compare(paint.paintItem.objectName, id + "Paint");
                compare(editor.text,"Titonium");compare(editor.selectionStart,1);compare(editor.selectionEnd,4);verify(editor.activeFocus);
                compare([paint.x,paint.y,paint.width,paint.height],bounds);
            }
        }
        function test_focus_survives_zero_material_strength() {
            var tokens=scene.resolve("neumorphism");tokens.material.borderStrength=0;tokens.material.shadowStrength=0;
            paint.tokens=tokens;paint.interaction={focused:true};wait(20);
            const ring=findChild(paint,"styleFocusRing");verify(ring.visible);compare(ring.border.width,2);compare(ring.opacity,1);
        }
        function test_neumorphic_state() {
            paint.tokens=scene.resolve("neumorphism");paint.interaction={};wait(20);compare(paint.paint.inset,false);
            paint.interaction={pressed:true};wait(20);compare(paint.paint.inset,true);
            paint.role="field";paint.interaction={};wait(20);compare(paint.paint.inset,true);paint.role="button";
        }
        function test_explicit_corners() {
            paint.topLeftRadius=0;paint.topRightRadius=0;paint.bottomLeftRadius=7;paint.bottomRightRadius=11;
            for(const id of scene.ids) {paint.tokens=scene.resolve(id);wait(20);compare(paint.geometry.topLeftRadius,0);compare(paint.geometry.bottomRightRadius,11);}
            paint.topLeftRadius=Qt.binding(()=>paint.radius);paint.topRightRadius=Qt.binding(()=>paint.radius);paint.bottomLeftRadius=Qt.binding(()=>paint.radius);paint.bottomRightRadius=Qt.binding(()=>paint.radius);
        }
        function test_layout_motion_does_not_follow_design_style() {
            const values=[];
            for(const id of scene.ids) {
                AppearanceService.setTrial({appearance:{themeId:id,mode:"dark",themeOverrides:{[id]:{dark:{motionScale:1.5}}}},reducedMotion:false},++scene.generation);
                wait(20);values.push([Motion.fast,Motion.normal,Motion.slow]);
            }
            for(const value of values) compare(value,[100,160,220]);
            AppearanceService.clearTrial(scene.generation);
        }
        function test_actual_depth_layers_and_ripple() {
            paint.tokens=scene.resolve("modern-flat");paint.interaction={};wait(20);
            compare(findChild(paint,"materialElevation"),null);
            const flat=grabImage(paint);
            paint.tokens=scene.resolve("material");wait(20);
            // qmllint disable missing-property
            const elevation=paint.paintItem.elevation;
            const rest=grabImage(paint);
            paint.interaction={pressed:true};wait(20);
            verify(paint.paintItem.elevation<elevation);
            // qmllint enable missing-property
            verify(!grabImage(paint).equals(rest),"Material press must change real paint pixels");
            compare(findChild(paint,"materialRipple").scale,1);
            paint.interaction={enabled:false,pressed:true,hovered:true};wait(20);
            compare(findChild(paint,"materialRipple").opacity,0);
            compare(findChild(paint,"materialStateLayer").opacity,0);
            paint.tokens=scene.resolve("neumorphism");paint.interaction={};wait(20);
            verify(findChild(paint,"neumoLightShadow").strength>0);
            verify(findChild(paint,"neumoDarkShadow").strength>0);
            const raised=grabImage(paint);
            paint.interaction={pressed:true};wait(20);
            verify(findChild(paint,"neumoInset").visible);
            verify(!grabImage(paint).equals(raised),"Neumorphic inset must change real paint pixels");
            paint.role="field";paint.interaction={};wait(20);
            verify(findChild(paint,"neumoInset").visible);
            verify(paint.paint.depthStrength>0);compare(paint.paint.shadowStrength,0);
            paint.role="button";
        }
        function test_glass_fallback_and_distinct_pixels() {
            for(const mode of ["light","dark"]) {
                paint.tokens=scene.resolve("glassmorphism",mode);wait(20);
                // qmllint disable missing-property
                compare(paint.paintItem.backdropTreatment,"opaque-safe-fallback");
                // qmllint enable missing-property
                compare(findChild(paint,"liquidBezel"),null);
                verify(findChild(paint,"frostedSheen")!==null);
                const frosted=grabImage(paint);
                paint.tokens=scene.resolve("liquid-glass",mode);wait(20);
                // qmllint disable missing-property
                compare(paint.paintItem.backdropTreatment,"opaque-safe-fallback");
                // qmllint enable missing-property
                verify(findChild(paint,"liquidBezel")!==null);
                verify(findChild(paint,"liquidSpecular")!==null);
                verify(!grabImage(paint).equals(frosted));
                paint.backdropCapability={level:"refraction",available:true};wait(20);
                compare(paint.renderer,"liquid-glass");
                paint.backdropCapability={level:"none",available:false};wait(20);
                compare(paint.renderer,"liquid-glass");compare(editor.opacity,1);
            }
        }
        function test_reduced_motion_mid_ripple() {
            var animated=scene.resolve("material");animated.reducedMotion=false;
            animated.design.controlMotion.durationMs=1000;
            paint.tokens=animated;paint.interaction={};wait(30);
            paint.interaction={pressed:true};wait(80);
            const ripple=findChild(paint,"materialRipple");
            verify(ripple.scale<1);verify(ripple.scale>.35);
            paint.tokens=scene.resolve("material");wait(10);
            compare(ripple.scale,1);compare(ripple.opacity,.1);
        }
        function test_resolved_motion_curves() {
            for (const id of scene.ids) {
                paint.tokens=scene.resolve(id);wait(20);
                const transition=findChild(paint,"styleStateTransition");
                compare(transition.easingType,id==="material"?Easing.InOutCubic:id==="liquid-glass"?Easing.OutQuint:Easing.OutCubic);
            }
        }
        function test_resting_quiet_glass_is_unpainted() {
            for (const id of ["glassmorphism","liquid-glass"]) {
                paint.tokens=scene.resolve(id);paint.interaction={quiet:true};wait(20);
                const resting=grabImage(paint);
                paint.visible=false;wait(20);const empty=grabImage(paint);
                paint.visible=true;wait(20);
                verify(resting.equals(empty),id+" resting quiet must leave only sibling content");
                paint.interaction={quiet:true,enabled:false,hovered:true,pressed:true};wait(20);
                verify(grabImage(paint).equals(empty),id+" disabled quiet must remain unpainted");
                paint.interaction={quiet:true,hovered:true};wait(20);
                verify(!grabImage(paint).equals(empty),id+" engaged quiet must show feedback");
            }
        }
        function test_liquid_opacity_changes_interior() {
            var translucent=scene.resolve("liquid-glass","light");
            translucent.material.backgroundOpacity=.85;translucent.material.sheenStrength=0;translucent.material.shadowStrength=0;
            paint.tokens=translucent;wait(20);
            const low=grabImage(paint);
            var opaque=scene.resolve("liquid-glass","light");
            opaque.material.backgroundOpacity=1;opaque.material.sheenStrength=0;opaque.material.shadowStrength=0;
            paint.tokens=opaque;wait(20);
            const high=grabImage(paint);
            verify(low.pixel(90,65)!==high.pixel(90,65),"Liquid interior must honor supported alpha endpoints");
            compare(editor.opacity,1);
        }
        function test_liquid_finite_motion_and_reduction() {
            var animated=scene.resolve("liquid-glass");animated.reducedMotion=false;
            animated.design.controlMotion.durationMs=600;animated.design.controlMotion.pressScale=.985;
            paint.tokens=animated;paint.interaction={};wait(30);
            const bounds=[paint.x,paint.y,paint.width,paint.height];
            paint.interaction={pressed:true};wait(40);const early=grabImage(paint);
            wait(180);const later=grabImage(paint);
            verify(!early.equals(later),"Liquid paint must evolve during its finite interaction animation");
            // qmllint disable missing-property
            verify(paint.paintItem.scale<1);verify(paint.paintItem.scale>=.985);
            paint.tokens=scene.resolve("liquid-glass");wait(10);
            compare(paint.paintItem.scale,1);
            compare(paint.paintItem.interactionProgress,1);
            // qmllint enable missing-property
            compare([paint.x,paint.y,paint.width,paint.height],bounds);
            const settled=grabImage(paint);wait(100);verify(settled.equals(grabImage(paint)));
        }
        function test_rendered_corners() {
            paint.topLeftRadius=0;paint.topRightRadius=35;paint.bottomLeftRadius=0;paint.bottomRightRadius=0;
            for(const id of scene.ids) {
                paint.tokens=scene.resolve(id);wait(20);
                const image=grabImage(paint);
                // A squared top-left is painted; the rounded top-right excludes its corner.
                image.save("/tmp/style-corner-"+id+".png");
                verify(image.pixel(1,1)!==image.pixel(178,1),id+" must preserve asymmetric corners");
            }
            paint.topLeftRadius=Qt.binding(()=>paint.radius);paint.topRightRadius=Qt.binding(()=>paint.radius);
            paint.bottomLeftRadius=Qt.binding(()=>paint.radius);paint.bottomRightRadius=Qt.binding(()=>paint.radius);
        }
        function test_hidden_unloads_paint() {
            paint.visible=false;wait(20);compare(paint.paintItem,null);paint.visible=true;wait(20);verify(paint.paintItem!==null);
        }
    }
}
