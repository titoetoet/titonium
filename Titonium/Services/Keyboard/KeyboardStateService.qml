pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center

QtObject {
 id: root
 property bool capsLock: false
 property bool numLock: false
 property bool initialized: false
 function update(text) {
  try { const data=JSON.parse(text); const k=(data.keyboards||[])[0]||{}; const caps=k.capsLock===true; const num=k.numLock===true; if (root.initialized && caps!==root.capsLock) CenterAttentionService.publish({id:"input:caps",source:"input",kind:"caps_changed",title:I18n.tr(caps?"input.center.caps_on":"input.center.caps_off"),icon:"keyboard_capslock"}); if (root.initialized && num!==root.numLock) CenterAttentionService.publish({id:"input:num",source:"input",kind:"num_changed",title:I18n.tr(num?"input.center.num_on":"input.center.num_off"),icon:"dialpad"}); root.capsLock=caps; root.numLock=num; root.initialized=true; } catch (e) {}
 }
 property Process probe: Process {
  command: ["hyprctl", "-j", "devices"]
  running: true
  stdout: StdioCollector {
   onStreamFinished: root.update(text)
  }
  onExited: {
   root.poll.start()
  }
 }
 property Timer poll: Timer { interval:1000; repeat:false; onTriggered: root.probe.running=true }
 function activate(){ root.probe.running=true }
 Component.onCompleted: root.activate()
}
