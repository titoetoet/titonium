#!/usr/bin/env python3
import importlib.util
import inspect
import json
import os
import select
import socket
import tempfile
import threading
from pathlib import Path

path = Path(__file__).with_name("agent_approval_bridge.py")
spec = importlib.util.spec_from_file_location("agent_approval_bridge", path)
bridge = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(bridge)

with tempfile.TemporaryDirectory() as directory:
    sock_path = str(Path(directory) / "approval.sock")
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        server.bind(sock_path)
    except PermissionError:
        server.close()
        server = None
    if server is not None:
        server.listen(1)
        os.environ["TITONIUM_AGENT_APPROVAL_SOCKET"] = sock_path

    if server is not None:
        def respond():
            client, _ = server.accept()
            data = client.recv(65536)
            request = json.loads(data)
            assert request["source"] == "chatgpt"
            client.sendall(b'{"decision":"accept"}\n')
            client.close()

        thread = threading.Thread(target=respond)
        thread.start()
        result = bridge.exchange({"source": "chatgpt", "requestId": "fixture"}, 2)
        thread.join()
        assert result == {"decision": "accept"}

        server.listen(1)
        def respond_agy():
            client, _ = server.accept()
            data = client.recv(65536)
            request = json.loads(data)
            assert request["source"] == "antigravity"
            client.sendall(b'{"decision":"ask","reason":"review in ide"}\n')
            client.close()

        thread = threading.Thread(target=respond_agy)
        thread.start()
        result = bridge.exchange({"source": "antigravity", "requestId": "fixture2"}, 2)
        thread.join()
        server.close()
        assert result == {"decision": "ask", "reason": "review in ide"}

assert "item/commandExecution/requestApproval" in bridge.APPROVAL_METHODS
assert "HOOK AUTO-APPROVE" not in inspect.getsource(bridge.antigravity_hook)
assert '"decision": "force_ask"' in inspect.getsource(bridge.antigravity_hook)
bridge_source = path.read_text(encoding="utf-8")
old_flag = os.environ.pop("TITONIUM_AGENT_APPROVAL_ENABLED", None)
try:
    assert bridge.approval_enabled() is False
    os.environ["TITONIUM_AGENT_APPROVAL_ENABLED"] = "1"
    assert bridge.approval_enabled() is True
    os.environ["TITONIUM_AGENT_APPROVAL_ENABLED"] = "true"
    assert bridge.approval_enabled() is False
finally:
    if old_flag is None:
        os.environ.pop("TITONIUM_AGENT_APPROVAL_ENABLED", None)
    else:
        os.environ["TITONIUM_AGENT_APPROVAL_ENABLED"] = old_flag
assert bridge.project_path() == str(path.resolve().parent.parent)
assert "/home/cole/Projects/titonium" not in bridge_source
codex_source = bridge_source.split("def codex_proxy", 1)[1].split("def main", 1)[0]
assert "CODEX AUTO-APPROVE" not in codex_source
assert "requires_sudo" not in codex_source
assert 'decision == "delegate"' in codex_source
# Byte-for-byte forwarding and non-blocking output are exercised by
# check_approval_proxy.py with a real subprocess and isolated app-server fixture.
for method in bridge.APPROVAL_METHODS:
    assert method in bridge.APPROVAL_METHODS

# A live Desktop keeps stdin open. The first JSON-RPC bytes must still be
# forwarded immediately instead of waiting for a 64 KiB buffer or EOF.
source_read_fd, source_write_fd = os.pipe()
destination_read_fd, destination_write_fd = os.pipe()
source = os.fdopen(source_read_fd, "rb", buffering=0)
destination = os.fdopen(destination_write_fd, "wb", buffering=0)
forwarder = threading.Thread(target=bridge.forward_stream, args=(source, destination))
forwarder.start()
os.write(source_write_fd, b'{"id":1}\n')
ready, _, _ = select.select([destination_read_fd], [], [], 1.0)
assert ready, "live stdin bytes were buffered instead of forwarded"
assert os.read(destination_read_fd, 1024) == b'{"id":1}\n'
os.close(source_write_fd)
forwarder.join(timeout=1.0)
assert not forwarder.is_alive()
os.close(destination_read_fd)

print("agent approval bridge: ok")

# Check transport cleanup/cancellation without depending on a native socket server.
from types import SimpleNamespace
from unittest.mock import patch
import contextlib
import io
import time

class FixtureSocket:
    def __init__(self, refused=False, cancel=None):
        self.closed = False
        self.refused = refused
        self.cancel = cancel
    def settimeout(self, timeout):
        pass
    def connect(self, address):
        if self.refused:
            raise ConnectionRefusedError('fixture')
    def close(self):
        self.closed = True
    def __enter__(self):
        return self
    def __exit__(self, *args):
        self.close()
    def sendall(self, data):
        pass
    def recv(self, count):
        if self.cancel is not None:
            self.cancel.set()
        time.sleep(.01)
        return b' '  # A trickling peer must not extend the absolute timeout.

for mode in ('refused', 'cancel', 'deadline'):
    cancel = threading.Event() if mode == 'cancel' else None
    candidate = FixtureSocket(refused=mode == 'refused', cancel=cancel)
    with patch.object(bridge.os, 'stat', return_value=SimpleNamespace(st_uid=os.getuid())), \
         patch.object(bridge.socket, 'socket', return_value=candidate), \
         patch.object(bridge, 'is_quickshell_running', return_value=False):
        try:
            bridge.exchange({'source': 'fixture'}, timeout=0 if mode == 'refused' else .05,
                            stop_event=cancel)
        except (ConnectionError, TimeoutError):
            pass
        else:
            raise AssertionError('expected transport failure: ' + mode)
        assert candidate.closed, 'transport failure leaked socket: ' + mode
print('PASS approval transport closes failed sockets and honors cancellation/absolute deadlines')

secret = 'PRIVATE_FIXTURE_ARGUMENT_NEVER_LOG'
payload = {'toolCall': {'name': 'fixture', 'args': {'command': secret}}}
for failure in (False, True):
    stderr, stdout = io.StringIO(), io.StringIO()
    fixture_input = SimpleNamespace(buffer=io.BytesIO(json.dumps(payload).encode()))
    result = {'decision': 'allow', 'reason': secret}
    with patch.dict(os.environ, {'TITONIUM_AGENT_APPROVAL_ENABLED': '1'}), \
         patch.object(bridge.sys, 'stdin', fixture_input), \
         patch.object(bridge, 'exchange', side_effect=ValueError(secret) if failure else None,
                      return_value=result), \
         contextlib.redirect_stderr(stderr), contextlib.redirect_stdout(stdout):
        assert bridge.antigravity_hook() == 0
    assert secret not in stderr.getvalue(), 'hook leaked payload/result/exception into diagnostics'
    assert json.loads(stdout.getvalue())['decision'] == ('force_ask' if failure else 'allow')
print('PASS hook integration preserves protocol results without logging payloads or exception text')
