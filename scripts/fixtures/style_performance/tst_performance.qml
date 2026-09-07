pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtTest
import qs.Titonium.Shared as Shared
import qs.Titonium.Services.Appearance
Item {
    id: scene
    width: 1000; height: 400
    property int frames: 0
    property bool showPaint: false
    property bool pressed: false
    readonly property var ids: ["modern-flat","material","neumorphism","glassmorphism","liquid-glass"]
    Connections { target: scene.Window.window; function onFrameSwapped() { scene.frames++; } }
    Repeater {
        id: specimens
        model: scene.ids
        Shared.StylePaint {
            required property int index
            required property string modelData
            x: index*195+5; y: 40; width: 180; height: 80
            visible: scene.showPaint
            tokens: AppearanceService.resolveCandidate({appearance:{themeId:modelData,mode:"dark"},reducedMotion:false})
            role: "button"
            interaction: ({pressed:scene.pressed})
        }
    }
    TestCase {
        name: "StylePerformance"; when: windowShown
        function phase(name) { console.log("PERF_PHASE "+name); }
        function assertLoaded(expected) {
            // qmllint disable missing-property
            for (var i=0;i<5;i++) compare(specimens.itemAt(i).paintItem!==null,expected);
            // qmllint enable missing-property
        }
        function test_protocol() {
            // Warm every renderer and its software caches before measuring retained memory.
            scene.showPaint=true;wait(500);scene.showPaint=false;wait(500);
            phase("hidden_idle"); const hiddenFrames=scene.frames;wait(30000);
            console.log("PERF_FRAMES hidden_idle "+(scene.frames-hiddenFrames));
            scene.showPaint=true;wait(500);assertLoaded(true);
            phase("visible_idle");const visibleFrames=scene.frames;wait(30000);
            const idleFrames=scene.frames-visibleFrames;
            console.log("PERF_FRAMES visible_idle "+idleFrames);
            verify(idleFrames<=2,"Settled scene must not continuously submit frames");
            phase("interaction_10s");const activeFrames=scene.frames;
            for (var n=0;n<20;n++) {scene.pressed=true;wait(250);scene.pressed=false;wait(250);}
            console.log("PERF_FRAMES interaction_10s "+(scene.frames-activeFrames));
            verify(scene.frames>activeFrames,"Frame counter must observe animated submissions");
            wait(500);const settled=scene.frames;wait(500);
            compare(scene.frames,settled,"Finite interaction motion must stop submitting frames");
            scene.showPaint=false;wait(500);phase("before_cycles");wait(1000);
            phase("cycles");
            for (var cycle=0;cycle<20;cycle++) {
                scene.showPaint=true;wait(20);assertLoaded(true);
                scene.showPaint=false;wait(20);assertLoaded(false);
            }
            gc();wait(500);phase("after_cycles");wait(1000);
            assertLoaded(false);
            console.log("PERF_CYCLES 20 loads=100 unloads=100 livePaintItems=0");
            phase("done");
        }
    }
}
