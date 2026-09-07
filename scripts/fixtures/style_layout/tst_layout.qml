import QtQuick
import QtQuick.Layouts
import QtTest
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import qs.Titonium.Services.Appearance

Item {
 id:scene;width:840;height:440
 property bool connected:true
 property int generation:500
 readonly property var ids:["glassmorphism","material","liquid-glass","modern-flat","neumorphism"]
 Rectangle {anchors.fill:parent;color:Theme.background}
 Shared.ConnectedPillShape {id:chassis;x:40;bodyWidth:720;bodyHeight:370;shoulderSize:20;bottomRadius:24;color:Theme.surface;visible:scene.connected}
 Shared.Panel {id:classic;x:60;y:20;width:720;height:350;radius:12;visible:!scene.connected}
 ColumnLayout {
  x:90;y:60;width:660;spacing:22
  Shared.TextLabel {text:"Titonium · " + Theme.themeId + " · " + (scene.connected ? "Connected" : "Classic");variant:"title"}
  RowLayout {
   Layout.fillWidth:true;spacing:16
   Shared.Button {id:action;label:"Primary";variant:"primary";Layout.preferredWidth:160}
   Shared.Button {label:"Secondary";Layout.preferredWidth:160}
   Shared.Button {label:"Selected";selected:true;Layout.preferredWidth:160}
   Shared.Toggle {checked:true}
  }
  Shared.Surface {Layout.fillWidth:true;Layout.preferredHeight:58;styleRole:"field";radius:10;Shared.TextLabel {anchors.centerIn:parent;text:"Field surface · nội dung dễ đọc"}}
  Shared.Slider {Layout.fillWidth:true;value:.62}
  Shared.TextLabel {text:"Same content and geometry · style changes paint only";tone:"secondary"}
 }
 Shared.AnchoredMenuPillShape {id:edge;visible:false;width:400;height:400;compactWidth:260;branchX:60;branchWidth:170;branchHeight:180;color:Theme.surface}
 TestCase {
  name:"DesignStyleLayoutMatrix";when:windowShown
  function test_layout_matrix(){
   const original=[chassis.width,chassis.height,chassis.safeRadius,edge.attachmentX,edge.safeRadius,classic.x,classic.y,classic.width,classic.height];
   action.forceActiveFocus();
   for(const id of scene.ids) for(const mode of ["light","dark"]) for(const layout of ["connected","classic"]){
    scene.connected=layout==="connected";
    AppearanceService.setTrial({appearance:{themeId:id,mode:mode},reducedMotion:true},++scene.generation);
    wait(30);
    compare([chassis.width,chassis.height,chassis.safeRadius,edge.attachmentX,edge.safeRadius,classic.x,classic.y,classic.width,classic.height],original);
    verify(action.activeFocus);
    const capture=grabImage(scene);
    compare(capture.pixel(2,420),Theme.background);
    capture.save("/tmp/titonium-style-layout-"+id+"-"+mode+"-"+layout+".png");
   }
   AppearanceService.clearTrial(scene.generation);
  }
 }
}
