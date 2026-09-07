#!/usr/bin/env python3
"""Run actual AudioService reactive handlers with isolated QObject PipeWire nodes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    runner = shutil.which('qmltestrunner') or '/usr/lib/qt6/bin/qmltestrunner'
    with tempfile.TemporaryDirectory(prefix='titonium-audio-indicators-') as directory:
        base = Path(directory)

        def module(name, files):
            path = base / name.replace('.', '/')
            path.mkdir(parents=True, exist_ok=True)
            exports = ['module ' + name]
            for key, value in files.items():
                (path / (key + '.qml')).write_text(value)
                exports.append(('singleton ' if value.startswith('pragma Singleton') else '')
                               + key + ' 1.0 ' + key + '.qml')
            (path / 'qmldir').write_text('\n'.join(exports))
            return path

        module('Quickshell.Services.Pipewire', {
            'PwNodePeakMonitor': '''import QtQuick
QtObject { property var node: null; property bool enabled: false; property real peak: 0 }''',
            'PwObjectTracker': '''import QtQuick
QtObject { property var objects: [] }''',
            'FakeNode': '''import QtQuick
QtObject {
 property int nodeId: 0
 readonly property int id: nodeId
 property bool ready: true
 property bool isSink: false
 property bool isStream: false
 property string description: ""
 property string nickname: ""
 property string name: ""
 property var properties: ({})
 property QtObject audio: QtObject {
  property real volume: 0.5
  property bool muted: false
  signal volumesChanged()
  onVolumeChanged: volumesChanged()
 }
}''',
            'Pipewire': '''pragma Singleton
import QtQuick
QtObject {
 property bool ready: false
 property FakeNode output: FakeNode { nodeId: 1; isSink: true; description: "Speakers" }
 property FakeNode input: FakeNode { nodeId: 2; description: "Microphone" }
 property FakeNode otherInput: FakeNode { nodeId: 3; description: "Headset microphone" }
 property FakeNode stream: FakeNode {
  nodeId: 4; isStream: true; description: "Player"; properties: ({"media.class": "Stream/Output/Audio"})
 }
 property var defaultAudioSink: output
 property var defaultAudioSource: input
 property var preferredDefaultAudioSink: null
 property QtObject nodes: QtObject { property var values: [] }
}'''})
        module('qs.Titonium.Core.Runtime', {
            'Preferences': '''pragma Singleton
import QtQuick
QtObject { property bool allowAudioAmplification: false }''',
            'I18n': '''pragma Singleton
import QtQuick
QtObject { function tr(key, values) { return key + (values ? ":" + JSON.stringify(values) : ""); } }''',
            'Logger': '''pragma Singleton
import QtQuick
QtObject { function warn(source, message) {} }'''})
        module('qs.Titonium.Services.Center', {'CenterAttentionService': '''pragma Singleton
import QtQuick
QtObject {
 property var indicators: ({})
 property var events: []
 function setIndicator(id, icon, accessibleName, active) {
  const next = Object.assign({}, indicators);
  next[id] = {icon: icon, accessibleName: accessibleName, active: active};
  indicators = next;
 }
 function publish(event) { events = events.concat([event]); }
}'''})
        service = ROOT / 'Titonium/Services/Audio'
        path = module('qs.Titonium.Services.Audio', {'AudioService': (service / 'AudioService.qml').read_text()})
        shutil.copyfile(service / 'AudioRules.js', path / 'AudioRules.js')
        (base / 'tst_indicators.qml').write_text('''import QtQuick
import QtTest
import Quickshell.Services.Pipewire
import qs.Titonium.Services.Audio
import qs.Titonium.Services.Center

TestCase {
 name: "AudioIndicators"
 SignalSpy { id: outputSpy; target: AudioService; signalName: "outputPresentationChanged" }
 function initTestCase() {
  compare(AudioService.outputAvailable, false);
  compare(CenterAttentionService.events.length, 0, "cold startup stays silent");
  Pipewire.ready = true;
  compare(AudioService.outputAvailable, true);
  compare(AudioService.inputAvailable, true);
  compare(outputSpy.count, 0, "first usable discovery must establish a silent output baseline");
  compare(CenterAttentionService.events.length, 0, "first usable discovery must not announce a device change");
 }
 function test_capture_mute_is_scoped_and_stale_safe() {
  Pipewire.stream.properties = ({"media.class": "Stream/Input/Audio", "object.serial": "40"});
  Pipewire.stream.audio.muted = false;
  Pipewire.nodes.values = [Pipewire.input, Pipewire.stream];
  compare(AudioService.captureStreams.length, 1);
  verify(AudioService.toggleCaptureMute(4, "4:40"));
  compare(Pipewire.stream.audio.muted, true);
  compare(Pipewire.input.audio.muted, false);
  Pipewire.stream.properties = ({"media.class": "Stream/Input/Audio", "object.serial": "41"});
  verify(!AudioService.toggleCaptureMute(4, "4:40"));
  Pipewire.stream.properties = ({"media.class": "Stream/Input/Audio", "stream.monitor": "true"});
  compare(AudioService.captureStreams.length, 0);
 }
 function init() {
  Pipewire.ready = true;
  Pipewire.input.ready = true; Pipewire.input.description = "Microphone"; Pipewire.input.audio.muted = false;
  Pipewire.otherInput.ready = true; Pipewire.otherInput.audio.muted = true;
  Pipewire.output.ready = true; Pipewire.output.description = "Speakers";
  Pipewire.stream.properties = ({"media.class": "Stream/Output/Audio"});
  Pipewire.defaultAudioSource = Pipewire.input;
  Pipewire.defaultAudioSink = Pipewire.output;
  Pipewire.nodes.values = [Pipewire.output, Pipewire.input, Pipewire.otherInput];
  // Establish the existing startup/output-event baseline before each isolated input change.
  AudioService.resetOutputPresentation();
  wait(0);
  CenterAttentionService.events = [];
  outputSpy.clear();
 }
 function cleanup() {
  compare(outputSpy.count, 0, "input/stream changes must not produce an output OSD event");
  compare(CenterAttentionService.events.filter(event => event.kind === "volume_changed").length, 0,
   "input/stream changes must not publish output volume feedback");
 }
 function microphoneActive() { return CenterAttentionService.indicators["audio-microphone"].active; }
 function test_delayedNodeReadiness() {
  Pipewire.nodes.values = [];
  Pipewire.ready = false;
  Pipewire.output.ready = false; Pipewire.input.ready = false;
  AudioService.previousOutputName = ""; AudioService.previousInputName = "";
  CenterAttentionService.events = [];
  Pipewire.ready = true;
  compare(CenterAttentionService.events.length, 0);
  Pipewire.output.ready = true;
  compare(AudioService.previousOutputName, "Speakers", "output-only readiness must observe the baseline immediately");
  compare(CenterAttentionService.events.length, 0, "output-only discovery stays silent without input events");
  Pipewire.input.ready = true;
  compare(AudioService.previousInputName, "Microphone");
  compare(CenterAttentionService.events.length, 0, "delayed native nodes establish their first usable baseline silently");
 }
 function test_realDeviceChangeAfterDiscovery() {
  Pipewire.defaultAudioSink = null;
  CenterAttentionService.events = [];
  Pipewire.output.description = "USB Audio S/PDIF Output";
  Pipewire.defaultAudioSink = Pipewire.output;
  const changes = CenterAttentionService.events.filter(event => event.kind === "output_changed");
  compare(changes.length, 1, "later output replacement must still publish exactly once");
  verify(changes[0].title.indexOf("USB Audio S/PDIF Output") >= 0);
 }
 function test_inputMute() {
  Pipewire.input.audio.muted = true;
  compare(AudioService.inputMuted, true, "normalized input already observes native mute");
  compare(microphoneActive(), true, "mute must reach the Center indicator without output changes");
  compare(CenterAttentionService.indicators["audio-microphone"].icon, "mic_off");
  Pipewire.input.audio.muted = false;
  compare(microphoneActive(), false);
 }
 function test_inputReadiness() {
  Pipewire.input.audio.muted = true; AudioService.resetOutputPresentation();
  Pipewire.input.ready = false;
  compare(AudioService.inputAvailable, false);
  compare(microphoneActive(), false, "unready input must remove the muted-microphone indicator");
  Pipewire.input.ready = true;
  compare(microphoneActive(), true);
 }
 function test_defaultSource() {
  Pipewire.defaultAudioSource = Pipewire.otherInput;
  compare(AudioService.inputName, "Headset microphone");
  compare(microphoneActive(), true, "default source replacement must update the microphone indicator");
  const changes = CenterAttentionService.events.filter(event => event.kind === "input_changed");
  compare(changes.length, 1);
  verify(changes[0].title.indexOf("Headset microphone") >= 0);
  Pipewire.defaultAudioSource = null;
  compare(microphoneActive(), false);
 }
 function test_inputName() {
  Pipewire.input.description = "Renamed microphone";
  compare(AudioService.inputName, "Renamed microphone");
  const changes = CenterAttentionService.events.filter(event => event.kind === "input_changed");
  compare(changes.length, 1, "input-only rename must publish device change");
  verify(changes[0].title.indexOf("Renamed microphone") >= 0);
 }
 function test_streamMembership() {
  Pipewire.nodes.values = [Pipewire.output, Pipewire.input, Pipewire.stream];
  compare(AudioService.playbackStreams.length, 1);
  compare(CenterAttentionService.indicators["audio-streams"].active, true,
   "new playback stream must activate indicator without output changes");
  Pipewire.nodes.values = [Pipewire.output, Pipewire.input];
  compare(AudioService.playbackStreams.length, 0);
  compare(CenterAttentionService.indicators["audio-streams"].active, false);
 }
 function test_streamClassification() {
  Pipewire.stream.properties = ({"media.class": "Stream/Input/Audio"});
  Pipewire.nodes.values = [Pipewire.output, Pipewire.input, Pipewire.stream];
  AudioService.resetOutputPresentation();
  Pipewire.stream.properties = ({"media.class": "Stream/Output/Audio"});
  compare(AudioService.playbackStreams.length, 1);
  compare(CenterAttentionService.indicators["audio-streams"].active, true);
  Pipewire.stream.properties = ({"media.class": "Stream/Input/Audio"});
  compare(CenterAttentionService.indicators["audio-streams"].active, false);
  Pipewire.stream.properties = ({"media.class": "Stream/Output/Audio"});
 }
}''')
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
        return subprocess.run([runner, '-input', str(base), '-import', str(base)], env=env).returncode


if __name__ == '__main__':
    raise SystemExit(main())
