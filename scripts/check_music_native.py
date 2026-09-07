#!/usr/bin/env python3
"""Test production UI → adapter → MPRIS, including late capabilities, on private DBus."""
from pathlib import Path
import os, shutil, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
def main():
 with tempfile.TemporaryDirectory(prefix='titonium-native-music-') as td:
  base=Path(td)
  flags=subprocess.check_output(['pkg-config','--cflags','--libs','Qt6Core','Qt6DBus'],text=True).split()
  subprocess.run(['c++','-std=c++17','-fPIC',str(ROOT/'scripts/fixtures/music_mpris.cpp'),'-o',str(base/'player'),*flags],check=True)
  def module(name,files):
   path=base/'Titonium'/name;path.mkdir(parents=True,exist_ok=True)
   exports=['module qs.Titonium.'+name.replace('/','.')]
   for name,source in files.items():
    (path/(name+'.qml')).write_text(source)
    exports.append(('singleton ' if 'pragma Singleton' in source else '')+name+' 1.0 '+name+'.qml')
   (path/'qmldir').write_text('\n'.join(exports))
  module('Core/Runtime',{'I18n':'pragma Singleton\nimport QtQuick\nQtObject { function tr(k) {return k} }','Preferences':'pragma Singleton\nimport QtQuick\nQtObject { property bool reducedMotion: true; readonly property var effectiveState: ({appearance:settings.appearance,accessibility:{reducedMotion:reducedMotion}}); property var settings: ({appearance:{mode:"dark"}}) }'})
  module('Services/Center',{'CenterActivityService':'pragma Singleton\nimport QtQuick\nQtObject {function upsert(v) {} function remove(v) {}}','CenterAttentionService':'pragma Singleton\nimport QtQuick\nQtObject {function publish(v) {} function setIndicator(a,b,c,d) {}}'})
  module('Services/MediaSpectrum',{'MediaSpectrumService':'pragma Singleton\nimport QtQuick\nQtObject {property var spectrum: []}'})
  for name in ['Services/Mpris','Services/Appearance','Bar/center','Shared','Theme']:
   target=base/'Titonium'/name;target.parent.mkdir(parents=True,exist_ok=True)
   target.symlink_to(ROOT/'Titonium'/name,target_is_directory=True)
  shutil.copy(ROOT/'Titonium/Services/Center/adapters/MediaCenterAdapter.qml',base/'MediaAdapter.qml')
  (base/'shell.qml').write_text('''import QtQuick
import Quickshell
import qs.Titonium.Services.Mpris
import qs.Titonium.Bar.center
FloatingWindow {
 implicitWidth:640; implicitHeight:160; visible:true
 MediaAdapter {id:adapter}
 MusicPlayerContent {
  id:content;anchors.fill:parent
  context:adapter.contexts[0] || ({})
  actions:adapter.actions
  onIntentRequested:intent => adapter.dispatch(intent.actionId,intent.contextId,"")
 }
 function child(item,name) {
  if(item.objectName===name)return item;
  for(let c of item.children){let result=child(c,name);if(result)return result;}
  return null;
 }
 Timer {interval:600;running:true;onTriggered:{
  if(!MprisService.selectedPlayer || MprisService.selectedPlayer.canGoNext) throw new Error("FAIL bad initial fixture");
  MprisService.detailsActive=true;
 }}
 Timer {interval:3400;running:true;onTriggered:{
  let next=child(content,"musicNext");
  if(!next.enabled) {console.error("FAIL late capability remains disabled");Qt.quit();return;}
  if(MprisService.playbackDetails.nextTrack?.title!=="Next fixture") {console.error("FAIL native Up next metadata",JSON.stringify(MprisService.playbackDetails),JSON.stringify(MprisService.queue));Qt.quit();return;}
  child(content,"musicPrevious").activate();child(content,"musicToggle").activate();next.activate();
  if(!MprisService.seekTo(MprisService.selectedIdentity,MprisService.playbackDetails.trackToken,.5)) {console.error("FAIL seek");Qt.quit();return;}
  console.log("PASS native Music transport, late capabilities, seek and Up next");Qt.quit();
 }}
}''')
  (base/'run.sh').write_text('''#!/bin/sh
"$1/player" > "$1/calls.log" &
fixture_pid=$!
trap 'kill "$fixture_pid" 2>/dev/null; wait "$fixture_pid" 2>/dev/null' EXIT
qs -p "$1/shell.qml" --no-color
''')
  env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
  result=subprocess.run(['dbus-run-session','--','sh',str(base/'run.sh'),str(base)],env=env,capture_output=True,text=True,timeout=15)
  output=result.stdout+result.stderr
  print(output)
  calls=(base/'calls.log').read_text();print(calls)
  assert 'PASS native Music' in output and 'FAIL' not in output
  for call in ['Previous','Pause','Next','SetPosition']:
   assert 'CALL '+call in calls,call
if __name__=='__main__':main()
