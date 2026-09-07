#!/usr/bin/env python3
"""Isolated Expanded UI acceptance; all runtime/service inputs are fixtures."""
import os
import json
import sys
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

I18N_EN = {
    "center.expanded.tab.dashboard": "Dashboard",
    "center.expanded.tab.tasks": "Tasks",
    "center.expanded.tab.monitoring": "Monitoring",
    "center.expanded.tab.wallpapers": "Wallpapers",
    "center.expanded.close": "Close expanded view",
    "center.expanded.music": "Music",
    "center.expanded.music_empty": "No music player is available. Open a player to see playback controls here.",
    "center.expanded.context_unavailable": "This activity is no longer available.",
    "center.expanded.activities": "Current activities",
    "center.expanded.activities_empty": "No current activities.",
    "center.expanded.open_tasks": "Open in Tasks",
    "center.expanded.today_focus": "Today’s Focus",
    "center.expanded.focus_empty": "Choose today’s focus in your Today Focus file.",
    "center.expanded.focus_source": "Today Focus reads the first entry for today from:",
    "center.expanded.focus_cancel": "End focus session",
    "center.expanded.focus_start": "Start 25-minute focus",
    "center.expanded.tasks_activity": "Jobs and timers",
    "center.expanded.tasks_empty": "No active jobs or timers. Activities started by connected tools appear here.",
    "center.expanded.unavailable": "Unavailable",
    "center.expanded.metric.cpu": "CPU",
    "center.expanded.metric.ram": "Memory",
    "center.expanded.metric.gpu": "GPU",
    "center.expanded.metric.vram": "GPU memory",
    "center.expanded.metric.storage": "Storage",
    "center.expanded.processes": "Top processes · CPU",
}

def main():
    if '--i18n' in sys.argv:
        print(json.dumps(I18N_EN, ensure_ascii=False, indent=2))
        return 0
    names = ('ExpandedContent', 'DashboardContent', 'TasksContent', 'MonitoringContent')
    for name in names:
        assert (ROOT / 'Titonium/Bar/center' / (name + '.qml')).exists(), name + ' is missing'
    with tempfile.TemporaryDirectory(prefix='titonium-expanded-') as directory:
        base = Path(directory)
        def module(name, sources):
            target = base / name.replace('.', '/')
            target.mkdir(parents=True, exist_ok=True)
            exports = ['module ' + name]
            for key, source in sources.items():
                (target / (key + '.qml')).write_text(source)
                exports.append(('singleton ' if 'pragma Singleton' in source else '') + key + ' 1.0 ' + key + '.qml')
            (target / 'qmldir').write_text('\n'.join(exports))
            return target
        module('qs.Titonium.Core.Runtime', {
            'Preferences': 'pragma Singleton\nimport QtQuick\nQtObject { property bool reducedMotion: true; readonly property var effectiveState: ({appearance:settings.appearance,accessibility:{reducedMotion:reducedMotion}}); property var settings: ({appearance:{mode:"dark"}}) }',
            'I18n': 'pragma Singleton\nimport QtQuick\nQtObject { property var catalog: (' + json.dumps(I18N_EN) + '); function tr(k) { return catalog[k] || k; } }'})
        module('qs.Titonium.Services.MediaSpectrum', {'MediaSpectrumService': 'pragma Singleton\nimport QtQuick\nQtObject { property var spectrum: [] }'})
        module('Quickshell.Widgets', {'ClippingRectangle': 'import QtQuick\nRectangle { clip: true }'})
        module('qs.Titonium.Services.Center', {
            'FocusSessionService': (ROOT / 'Titonium/Services/Center/FocusSessionService.qml').read_text(),
            'CenterFocusStore': 'pragma Singleton\nimport QtQuick\nQtObject { property string text: "Fixture focus"; property string focusPath: "/fixture/daily-focus.md" }'})
        module('qs.Titonium.Services.SystemMonitor', {'SystemMonitorService': 'pragma Singleton\nimport QtQuick\nQtObject { property var snapshot: ({cpu:null,ram:null,gpu:null,vram:null,storage:null}); property var processes: [] }'})
        for name in ('Shared', 'Theme', 'Services/Appearance'):
            (base / 'qs/Titonium' / name).symlink_to(ROOT / 'Titonium' / name, target_is_directory=True)
        sources = {name: (ROOT / 'Titonium/Bar/center' / (name + '.qml')).read_text() for name in names}
        sources.update({p.stem: p.read_text() for p in (ROOT / 'Titonium/Bar/center').glob('Music*.qml')})
        sources['ScreenshotPreviewContent'] = (ROOT / 'Titonium/Bar/center/ScreenshotPreviewContent.qml').read_text()
        sources['WallpapersContent'] = 'import QtQuick\nItem { required property string screenName; implicitHeight: 200 }'
        center = module('qs.Titonium.Bar.center', sources)
        shutil.copy(ROOT / 'Titonium/Bar/center/MusicPlayerRules.js', center)
        (base / 'screenshot.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="30"><rect width="40" height="30" fill="blue"/></svg>')
        (base / 'tst_expanded.qml').write_text('''import QtQuick
import QtTest
import qs.Titonium.Bar.center
import qs.Titonium.Services.Center
TestCase {
 id: test
 name: "ExpandedContent"
 when: windowShown
 width: 900; height: 600
 visible: true
 property var received: null
 ExpandedContent {
  id: panel; width: 800; height: 500
  snapshot: ({contexts:[],capabilities:{actions:[]}})
  viewState: ({ownerScreenName:"fixture"})
  onIntentRequested: intent => test.received = intent
 }
 function init() {
  failOnWarning(/.*Binding loop.*/)
  panel.width = 800; panel.height = 500
  test.forceActiveFocus()
  panel.viewState = {expandedTab:"dashboard",ownerScreenName:"fixture"}
  panel.snapshot = {contexts:[],capabilities:{actions:[]}}
  received = null
  wait(10)
 }
 Component {
  id: openingPanel
  ExpandedContent {
   id: openingRoot
   width: 0; height: 0
   snapshot: ({contexts:[{id:"focus:daily",source:"focus",kind:"daily",title:"Today focus with a long descriptive line that wraps during opening",details:{}}],capabilities:{actions:[]}})
   viewState: ({expandedTab:"dashboard",ownerScreenName:"fixture"})
   ParallelAnimation {
    running: true
    NumberAnimation { target: openingRoot; property: "width"; from: 0; to: 720; duration: 250 }
    NumberAnimation { target: openingRoot; property: "height"; from: 0; to: 500; duration: 250 }
   }
  }
 }
 function test_opening_animation() {
  let opening = createTemporaryObject(openingPanel,test)
  verify(opening)
  wait(350)
  compare(opening.width,720); compare(opening.height,500)
 }
 function test_narrow_header() {
  panel.width = 320
  wait(30)
  let close = findChild(panel,"expandedClose")
  verify(close.mapToItem(panel,close.width,0).x <= panel.width,"Close must remain inside a 320px panel")
  let strip = findChild(panel,"expandedTabScroll")
  let last = findChild(panel,"expandedTab_wallpapers")
  let closeX = close.mapToItem(panel,0,0).x
  last.forceActiveFocus(); wait(20)
  verify(strip.contentX > 0)
  verify(last.mapToItem(strip,0,0).x >= 0)
  verify(last.mapToItem(strip,last.width,0).x <= strip.width)
  compare(close.mapToItem(panel,0,0).x,closeX)
  keyClick(Qt.Key_Right); wait(20)
  compare(strip.contentX,0)
  compare(received.tab,"dashboard")
 }
 function test_dashboard_geometry() {
  let contexts = []
  for (let index = 0; index < 12; index++)
   contexts.push({id:"focus:" + index,source:"focus",kind:"daily",title:("Today focus with wrapping text ").repeat(10),subtitle:"",details:{}})
  for (let size of [[760,0],[760,140],[760,480],[560,320],[980,600]]) {
   panel.width = size[0]; panel.height = size[1]
   panel.snapshot = {contexts:contexts,capabilities:{actions:[]}}
   wait(40)
   let body = findChild(panel,"expandedBody")
   verify(Number.isFinite(body.height))
   if (size[1] > 140) {
    verify(body.item.implicitHeight > panel.height)
    verify(body.height >= body.item.implicitHeight)
    let close = findChild(panel,"expandedClose")
    verify(close.mapToItem(panel,0,0).y < 60)
    verify(body.mapToItem(panel,0,0).y < 70)
   }
   panel.snapshot = {contexts:[],capabilities:{actions:[]}}
   wait(40)
   if (size[1] >= 320)
    compare(findChild(panel,"expandedBody").height, size[1] - 49)
  }
 }
 function test_tabs() {
  compare(panel.selectedTab, "dashboard")
  let tab = findChild(panel, "expandedTab_tasks")
  verify(tab)
  mouseClick(tab)
  compare(received.type, "select-tab"); compare(received.tab, "tasks")
  compare(panel.selectedTab, "dashboard")
  tab.forceActiveFocus(); keyClick(Qt.Key_Right)
  compare(received.tab, "monitoring")
  keyClick(Qt.Key_Tab)
  verify(!findChild(panel, "expandedTab_monitoring").activeFocus)
  mouseClick(findChild(panel, "expandedClose"))
  compare(received.mode, "compact")
 }
 function test_pages_and_session() {
  FocusSessionService.start(1500)
  let deadline = FocusSessionService.session.deadline
  for (let tab of ["tasks", "monitoring", "wallpapers", "dashboard"]) {
   test.forceActiveFocus()
   panel.viewState = {expandedTab:tab, ownerScreenName:"fixture", selectedContextId:"focus:session"}
   wait(30)
   compare(FocusSessionService.session.deadline, deadline)
   verify(findChild(panel, "expandedBody").item)
  }
  FocusSessionService.cancel()
 }
 function test_monitor_values() {
  panel.viewState = {expandedTab:"monitoring"}; wait(30)
  let page = findChild(panel, "expandedBody").item
  verify(page.percent(null) !== "0%")
  compare(page.percent(0), "0%")
  compare(page.percent(87.6), "88%")
 }
 function test_task_action_and_keyboard() {
  panel.viewState = {expandedTab:"tasks",selectedContextId:"job:fixture"}
  panel.snapshot = {contexts:[{id:"job:fixture",source:"job",title:"Fixture job",progress:0.5}],capabilities:{actions:[{id:"job.clear",contextId:"job:fixture",enabled:true,label:"Clear"}]}}
  wait(30)
  let tab = findChild(panel,"expandedTab_tasks")
  tab.forceActiveFocus(); keyClick(Qt.Key_Tab)
  verify(findChild(panel,"focusSessionAction").activeFocus)
 }
 function test_dashboard_selected_details() {
  panel.viewState = {expandedTab:"dashboard",selectedContextId:"capture:screenshot:fixture"}
  panel.snapshot = {contexts:[{id:"job:other",source:"job",title:"Other"},
   {id:"capture:screenshot:fixture",source:"capture",kind:"screenshot",title:"Selected screenshot",details:{imageUrl:""}}],capabilities:{actions:[]}}
  wait(30)
  let selected = findChild(panel,"dashboardSelectedDetail")
  verify(selected && selected.item)
  compare(selected.item.context.id,"capture:screenshot:fixture")
  verify(findChild(selected,"screenshotPreviewStatus"))
  verify(selected.y < findChild(panel,"dashboardMusicHeading").y)
  panel.snapshot = {contexts:[{id:"capture:screenshot:fixture",source:"capture",kind:"screenshot",title:"Selected screenshot",details:{imageUrl:Qt.resolvedUrl("screenshot.svg")}}],capabilities:{actions:[]}}
  wait(30)
  let preview = findChild(selected,"screenshotPreviewImage")
  verify(preview)
  tryCompare(preview,"status",Image.Ready)
  compare(preview.source,Qt.resolvedUrl("screenshot.svg"))
 }
 function test_dashboard_context_actions() {
  for (let source of ["notification","agent","capture"]) {
   let id = source + ":fixture"
   let actionId = source + ".fixture-action"
   let context = {id:id,source:source,kind:source === "agent" ? "approval-required" : "notification",title:"Summary",subtitle:"Subtitle",details:{body:"Complete body",command:"fixture command --argument",appName:"Fixture app"}}
   panel.viewState = {expandedTab:"dashboard",selectedContextId:id}
   panel.snapshot = {contexts:[context],capabilities:{actions:[{id:actionId,contextId:id,enabled:true,label:"Fixture action",role:"primary"}]}}
   wait(30)
   let selected = findChild(panel,"dashboardSelectedDetail")
   verify(selected && selected.item)
   compare(findChild(selected,"dashboardContextBody").text,"Complete body")
   compare(findChild(selected,"dashboardContextCommand").text,"fixture command --argument")
   let button = findChild(selected,"dashboardAction_" + actionId)
   verify(button && button.enabled)
   mouseClick(button)
   compare(received.type,"invoke-action"); compare(received.actionId,actionId); compare(received.contextId,id)
   panel.snapshot = {contexts:[context],capabilities:{actions:[{id:actionId,contextId:id,enabled:false,label:"Fixture action"}]}}
   wait(30)
   verify(!findChild(selected,"dashboardAction_" + actionId).enabled)
   panel.snapshot = {contexts:[],capabilities:{actions:[]}}
   wait(30)
   verify(!findChild(panel,"dashboardAction_" + actionId))
   verify(findChild(panel,"dashboardContextUnavailable").visible)
  }
 }
 function test_music() {
  panel.viewState = {expandedTab:"dashboard", selectedContextId:"media:current"}
  panel.snapshot = {contexts:[{id:"media:current",source:"media",title:"Paused track",details:{playing:false,playback:{}}}],capabilities:{actions:[]}}
  wait(30)
  verify(findChild(panel,"musicToggle"))
  verify(!findChild(panel,"musicToggle").enabled)
  panel.snapshot = {contexts:[],capabilities:{actions:[]}}
  wait(30)
  verify(!findChild(panel,"musicToggle"))
 }
}
''')
        lint = subprocess.run(['/usr/lib/qt6/bin/qmllint', '-I', str(base)] + [str(center / (name + '.qml')) for name in names])
        if lint.returncode:
            return lint.returncode
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
        return subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(base), '-import', str(base)], env=env).returncode

if __name__ == '__main__':
    raise SystemExit(main())
