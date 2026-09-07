#!/usr/bin/env python3
"""Exercise real shared QML paint properties in an isolated offscreen Qt runtime."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='titonium-material-') as temporary:
    base = Path(temporary)
    module = base / 'qs/Titonium'
    shutil.copytree(ROOT / 'Titonium/Shared', module / 'Shared')
    shutil.copytree(ROOT / 'Titonium/Theme', module / 'Theme')
    shutil.copytree(ROOT / 'Titonium/Services/Appearance', module / 'Services/Appearance')
    runtime = module / 'Core/Runtime'
    runtime.mkdir(parents=True)
    (runtime / 'qmldir').write_text('module qs.Titonium.Core.Runtime\nsingleton Preferences 1.0 Preferences.qml\n')
    (runtime / 'Preferences.qml').write_text('''pragma Singleton
import QtQuick
QtObject { property var effectiveState: ({appearance:{themeId:"neutral",mode:"dark"},accessibility:{reducedMotion:true}})
 readonly property var settings: effectiveState
 readonly property var bar: ({height:44}) }
''')
    (base / 'tst_material.qml').write_text('''import QtQuick
import QtTest
import qs.Titonium.Shared
import qs.Titonium.Theme
import qs.Titonium.Services.Appearance
Item {
 width: 500; height: 500
 Surface { id: surface; width: 140; height: 80; Text { id: label; text:"Opaque content"; color:Theme.textPrimary } }
 Panel { id: panel; y:100; width:160; height:100 }
 Surface { id: explicitRadius; radius:7; width:80; height:40 }
 ConnectedPillShape { id: connected; y:230; bodyWidth:180; bodyHeight:48; color:Theme.surface }
 AnchoredMenuPillShape { id: anchored; y:300; width:300; height:150; compactWidth:220; branchX:30; branchWidth:170; branchHeight:90; color:Theme.surface }
 InteractionFeedback { id: feedback; width:100; height:40; hovered:true; focused:true }
 TestCase {
  name:"AppearanceMaterial"; when:windowShown
  function candidate(id, overrides) { return {appearance:{themeId:id,mode:"dark",themeOverrides:overrides || {}},reducedMotion:true} }
  function test_materials() {
   AppearanceService.setTrial(candidate("neutral"),1); wait(20)
   var paint=findChild(surface,"appearancePaint")
   verify(paint !== null,"Surface exposes actual material paint for inspection")
   compare(paint.color,Theme.surface); compare(paint.opacity,1); compare(paint.border.width,Metrics.borderWidth)
   compare(paint.border.color,Theme.border); compare(surface.radius,Metrics.radiusSmall)
   compare(panel.radius,Metrics.radiusLarge); compare(label.opacity,1); compare(surface.opacity,1)
   compare(findChild(surface,"appearanceShadow").visible,false)
   compare(findChild(surface,"appearanceSheen").visible,false)
   compare(findChild(connected,"appearancePath").strokeWidth,0)
   compare(findChild(connected,"appearancePath").fillColor,Theme.surface)
   compare(feedback.hoverStrength,.12)
   var neutralImage=grabImage(surface)
   compare(neutralImage.pixel(120,65),Theme.surface,"Neutral center paint matches original opaque surface")
   var width=connected.width, height=connected.height, radius=connected.safeRadius, attachment=anchored.attachmentX
   AppearanceService.setTrial(candidate("glass",{glass:{dark:{backgroundOpacity:.85,borderStrength:.3,shadowStrength:1,sheenStrength:1,radiusScale:1.25}}}),2);wait(20)
   fuzzyCompare(paint.color.a,.85,.005); fuzzyCompare(paint.border.color.a,.3,.005)
   verify(findChild(surface,"appearanceShadow").visible);verify(findChild(surface,"appearanceSheen").visible)
   compare(surface.radius,Math.round(Metrics.radiusSmall*1.25));compare(panel.radius,Math.round(Metrics.radiusLarge*1.25));compare(explicitRadius.radius,7)
   compare(surface.opacity,1);compare(label.opacity,1);compare(connected.width,width);compare(connected.height,height);compare(connected.safeRadius,radius);compare(anchored.attachmentX,attachment)
   verify(feedback.hoverStrength>.12);verify(findChild(feedback,"appearanceFocus").visible)
   AppearanceService.setTrial(candidate("glass",{glass:{dark:{shadowStrength:0,sheenStrength:0,borderStrength:0}}}),3);wait(20)
   compare(findChild(surface,"appearanceShadow").visible,false);compare(findChild(surface,"appearanceSheen").visible,false);compare(paint.border.color.a,0)
   compare(feedback.hoverStrength,.12);verify(findChild(feedback,"appearanceFocus").visible)
   AppearanceService.clearTrial(3)
  }
 }
}
''')
    runner = shutil.which('qmltestrunner') or '/usr/lib/qt6/bin/qmltestrunner'
    result = subprocess.run([runner, '-input', str(base), '-import', str(base)], env={**os.environ, 'QT_QPA_PLATFORM':'offscreen', 'QT_QUICK_BACKEND':'software'},capture_output=True,text=True)
    print(result.stdout,end='');print(result.stderr,end='')
    if result.returncode or 'QWARN' in result.stdout or 'ReferenceError' in result.stderr:
        raise SystemExit(result.returncode or 1)
