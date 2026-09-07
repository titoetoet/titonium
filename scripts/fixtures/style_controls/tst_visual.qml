pragma ComponentBehavior: Bound
import QtQuick
import QtTest

Item {
    id: scene
    width: 1410; height: 810
    readonly property var ids:["modern-flat","material","neumorphism","glassmorphism","liquid-glass"]
    Rectangle { anchors.fill:parent;color:"#747b85" }
    Repeater {
        model: 10
        StyleSpecimen {
            required property int index
            x:25+(index%5)*278;y:20+Math.floor(index/5)*400
            styleId:scene.ids[index%5];mode:index<5?"light":"dark"
        }
    }
    TestCase {
        name:"DesignStyleVisual";when:windowShown
        function test_capture_actual_specimen() {
            wait(40);
            const image=grabImage(scene);
            compare(image.width,scene.width);compare(image.height,scene.height);
            image.save("/tmp/titonium-style-specimen.png");
        }
    }
}
