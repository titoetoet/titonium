#!/usr/bin/env python3
"""Live isolated approval fixtures; never execute or approve a real tool."""
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
CONFIGS = [Path('/home/cole/.config/hypr/hyprland.lua'),
           ROOT.parent / 'titonium-hyprland/config/hypr/hyprland.lua',
           Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / 'titonium-agent-approval-grants.json']

def hashes():
    return [hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None for p in CONFIGS]

before = hashes()
git_before = subprocess.check_output(['git', 'status', '--porcelain=v1'], cwd=ROOT)
with tempfile.TemporaryDirectory(prefix='titonium-approval-acceptance-') as directory:
    base = Path(directory)
    socket_path = str(base / 'approval.sock')
    env = dict(os.environ, XDG_DATA_HOME=str(base / 'data'), XDG_STATE_HOME=str(base / 'state'),
               XDG_CACHE_HOME=str(base / 'cache'), TITONIUM_AGENT_APPROVAL_ENABLED='1',
               TITONIUM_AGENT_APPROVAL_SOCKET=socket_path)
    clients = []
    with (base / 'shell.log').open('w') as log:
        child = subprocess.Popen(['qs', '-n', '-p', str(ROOT), '--no-color'], env=env,
                                 stdout=log, stderr=subprocess.STDOUT)
    def ipc(*args):
        return subprocess.check_output(['qs', '-p', str(ROOT), 'ipc', '--pid', str(child.pid),
                                        'call', *args], env=env, stderr=subprocess.DEVNULL,
                                       timeout=2, text=True).strip()
    def wait_for(predicate, description):
        for _ in range(60):
            try:
                if predicate():
                    return
            except (OSError, subprocess.SubprocessError):
                pass
            time.sleep(.05)
        raise AssertionError(description)
    def pending_ids():
        return [item['requestId'] for item in json.loads(ipc('agentApproval', 'state'))['pending']]
    def send(client, request_id):
        client.sendall((json.dumps({'source': 'chatgpt', 'requestId': request_id,
            'method': 'item/commandExecution/requestApproval',
            'params': {'threadId': 'acceptance-' + request_id,
                       'command': 'Synthetic review fixture; no executor exists'}}) + '\n').encode())
    def connect():
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        clients.append(client)
        client.settimeout(2)
        client.connect(socket_path)
        return client
    try:
        wait_for(lambda: ipc('app', 'status') == 'ready' and Path(socket_path).exists(),
                 'isolated approval shell did not become ready')
        assert pending_ids() == []
        first, second = 'fixture-' + uuid.uuid4().hex, 'fixture-' + uuid.uuid4().hex
        a, b = connect(), connect()
        send(a, first)
        send(b, second)
        wait_for(lambda: set(pending_ids()) == {first, second}, 'concurrent requests were lost')
        assert ipc('agentApproval', 'decide', first, 'invalid-fixture-decision') == 'false'
        assert set(pending_ids()) == {first, second}, 'invalid decision changed pending requests'
        assert ipc('agentApproval', 'decide', second, 'ask') == 'true'
        assert json.loads(b.makefile('rb').readline()) == {'decision': 'delegate'}
        assert ipc('agentApproval', 'decide', first, 'deny') == 'true'
        assert json.loads(a.makefile('rb').readline()) == {'decision': 'decline'}
        wait_for(lambda: pending_ids() == [], 'decided fixtures remained pending')
        orphan = connect()
        send(orphan, first + '-disconnect')
        send(orphan, second + '-disconnect')
        wait_for(lambda: len(pending_ids()) == 2, 'disconnect fixtures not queued')
        orphan.close()
        wait_for(lambda: pending_ids() == [], 'socket disconnect left orphan requests')
        assert before == hashes(), 'approval fixture changed grants or Hyprland configuration'
        assert git_before == subprocess.check_output(['git', 'status', '--porcelain=v1'], cwd=ROOT)
    finally:
        for client in clients:
            client.close()
        if child.poll() is None:
            child.terminate()
        child.wait(timeout=5)
        text = (base / 'shell.log').read_text()
        if 'Configuration Loaded' not in text or any(error in text for error in
                ('TypeError:', 'ReferenceError:', 'ERROR:')):
            print(text)
            raise AssertionError('approval fixture shell runtime error')
print('PASS live approval concurrency, invalid-decision rejection, deny/delegate, disconnect cleanup and unchanged grants/configuration')
