#!/usr/bin/env python3
"""Exercise production bar hover/timer logic with Qt pointer events.
Native window chrome is replaced with an Item; real edge geometry is retained.
Inert islands expose no hover so the full-band gap retention is tested directly.
"""
import os
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--surface-source', type=Path, default=ROOT/'Titonium/Bar/BarSurface.qml', help='Optional saved pre-fix BarSurface for regression reproduction')
args=parser.parse_args()
with tempfile.TemporaryDirectory(prefix='titonium-bar-hover-') as tmp:
    base=Path(tmp);module=base/'qs/Titonium'
    def write(path,text):
        target=module/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(text)
    def singleton(folder,name,body):
        write(folder+'/'+name+'.qml','pragma Singleton\nimport QtQuick\nQtObject { '+body+' }\n')
    write('Bar/qmldir','module qs.Titonium.Bar\nBar 1.0 Bar.qml\nBarSurface 1.0 BarSurface.qml\n')
    write('Bar/Bar.qml','import QtQuick\nItem { property var screen; readonly property bool hovered:false;signal notificationsRequested(var screen,var invoker) }')
    write('Bar/classic/qmldir','module qs.Titonium.Bar.classic\nClassicBar 1.0 ClassicBar.qml\n')
    write('Bar/classic/ClassicBar.qml','import QtQuick\nItem {property var screen;readonly property bool hovered:false;signal notificationsRequested(var screen,var invoker)}')
    write('Bar/right/qmldir','module qs.Titonium.Bar.right\nsingleton RightPillCoordinator 1.0 RightPillCoordinator.qml\n')
    singleton('Bar/right','RightPillCoordinator','property string presentedStyle:"connected";property bool hovered:false;property bool presentationActive:false')
    write('Core/Surfaces/Center/qmldir','module qs.Titonium.Core.Surfaces.Center\nsingleton CenterSurfaceController 1.0 CenterSurfaceController.qml\n')
    singleton('Core/Surfaces/Center','CenterSurfaceController','property bool active:false')
    write('Core/Runtime/qmldir','module qs.Titonium.Core.Runtime\nsingleton Preferences 1.0 Preferences.qml\nsingleton BarVisibilityState 1.0 BarVisibilityState.qml\n')
    singleton('Core/Runtime','Preferences','property var bar:({autoHide:true});property bool previewActive:false;function patch(path,value){bar={autoHide:value};return true;} function commitPatch(path,value){return patch(path,value);}')
    write('Core/Runtime/BarVisibilityState.qml',(ROOT/'Titonium/Core/Runtime/BarVisibilityState.qml').read_text())
    write('Theme/qmldir','module qs.Titonium.Theme\nsingleton Metrics 1.0 Metrics.qml\nsingleton Motion 1.0 Motion.qml\n')
    singleton('Theme','Metrics','readonly property int barHeight:44;readonly property int widgetHeight:36')
    singleton('Theme','Motion','readonly property int fast:0')
    write('Bar/BarVisibilityRules.js',(ROOT/'Titonium/Bar/BarVisibilityRules.js').read_text())
    code=args.surface_source.read_text()
    code=code.replace('import Quickshell\n','').replace('import Quickshell.Wayland\n','').replace('PanelWindow {','Item {').replace('required property ShellScreen screenModel','required property var screenModel')
    code=code.replace('    id: root','    id: root\n    property var screen\n    property real exclusiveZone\n    property bool aboveWindows',1)
    code='\n'.join(line for line in code.splitlines() if 'WlrLayershell.' not in line and 'anchors { top: true;' not in line and 'color: "transparent"' not in line)
    start=code.index('    mask: Region {');brace=code.index('{',start);depth=1;end=brace+1
    while depth:
        if code[end]=='{':depth+=1
        if code[end]=='}':depth-=1
        end+=1
    code=code[:start]+code[end:]
    write('Bar/BarSurface.qml',code)
    test=base/'tst_hover.qml'
    test.write_text('''import QtQuick
import QtTest
import qs.Titonium.Bar
import qs.Titonium.Bar.right
import qs.Titonium.Core.Runtime
Item {
 width:800;height:180
 BarSurface {id:bar;width:800;height:44;screenModel:({name:"DP-1"})}
 TestCase {
  name:"BarHoverRetention";when:windowShown
  function init(){Preferences.bar={autoHide:true};BarVisibilityState.setCenterHovered("DP-1",false);mouseMove(bar,400,100);wait(300);}
  function test_gap_crossing_data(){return [{tag:"Connected",style:"connected"},{tag:"Classic",style:"classic"}];}
  function test_gap_crossing(data){
   RightPillCoordinator.presentedStyle=data.style;
   mouseMove(bar,220,1);wait(30);verify(bar.barRevealed);
   for(const x of [220,400,650]){mouseMove(bar,x,22);wait(320);verify(bar.barRevealed,"gap must retain hover past hide delay");}
   mouseMove(bar,650,70);wait(320);compare(bar.barRevealed,false);
  }
  function test_center_surface_handoff(){
   mouseMove(bar,220,1);wait(30);verify(bar.barRevealed);
   BarVisibilityState.setCenterHovered("DP-1",true);mouseMove(bar,400,100);wait(320);verify(bar.barRevealed);
   BarVisibilityState.setCenterHovered("DP-1",false);wait(320);compare(bar.barRevealed,false);
  }
  function test_other_screen_cannot_retain_bar(){
   BarVisibilityState.setCenterHovered("DP-3",true);wait(320);compare(bar.barRevealed,false);BarVisibilityState.setCenterHovered("DP-3",false);
  }
 }
}
''')
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(test),'-import',str(base)],env={**os.environ,'QT_QPA_PLATFORM':'offscreen','QT_QUICK_BACKEND':'software'},text=True,capture_output=True,timeout=30)
    print(result.stdout,end='');print(result.stderr,end='')
    if result.returncode or any(x in result.stdout+result.stderr for x in ['QWARN','TypeError','ReferenceError','Binding loop','Unable to assign']):raise SystemExit(result.returncode or 1)
