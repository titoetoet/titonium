#!/usr/bin/env python3
"""Exercise screenshot identity, lazy preview, bounds and Satellite Music selection."""
from pathlib import Path
import os, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='titonium-preview-') as td:
 base=Path(td);mods=base/'qs/Titonium';mods.mkdir(parents=True)
 def module(name,files):
  path=mods/name;path.mkdir(parents=True,exist_ok=True)
  exports=['module qs.Titonium.'+name.replace('/','.')]
  for n,source in files.items():
   (path/(n+'.qml')).write_text(source)
   exports.append(('singleton ' if 'pragma Singleton' in source else '')+n+' 1.0 '+n+'.qml')
  (path/'qmldir').write_text('\n'.join(exports))
 module('Core/Runtime',{'Preferences':'pragma Singleton\nimport QtQuick\nQtObject {property bool reducedMotion:false;readonly property var effectiveState:({appearance:settings.appearance,accessibility:{reducedMotion:reducedMotion}});property var settings:({appearance:{mode:"dark"}}); property var bar:({mascotEnabled:false})}', 'I18n':'pragma Singleton\nimport QtQuick\nQtObject {function tr(k) {return k}}'})
 module('Services/MediaSpectrum',{'MediaSpectrumService':'pragma Singleton\nimport QtQuick\nQtObject {property var levels:[.2,.4,.8,.3];property var spectrum:[.2,.4,.6,.8]}'})
 (mods/'Services/Appearance').symlink_to(ROOT/'Titonium/Services/Appearance',target_is_directory=True)
 (mods/'Theme').symlink_to(ROOT/'Titonium/Theme',target_is_directory=True)
 shutil.copytree(ROOT/'Titonium/Shared',mods/'Shared')
 (mods/'Shared/SystemIcon.qml').write_text('import QtQuick\nItem {property string sourceName:"";property string fallbackName:"";property string tone:"";property string accessibleName:"";property int size:20}')
 widgets=base/'Quickshell/Widgets';widgets.mkdir(parents=True)
 (widgets/'qmldir').write_text('module Quickshell.Widgets\nClippingRectangle 1.0 ClippingRectangle.qml\n')
 (widgets/'ClippingRectangle.qml').write_text('import QtQuick\nRectangle {clip:true}')
 (mods/'Bar').mkdir();shutil.copytree(ROOT/'Titonium/Bar/center',mods/'Bar/center')
 # Expanded Dashboard composition is covered by check_expanded_content.py.
 (mods/'Bar/center/ExpandedContent.qml').write_text('import QtQuick\nItem {required property var snapshot;required property var viewState;signal intentRequested(var intent); ScreenshotPreviewContent {anchors.fill: parent; context: parent.snapshot.contexts.find(c => c.id === parent.viewState.selectedContextId)}}')
 (base/'image.ppm').write_bytes(b'P6\n200 100\n255\n'+bytes([40,160,220])*200*100)
 (base/'tst_preview.qml').write_text('''import QtQuick
import QtTest
import qs.Titonium.Core.Runtime
import qs.Titonium.Bar.center.presentations.Connected
import qs.Titonium.Bar.center.presentations.Classic
Item {
 id:host; width:1000;height:700
 property var shot:({id:"capture:shot:1",source:"capture",kind:"screenshot",title:"Saved screenshot",details:{imageUrl:"IMAGE"}})
 property var focusContext:({id:"focus:1",source:"focus",title:"Focus"})
 property var media:({id:"media:1",source:"media",title:"Satellite Song",details:{playing:true}})
 property var state:({mode:"compact",selectedContextId:"",generation:1})
 property var snapshotData:({primary:focusContext,contexts:[focusContext,shot,media],compact:{primary:focusContext,secondary:media,idle:false},capabilities:{actions:[]}})
 ConnectedRenderer {id:connected;anchors.fill:parent;snapshot:host.snapshotData;viewState:host.state
 profile:({id:"connected",compact:{height:32,radius:18},banner:{radius:22},expanded:{radius:28},transitions:{contextChange:"crossfade"}})}
 ClassicRenderer {id:classic;anchors.fill:parent;snapshot:host.snapshotData;viewState:host.state;presentationActive:true;transitionOwner:true
 profile:({id:"classic",compact:{height:32,radius:18},banner:{width:480,height:72,radius:22},expanded:{width:720,height:440,radius:28},transitions:{contextChange:"crossfade"}})}
 TestCase {
 name:"ScreenshotPreview";when:windowShown
 function select(mode,id) {host.state={mode:mode,selectedContextId:id,generation:host.state.generation+1};wait(450);}
 function test_exact_image_lazy_bounded_and_error() {
 Preferences.reducedMotion=true;
 verify(findChild(connected,"screenshotPreviewImage")===null);verify(findChild(classic,"screenshotPreviewImage")===null);
 select("banner",host.shot.id);
 verify(findChild(connected,"screenshotPreviewImage")===null);
 select("expanded",host.shot.id);
 for (const renderer of [connected,classic]) {
 const img=findChild(renderer,"screenshotPreviewImage");verify(img!==null);
 tryCompare(img,"status",Image.Ready);compare(img.source.toString(),host.shot.details.imageUrl);
 compare(img.fillMode,Image.PreserveAspectFit);verify(img.width>100);verify(img.height>100);
 verify(Math.abs(img.paintedWidth/img.paintedHeight-2)<.01);
 }
 select("expanded",host.shot.id);host.width=320;host.height=260;wait(100);
 for (const renderer of [connected,classic]) {const img=findChild(renderer,"screenshotPreviewImage");verify(img.width<=host.width);verify(img.height<=host.height);verify(img.height>0);}
 host.shot={id:"capture:shot:1",source:"capture",kind:"screenshot",title:"Saved screenshot",details:{imageUrl:""}};wait(100);
 for (const renderer of [connected,classic]) {const msg=findChild(renderer,"screenshotPreviewStatus");verify(msg.visible);compare(msg.text,"capture.preview_unavailable");}
 select("compact","");verify(findChild(connected,"screenshotPreviewImage")===null);verify(findChild(classic,"screenshotPreviewImage")===null);
 }
 function test_satellite_music_keeps_selected_title() {
 host.width=1000;host.height=700;Preferences.reducedMotion=false;select("banner",host.media.id);
 compare(connected.context.id,host.media.id);compare(connected.context.title,"Satellite Song");compare(classic.popupContext.id,host.media.id);
 select("compact","");compare(host.snapshotData.compact.primary.id,host.focusContext.id);
 }
 }
}'''.replace('IMAGE',(base/'image.ppm').as_uri()))
 result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(base),'-import',str(base)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'))
 raise SystemExit(result.returncode)
