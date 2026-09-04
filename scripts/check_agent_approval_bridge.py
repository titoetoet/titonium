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
assert bridge.project_path() == str(path.resolve().parent.parent)
assert "/home/cole/Projects/titonium" not in bridge_source
codex_source = bridge_source.split("def codex_proxy", 1)[1].split("def main", 1)[0]
assert "CODEX AUTO-APPROVE" not in codex_source
assert "requires_sudo" not in codex_source
assert 'decision == "delegate"' in codex_source
assert "sys.stdout.buffer.write(raw_line)" in codex_source
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
