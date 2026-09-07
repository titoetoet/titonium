#!/usr/bin/env python3
"""Exercise the acceptance shortcut helper without accessing a compositor."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'scripts/notifications_acceptance.sh').read_text()
helper = re.search(r'^trigger_notification_control\(\) \{\n.*?^\}', source, re.M | re.S).group()

with tempfile.TemporaryDirectory(prefix='titonium-notification-dispatch-') as directory:
    base = Path(directory)
    fake = base / 'hyprctl'
    fake.write_text('''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
with open(os.environ['DISPATCH_LOG'], 'a') as log:
    log.write(json.dumps(args) + '\\n')
if args == ['-j', 'status']:
    print(os.environ['STATUS_REPLY'])
    raise SystemExit(int(os.environ['STATUS_EXIT']))
expected = ['dispatch', 'hl.dsp.global("titonium:notifications")'] if os.environ['PROVIDER'] == 'lua' else ['dispatch', 'global', 'titonium:notifications']
if args != expected:
    print('invalid dispatcher syntax', file=sys.stderr)
    raise SystemExit(7)
if os.environ['DISPATCH_EXIT'] != '0':
    print('shortcut dispatch rejected', file=sys.stderr)
    raise SystemExit(int(os.environ['DISPATCH_EXIT']))
''')
    fake.chmod(0o755)

    def run(provider, reply, status_exit=0, dispatch_exit=0):
        log = base / 'calls.jsonl'
        log.write_text('')
        env = dict(os.environ, PATH=str(base) + os.pathsep + os.environ['PATH'],
                   DISPATCH_LOG=str(log), PROVIDER=provider, STATUS_REPLY=reply,
                   STATUS_EXIT=str(status_exit), DISPATCH_EXIT=str(dispatch_exit))
        result = subprocess.run(['bash', '-euo', 'pipefail', '-c', helper + '\ntrigger_notification_control'],
                                env=env, text=True, capture_output=True)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        return result, calls

    for provider in ('lua', 'hyprlang'):
        result, calls = run(provider, json.dumps({'configProvider': provider, 'backend': 'drm'}))
        assert result.returncode == 0, (provider, result.returncode, result.stderr, calls)
        assert calls[0] == ['-j', 'status'], calls
        assert len(calls) == 2, 'must dispatch the registered shortcut exactly once'
        assert calls[1] == (['dispatch', 'hl.dsp.global("titonium:notifications")'] if provider == 'lua'
                            else ['dispatch', 'global', 'titonium:notifications']), calls

    for status_exit in (0, 1):
        result, calls = run('hyprlang', 'unknown request', status_exit)
        assert result.returncode == 0, result.stderr
        assert calls[-1] == ['dispatch', 'global', 'titonium:notifications']

    for reply, status_exit in (('{bad json', 0), ('{"configProvider":"future"}', 0),
                               ('{}', 0), ('socket unavailable', 1)):
        result, calls = run('lua', reply, status_exit)
        assert result.returncode != 0, reply
        assert calls == [['-j', 'status']], 'an unknown backend must not guess a mutating dispatch'
        assert 'FAIL' in result.stderr, result.stderr

    result, calls = run('lua', '{"configProvider":"lua"}', dispatch_exit=7)
    assert result.returncode != 0
    assert 'shortcut dispatch rejected' in result.stderr, 'dispatch errors must remain visible'
    assert 'FAIL' in result.stderr
    assert len(calls) == 2, 'a rejected dispatch must not retry through another route'

print('PASS notification shortcut Lua/legacy dispatch and failure diagnostics')
