#!/usr/bin/env python3
"""Pixel-test the actual edge contour, including two opposed shoulders with a clear gap."""
from pathlib import Path
import os, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='titonium-edge-contour-') as tmp:
 b=Path(tmp);m=b/'qs/Titonium'
 for name in ['Shared','Theme','Services/Appearance']:
  shutil.copytree(ROOT/'Titonium'/name,m/name)
 p=m/'Core/Runtime';p.mkdir(parents=True)
 (p/'qmldir').write_text('module qs.Titonium.Core.Runtime\nsingleton Preferences 1.0 Preferences.qml\n')
 (p/'Preferences.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {property var effectiveState:({appearance:{themeId:"neutral",mode:"dark"},accessibility:{reducedMotion:true}})}')
 shutil.copy2(ROOT/'Titonium/Bar/right/EdgeMenuGeometry.js',b/'EdgeMenuGeometry.js')
 (b/'tst_contour.qml').write_text('''import QtQuick
import QtTest
import qs.Titonium.Shared
import "EdgeMenuGeometry.js" as Geometry
Rectangle {
 id:host;width:500;height:400;color:"#ff00ff"
 property var branch: Geometry.branchRect("right",276,28,220,500,380,280,1)
 AnchoredMenuPillShape {
  id:contour;anchors.fill:parent;edge:"right"
  compactX:host.branch.x-16;compactWidth:host.width-compactX
  branchX:host.branch.x;branchY:host.branch.y
  branchWidth:host.branch.width;branchHeight:host.branch.height;color:"#202020"
 }
 ScreenCorner {x:484;y:36;width:16;height:16;rotation:90;color:"#202020"}
 TestCase {
 name:"EdgeContour";when:windowShown
 function test_opposed_shoulders_and_rounded_bottom() {
  wait(40);const image=grabImage(host);
  compare(host.branch.x+host.branch.width,452,"popup must reserve 48px for two shoulders and breathing room");
  compare(image.pixel(460,80),Qt.color("#ff00ff"),"clear gap continues below the shoulders");
  compare(image.pixel(475,40),Qt.color("#ff00ff"),"the opposing shoulders must not touch");
  compare(image.pixel(453,38),Qt.color("#202020"),"popup outer shoulder remains attached to the rail");
  compare(image.pixel(498,38),Qt.color("#202020"),"screen shoulder faces the popup");
  compare(image.pixel(450,279),Qt.color("#ff00ff"),"bottom corner remains rounded");
  compare(image.pixel(300,200),Qt.color("#202020"),"one contour paints the tall body");

 }
 }
}''')
 r=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(b),'-import',str(b)],env={**os.environ,'QT_QPA_PLATFORM':'offscreen','QT_QUICK_BACKEND':'software'},capture_output=True,text=True)
 print(r.stdout,end='');print(r.stderr,end='')
 raise SystemExit(r.returncode or int('QWARN' in r.stdout))
