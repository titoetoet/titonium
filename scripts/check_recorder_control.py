#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile
from unittest.mock import patch
spec = importlib.util.spec_from_file_location('recorder', Path(__file__).resolve().parents[1] / 'Titonium/Services/Capture/recorder_control.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
with tempfile.TemporaryDirectory() as d:
    root = Path(d)
    proc = root / '42'; proc.mkdir()
    (proc / 'comm').write_text('wf-recorder\n')
    (proc / 'stat').write_text('42 (wf-recorder) ' + ' '.join(['S'] + ['0'] * 18 + ['123']))
    assert m.sessions(root) == [{'pid': 42, 'start': '123'}]
    with patch.object(m.os, 'pidfd_open', return_value=99), patch.object(m.os, 'close'), patch.object(m.signal, 'pidfd_send_signal') as send:
        assert not m.stop([{'pid': 42, 'start': '122'}], root)
        send.assert_not_called()
        assert m.stop([{'pid': 42, 'start': '123'}], root)
        send.assert_called_once_with(99, m.signal.SIGINT)
print('PASS recorder identity validation and graceful stop')
