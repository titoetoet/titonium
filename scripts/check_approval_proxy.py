#!/usr/bin/env python3
"""End-to-end proxy concurrency with a fake app-server; no real approvals/tools."""
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='titonium-proxy-test-') as directory:
    base = Path(directory)
    child = base / 'fake-codex'
    child.write_text('''#!''' + sys.executable + '''
import json, sys, os
messages = [
 {"id":1,"method":"item/commandExecution/requestApproval","params":{"command":"fixture"}},
 {"method":"thread/fixture-progress","params":{"value":1}},
 {"id":2,"method":"item/fileChange/requestApproval","params":{}},
 {"id":3,"method":"item/permissions/requestApproval","params":{"permissions":{}}},
 {"id":4,"method":"item/commandExecution/requestApproval","params":{}},
 ["opaque", "line"], None, {"method": [], "id": 5}]
for message in messages:
 print(json.dumps(message), flush=True)
buffer = b""
while chunk := os.read(sys.stdin.fileno(), 65536):
 buffer += chunk
 while b"\\n" in buffer:
  line, _, buffer = buffer.partition(b"\\n")
  print(json.dumps({"echo":json.loads(line)}), flush=True)
 if buffer:
  print(json.dumps({"partial": True}), flush=True)
''')
    child.chmod(0o755)
    wrapper = base / 'proxy.py'
    wrapper.write_text('''import sys,time
from pathlib import Path
sys.path.insert(0, ''' + repr(str(ROOT)) + ''')
import agent_approval_bridge as bridge
bridge.MAX_PENDING_APPROVALS = 2
def exchange(request, timeout=300, stop_event=None):
 release=Path(''' + repr(str(base)) + ''')/str(request["rpcId"])
 deadline=time.monotonic()+10
 while not release.exists():
  if stop_event is not None and stop_event.is_set():
   raise ConnectionError("cancelled fixture")
  if time.monotonic()>deadline:
   raise TimeoutError("fixture timed out")
  time.sleep(.01)
 if request["rpcId"] == 1:
  print('{"approvalReady":1}', flush=True)
 return {"decision":"accept"}
bridge.exchange=exchange
raise SystemExit(bridge.codex_proxy(["app-server"]))
''')
    env = dict(os.environ, TITONIUM_REAL_CODEX=str(child), TITONIUM_AGENT_APPROVAL_ENABLED='1',
               PYTHONDONTWRITEBYTECODE='1')
    process = subprocess.Popen([sys.executable, str(wrapper)], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env,
                               start_new_session=True, bufsize=0)
    pending = bytearray()
    def read_message():
        import time
        deadline = time.monotonic() + 2
        while b'\n' not in pending:
            remaining = deadline - time.monotonic()
            assert remaining > 0, 'approval wait blocked unrelated app-server output'
            ready, _, _ = select.select([process.stdout], [], [], remaining)
            assert ready, 'approval wait blocked unrelated app-server output'
            chunk = os.read(process.stdout.fileno(), 65536)
            assert chunk, 'proxy exited before forwarding output'
            pending.extend(chunk)
        line, _, rest = pending.partition(b'\n')
        pending[:] = rest
        return json.loads(line)
    try:
        assert read_message()['method'] == 'thread/fixture-progress'
        assert read_message()['id'] == 3, 'permission grants must retain native method-specific review'
        assert read_message()['id'] == 4, 'capacity overflow must delegate to native review'
        assert read_message() == ['opaque', 'line']
        assert read_message() is None
        assert read_message() == {"method": [], "id": 5}
        (base / '2').touch()
        assert read_message() == {'echo': {'id': 2, 'result': {'decision': 'accept'}}}
        process.stdin.write(b'{"id":77,')
        assert read_message() == {'partial': True}, 'fixture must consume the incomplete client frame'
        (base / '1').touch()
        assert read_message() == {'approvalReady': 1}
        ready, _, _ = select.select([process.stdout], [], [], 0.1)
        assert not ready, 'approval reply spliced into the incomplete client frame'
        process.stdin.write(b'"method":"client-fixture"}\n')
        replies = [read_message(), read_message()]
        assert {'echo': {'id': 77, 'method': 'client-fixture'}} in replies, 'client frame was corrupted'
        assert {'echo': {'id': 1, 'result': {'decision': 'accept'}}} in replies, 'approval frame was corrupted'
        process.stdin.close()
        assert process.wait(timeout=2) == 0
        print('PASS pending approvals preserve output, concurrent decisions, native delegation and complete input frames')
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=2)

    # Closing the app while an approval is still pending must not wait 300 seconds.
    (base / '1').unlink()
    (base / '2').unlink()
    process = subprocess.Popen([sys.executable, str(wrapper)], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env,
                               start_new_session=True, bufsize=0)
    pending.clear()
    try:
        assert read_message()['method'] == 'thread/fixture-progress'
        process.stdin.close()
        assert process.wait(timeout=2) == 0
        print('PASS app-server shutdown does not wait for unresolved approval workers')
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=2)
