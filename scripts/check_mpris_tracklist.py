#!/usr/bin/env python3
import importlib.util
from pathlib import Path
path = Path(__file__).resolve().parents[1] / 'Titonium/Services/Mpris/track_list.py'
assert path.exists(), 'TrackList must handle unavailable, shuffled and changed tracks'
spec = importlib.util.spec_from_file_location('track_list', path)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
assert m.next_id(['/a', '/b', '/c'], '/a', False, 'None') == '/b'
assert m.next_id(['/a', '/b'], '/b', False, 'None') is None
assert m.next_id(['/a', '/b'], '/b', False, 'Playlist') == '/a'
assert m.next_id(['/a', '/b'], '/a', True, 'None') is None
assert m.next_id(['/a', '/b'], '/missing', False, 'None') is None
assert m.next_id(['/a', '/b'], '/a', False, 'Track') == '/a'
assert m.metadata({'xesam:title':' Song ', 'xesam:artist':['A', 'B'], 'mpris:length':180000000}) == {
    'title':'Song', 'artist':'A, B', 'artUrl':'', 'length':180}
assert m.metadata({}) is None
assert m.metadata({'xesam:title':'x', 'mpris:artUrl':'javascript:bad'})['artUrl'] == ''
print('PASS TrackList ordering, shuffle, loop, missing metadata and safe artwork')

# A queue can change after initial GetAll but before dbus-monitor installs its
# match rules. NameLost is the observed BecomeMonitor-ready signal on this bus.
import contextlib
import io
import json
import sys
from unittest.mock import patch
class Monitor:
    stdout = io.StringIO('signal time=1 sender=org.freedesktop.DBus; member=NameLost\n')
    def terminate(self): pass
    def wait(self, timeout): pass
old = {'identity':'org.mpris.MediaPlayer2.test', 'nextTrack':{'title':'Old'}}
new = {'identity':'org.mpris.MediaPlayer2.test', 'nextTrack':{'title':'New'}}
output = io.StringIO()
with patch.object(sys, 'argv', ['track_list.py', old['identity']]), \
     patch.object(m.subprocess, 'Popen', return_value=Monitor()), \
     patch.object(m, 'snapshot', side_effect=[old, new]), contextlib.redirect_stdout(output):
    m.main()
assert json.loads(output.getvalue().splitlines()[-1])['nextTrack']['title'] == 'New'
print('PASS subscription-ready refresh closes startup queue race')
