#!/usr/bin/env python3
"""Exercise notification expansion/dismissal and complete live audio controls offscreen."""
from pathlib import Path
import os, shutil, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='titonium-polish-ui-') as td:
    base=Path(td); mods=base/'qs/Titonium'; mods.mkdir(parents=True)
    def module(name, files):
        p=mods/name; p.mkdir(parents=True,exist_ok=True)
        exports=['module qs.Titonium.'+name.replace('/','.')]
        for n,source in files.items():
            (p/(n+'.qml')).write_text(source)
            exports.append(('singleton ' if 'pragma Singleton' in source else '')+n+' 1.0 '+n+'.qml')
        (p/'qmldir').write_text('\n'.join(exports))
    module('Core/Runtime', {'Preferences':'''pragma Singleton
import QtQuick
QtObject {property var effectiveState:({appearance:{mode:"dark"},accessibility:{reducedMotion:true}})}''', 'I18n':'''pragma Singleton
import QtQuick
QtObject {function tr(k,args) {return k==="notification.group.label" ? args.name+" · "+args.count : k}}'''})
    for name in ('Theme','Services/Appearance'):
        (mods/name).parent.mkdir(parents=True,exist_ok=True)
        (mods/name).symlink_to(ROOT/'Titonium'/name,target_is_directory=True)
    shutil.copytree(ROOT/'Titonium/Shared',mods/'Shared')
    (mods/'Shared/SystemIcon.qml').write_text('import QtQuick\nItem {property string sourceName:"";property string fallbackName:"";property string tone:"";property string accessibleName:"";property int size:20}')
    module('Services/Audio', {'AudioService':'''pragma Singleton
import QtQuick
QtObject {
 property bool outputAvailable:true;property bool inputAvailable:false
 property string outputName:"ACTON II";property string inputName:"Unavailable";property string outputIcon:"volume_up"
 property real outputVolume:0.5;property real inputVolume:0;property real maximumOutputVolume:1
 property bool outputMuted:false;property bool inputMuted:false
 property var outputDevices:[]
 property var playbackStreams:[{id:7,name:"Google Chrome",available:true,volume:0.5,muted:false}]
 readonly property string playbackStreamIdentity: JSON.stringify(playbackStreams.map(stream=>stream.id))
 readonly property var playbackStreamIds: JSON.parse(playbackStreamIdentity)
 property int targetId:0;property real requestedVolume:0
 function setStreamVolume(id,value) {targetId=id;requestedVolume=value;playbackStreams=[{id:7,name:"Google Chrome",available:true,volume:value,muted:false}];}
 function toggleStreamMute(id) {targetId=id;}
}'''})
    module('Services/Notifications', {'NotificationCoordinator':'''pragma Singleton
import QtQuick
QtObject {
 property var history:[];property string dismissed:"";property string actionKey:""
 function dismiss(key) {dismissed=key;history=history.filter(n=>n.key!==key);}
 function dismissAll() {history=[];}
 function action(key,id) {actionKey=key+":"+id;}
}'''})
    shutil.copy2(ROOT/'Titonium/Services/Notifications/NotificationRules.js', mods/'Services/Notifications/NotificationRules.js')
    for name, components in [('Notifications',['NotificationHistoryContent','NotificationHistoryGroup','NotificationHistoryRow']),('Overlays/Audio',['ConnectedAudioPopupContent','AudioStreamRow','AudioSlider','AudioControlRow','AudioOutputDeviceRow'])]:
        module(name,{n:(ROOT/'Titonium'/name/(n+'.qml')).read_text() for n in components})
    shutil.copy2(ROOT/'Titonium/Overlays/Audio/AudioGeometry.js',mods/'Overlays/Audio/AudioGeometry.js')
    (base/'tst_polish.qml').write_text('''import QtQuick
import QtTest
import qs.Titonium.Notifications
import qs.Titonium.Overlays.Audio
import qs.Titonium.Services.Audio
import qs.Titonium.Services.Notifications
Item {
 width:900;height:750
 ConnectedAudioPopupContent {id:audio; width:380;height:implicitContentHeight}
 NotificationHistoryContent {id:history;x:430;width:420;height:640}
 TestCase {
 name:"PolishUI";when:windowShown
 function childrenWith(item,prop,result) {
  if (item[prop]!==undefined)result.push(item);
  for (const child of item.children) childrenWith(child,prop,result);
  return result;
 }
 function test_audio_complete_row_and_live_drag() {
  wait(30); compare(audio.streamHeight,72);
  const natural=audio.implicitContentHeight;
  audio.availableViewportHeight=70;wait(20);compare(audio.implicitContentHeight,natural);
  const rows=childrenWith(audio,"stream",[]);compare(rows.length,1);verify(rows[0].height>=72);
  const sliders=childrenWith(rows[0],"serviceValue",[]);compare(sliders.length,1);
  const slider=sliders[0]; const point=slider.mapToItem(audio,0,slider.height);
  verify(point.y<=audio.height,"application slider must fit inside the full viewport");
  mousePress(slider,slider.width/2,slider.height/2);
  mouseMove(slider,slider.width*.8,slider.height/2,20);
  compare(AudioService.targetId,7);verify(AudioService.requestedVolume>.65,"drag must reach service before release");
  mouseRelease(slider,slider.width*.8,slider.height/2);
  const buttons=childrenWith(rows[0],"iconName",[]);buttons[0].activate();compare(AudioService.targetId,7);
 }
 function notice(key,app) {return {key:key,source:"native",appId:app,appName:app,appIcon:"",category:"",severity:"normal",summary:"Screenshot saved",body:"/home/cole/Pictures/Screenshots/Screenshot.png",actions:[{id:"open",label:"Open"}]};}
 function test_group_expand_actions_dismiss_and_clear() {
  NotificationCoordinator.history=[notice("new","Screenshots"),notice("other","Chat"),notice("old","Screenshots")];wait(50);
  compare(history.groups.length,2);
  let rows=childrenWith(history,"notification",[]);compare(rows.length,2);
  const latest=rows.find(r=>r.notification.key==="new");
  mouseClick(latest,latest.width/2,latest.height/2);wait(30);
  rows=childrenWith(history,"notification",[]);compare(rows.length,3);
  const old=rows.find(r=>r.notification.key==="old");
  childrenWith(old,"label",[]).find(b=>b.label==="Open").activate();compare(NotificationCoordinator.actionKey,"old:open");
  childrenWith(old,"iconName",[]).find(b=>b.iconName==="close").activate();wait(20);compare(NotificationCoordinator.dismissed,"old");compare(history.groups[0].items.length,1);
  NotificationCoordinator.dismissAll();wait(20);compare(history.groups.length,0);
 }
 }
}''')
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(base),'-import',str(base)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'))
    raise SystemExit(result.returncode)
