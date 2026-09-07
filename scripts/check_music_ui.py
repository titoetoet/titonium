#!/usr/bin/env python3
"""Exercise unchanged Music QML/Shared/Theme; fake only runtime and audio input.

Never launch a music application, mutate system playback or write clipboard data.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    if '--native' in sys.argv and '--wayland' not in sys.argv:
        print('Native artwork capture requires --native --wayland and an unlocked compositor.', file=sys.stderr)
        return 2
    with tempfile.TemporaryDirectory(prefix='titonium-music-ui-') as directory:
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
        translations = json.loads((ROOT / 'config/i18n/en.json').read_text())['strings']
        module('qs.Titonium.Core.Runtime', {
            'Preferences': 'pragma Singleton\nimport QtQuick\nQtObject { property bool reducedMotion: false; readonly property var effectiveState: ({appearance:settings.appearance,accessibility:{reducedMotion:reducedMotion}}); property var settings: ({appearance:{mode:"dark"}}) }',
            'I18n': 'pragma Singleton\nimport QtQuick\nQtObject { property var catalog: (' + json.dumps(translations) + '); function tr(k) { return catalog[k] || k; } }'
        })
        module('qs.Titonium.Services.MediaSpectrum', {
            'MediaSpectrumService': 'pragma Singleton\nimport QtQuick\nQtObject { property var spectrum: [.2,.5,.8,.3,.4,.7,.3,.15,.2,.65,.3,.1,.4,.2,.9,.6,.4,.3,.7,.5,.3,.45,.2,.3] }'
        })
        # qmltestrunner cannot load Quickshell's statically linked clipping type.
        # Replace only that native boundary for interaction/layout tests. Native
        # visual capture is performed separately with qs and the real clipping type.
        if '--native' not in sys.argv: module('Quickshell.Widgets', {'ClippingRectangle': 'import QtQuick\nRectangle { clip: true }'})
        for name in ('Shared', 'Theme', 'Services/Appearance'):
            (base / 'qs/Titonium' / name).symlink_to(ROOT / 'Titonium' / name, target_is_directory=True)
        center = module('qs.Titonium.Bar.center', {p.stem: p.read_text()
            for p in (ROOT / 'Titonium/Bar/center').glob('Music*.qml')})
        shutil.copy(ROOT / 'Titonium/Bar/center/MusicPlayerRules.js', center)
        cover = (ROOT / 'docs/music-state-three/preview-cover.png').as_uri()
        out = ROOT / 'docs/music-state-three'
        (base / 'tst_music.qml').write_text('''import QtQuick
import QtTest
import qs.Titonium.Bar.center
import qs.Titonium.Theme
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.MediaSpectrum
TestCase {
    id: test
    name: "MusicPlayer"
    when: windowShown
    visible: true
    width: 860; height: 410
    property var received: []
    function context(token, seekable, queue) {
        return {id:"media:current", source:"media",title:"Slow Motion",subtitle:"Kai Rivers",
            details:{playing:true, trackArtUrl:COVER, playback:{identity:"player.a",trackToken:token,
                source:{label:"YouTube · Chromium",icon:"smart_display"},position:102,length:236,canSeek:seekable,queueStatus:"ready",nextTrack:queue
                    ? {title:"Chasing Dreams",artist:"Aria Nova",length:208,artUrl:COVER}:null}}};
    }
    Rectangle {
        id: frame
        width: 860; height: 300
        color: Theme.background
        Rectangle {
            x: 60; y: 58; width: player.width; height: player.height
            color: Theme.surface; radius:12; border.width:1; border.color:Theme.border
        }
        MusicPlayerContent {
            id: player
            x:60; y:58; width:604; height:152
            context: test.context(8, true, true)
            actions: [{id:"media.previous",contextId:"media:current",enabled:true},
                {id:"media.toggle",contextId:"media:current",enabled:true},
                {id:"media.next",contextId:"media:current",enabled:true},
                {id:"media.raise",contextId:"media:current",enabled:true}]
            onIntentRequested: intent => { test.received = test.received.concat([intent]); }
        }
    }
    function init() {
        received = [];
        Preferences.settings = {appearance:{mode:"dark"}};
        Preferences.reducedMotion = false;
        player.width=604; player.height=152;
        player.context=context(8,true,true);
        player.interactionEnabled=true;
        wait(200);
    }
    function test_sourcePresentation() {
        player.context=context(8,true,false);
        compare(findChild(player,"musicSourceHeading").text,I18n.tr("center.music.now_playing"));
        compare(findChild(player,"musicSourceLabel").text,"YouTube");
        verify(findChild(player,"musicSource").visible);
        player.context=context(8,true,true);
        compare(findChild(player,"musicSourceLabel").text,"YouTube");
    }
    Component {
        id: motionTitle
        MusicTransitionTitle {
            width: 120; height: 24
            text: "A long music title that must scroll in both states"
            playing: true
        }
    }
    function test_titleMotionBothStates() {
        const title=createTemporaryObject(motionTitle,test);
        verify(title !== null);
        for (const progress of [0,1]) {
            title.progress=progress;
            verify(title.scrolling);
            verify(title.shimmerActive);
            wait(1450);
            verify(title.scrollOffset>0);
            verify(title.sweep>-24);
            title.animationEnabled=false;
            compare(title.scrollOffset,0);
            verify(!title.shimmerActive);
            title.animationEnabled=true;
        }
        title.progress=.5;
        verify(!title.scrolling);
        verify(!title.shimmerActive);
        title.progress=1;
        Preferences.reducedMotion=true;
        compare(title.scrollOffset,0);
        verify(!title.scrolling);
        verify(!title.shimmerActive);
    }
    function test_transport() {
        mouseClick(findChild(player,"musicToggle"));
        compare(received.length,1);
        compare(received[0].actionId,"media.toggle");
        player.interactionEnabled=false;
        mouseClick(findChild(player,"musicNext"));
        compare(received.length,1);
    }
    function test_seekReleaseKeepsTarget() {
        const seek=findChild(player,"musicSeek");
        mousePress(seek,seek.width*.25,14);
        mouseMove(seek,seek.width*.8,14,100);
        mouseRelease(seek,seek.width*.8,14);
        compare(received.length,1);
        verify(received[0].fraction>.7, "release must not revert to old playback position");
        compare(received[0].trackToken,8);
    }
    function test_seekTrackChangeKeepsOriginalIdentity() {
        const seek=findChild(player,"musicSeek");
        mousePress(seek,seek.width*.25,14);
        mouseMove(seek,seek.width*.75,14,100);
        player.context=context(9,true,true);
        mouseRelease(seek,seek.width*.75,14);
        compare(received.length,1);
        compare(received[0].trackToken,8);
    }
    function test_disabledSeek() {
        player.context=context(8,false,true);
        mouseClick(findChild(player,"musicSeek"));
        compare(received.length,0);
    }
    function test_layoutAndCapture() {
        const art=findChild(player,"musicArtwork");
        const main=findChild(player,"musicMain");
        const up=findChild(player,"musicUpcoming");
        compare(art.width,art.height);
        verify(art.x+art.width<main.x);
        verify(main.x+main.width<up.x);
        wait(300);
        grabImage(frame).save(OUTPUT+"/implementation.png");
        player.width=380;player.height=272;frame.width=500;frame.height=410;
        wait(100);
        verify(up.y>main.y+main.height);
        verify(up.x+up.width<=player.width);
        grabImage(frame).save(OUTPUT+"/narrow.png");
        player.width=604;player.height=152;frame.width=860;frame.height=300;
    }
    function test_missingAndLightCapture() {
        player.context=context(8,true,false);
        wait(100);
        grabImage(frame).save(OUTPUT+"/unavailable.png");
        Preferences.settings={appearance:{mode:"light"}};
        wait(100);
        grabImage(frame).save(OUTPUT+"/light.png");
    }
    function test_silenceAndReducedMotion() {
        const spectrum=findChild(player,"musicSpectrum");
        spectrum.samples=[];
        wait(220);
        grabImage(frame).save(OUTPUT+"/silence.png");
        Preferences.reducedMotion=true;
        spectrum.samples=[1,1,1,1];
        wait(20);
        compare(spectrum.children[0].children[0].height,3);
    }
}
'''.replace('COVER', json.dumps(cover)).replace('OUTPUT', json.dumps(str(out))))
        if '--native' in sys.argv:
            (base / 'Titonium').symlink_to(base / 'qs/Titonium', target_is_directory=True)
            runtime = base / 'runtime'
            runtime.mkdir(mode=0o700)
            native = base / 'shell.qml'
            native.write_text('''import QtQuick
import Quickshell
import qs.Titonium.Bar.center
import qs.Titonium.Theme
FloatingWindow {
    visible: true
    implicitWidth: 860; implicitHeight: 300
    color: Theme.background
    Rectangle {
        id: frame
        anchors.fill: parent
        color: Theme.background
        Rectangle {
            x:60; y:58; width:604; height:152
            color:Theme.surface; radius:12; border.width:1; border.color:Theme.border
            MusicPlayerContent {
                anchors.fill: parent
                context: ({id:"media:current", source:"media",title:"Slow Motion",subtitle:"Kai Rivers",
                    details:{playing:true,trackArtUrl:COVER,playback:{identity:"preview",trackToken:1,source:{label:"YouTube",icon:"smart_display"},
                        position:102,length:236,canSeek:true,queueStatus:"ready",nextTrack:{
                            title:"Chasing Dreams",artist:"Aria Nova",length:208,artUrl:COVER}}}})
                actions: [{id:"media.previous",contextId:"media:current",enabled:true},
                    {id:"media.toggle",contextId:"media:current",enabled:true},
                    {id:"media.next",contextId:"media:current",enabled:true},
                {id:"media.raise",contextId:"media:current",enabled:true}]
            }
        }
    }
    Timer {
        interval:1500; running:true
        onTriggered: frame.grabToImage(result => {
            console.log("CAPTURE",result.saveToFile(OUTPUT+"/native.png"));
            Qt.quit();
        });
    }
}
'''.replace('COVER',json.dumps(cover)).replace('OUTPUT',json.dumps(str(out))))
            capture = out / 'native.png'
            capture.unlink(missing_ok=True)
            env = dict(os.environ, QT_QPA_PLATFORM='wayland', QSG_RHI_BACKEND='opengl',
                       QT_QUICK_BACKEND='rhi', QML_IMPORT_PATH=str(base),
                       XDG_RUNTIME_DIR=os.environ.get('XDG_RUNTIME_DIR', '/run/user/1000'))
            try:
                result = subprocess.run(['qs','-p',str(native),'--no-color'],env=env,timeout=15)
            except subprocess.TimeoutExpired:
                print('Native capture timed out; the compositor did not deliver a captured frame.', file=sys.stderr)
                return 1
            return result.returncode or (0 if capture.exists() else 1)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
        return subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-input', str(base), '-import', str(base)], env=env).returncode


if __name__ == '__main__':
    raise SystemExit(main())
