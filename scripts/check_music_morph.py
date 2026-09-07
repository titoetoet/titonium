#!/usr/bin/env python3
"""Verify Connected compact → read-only banner → Expanded after tab migration."""
from pathlib import Path
import os, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='titonium-morph-') as td:
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
 # The tab body has its own production UI test; isolate that boundary here.
 (mods/'Bar/center/ExpandedContent.qml').write_text('import QtQuick\nItem {required property var snapshot;required property var viewState;signal intentRequested(var intent)}')
 (base/'tst_morph.qml').write_text('''import QtQuick
import QtTest
import qs.Titonium.Core.Runtime
import qs.Titonium.Bar.center.presentations.Connected
Item {
 width:1000;height:600
 ConnectedRenderer {
  id:renderer; anchors.fill:parent
  property var media:({id:"media:current",source:"media",title:"Slow Motion",subtitle:"Kai Rivers",details:{playing:true}})
  snapshot:({primary:media,contexts:[media],compact:{primary:media,idle:false},capabilities:{actions:[]}})
  viewState:({mode:"compact",selectedContextId:"media:current",generation:1})
  profile:({id:"connected",compact:{height:32,radius:18},banner:{radius:22},expanded:{radius:28}})
 }
 TestCase {
  name:"ConnectedPreview";when:windowShown
  SignalSpy {id:spy;target:renderer;signalName:"intentRequested"}
  function mode(value) {renderer.viewState={mode:value,selectedContextId:"media:current",generation:renderer.viewState.generation+1};}
  function test_preview_then_expanded() {
   const shape=findChild(renderer,"connectedCenterShell");
   verify(!shape.visible);
   mode("banner");wait(200);
   verify(shape.visible);compare(shape.bodyHeight,renderer.headerHeight+88);
   verify(findChild(renderer,"musicToggle")===null,"Normal Banner has no transport controls");
   mouseClick(renderer,renderer.width/2,renderer.headerHeight+40);
   compare(spy.signalArguments[spy.count-1][0].type,"activate-preview");
   compare(spy.signalArguments[spy.count-1][0].contextId,"media:current");
   mode("expanded");wait(200);
   verify(findChild(renderer,"connectedExpandedContent").active);
   verify(shape.bodyHeight>renderer.headerHeight+88);
   verify(findChild(renderer,"connectedCenterTitle").visible);
   verify(findChild(renderer,"connectedExpandedContent").y>=renderer.headerHeight);
   mode("compact");wait(200);
   verify(!shape.visible);verify(!findChild(renderer,"connectedExpandedContent").active);
   Preferences.reducedMotion=true;mode("banner");wait(20);compare(shape.bodyHeight,renderer.headerHeight+88);
   mode("closed");wait(20);verify(!shape.visible);
  }
 }
}''')
 result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(base),'-import',str(base)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'))
 raise SystemExit(result.returncode)
