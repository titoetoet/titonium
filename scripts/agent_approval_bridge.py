#!/usr/bin/env python3
"""Bridge Antigravity hooks and ChatGPT's Codex app-server to Titonium."""

from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any

MAX_MESSAGE = 1024 * 1024
APPROVAL_METHODS = {
    "item/commandExecution/requestApproval",
    "item/fileChange/requestApproval",
    "item/permissions/requestApproval",
}


def socket_path() -> str:
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    return os.environ.get(
        "TITONIUM_AGENT_APPROVAL_SOCKET",
        str(Path(runtime) / "titonium-agent-approval.sock"),
    )


def exchange(payload: dict[str, Any], timeout: float = 300.0) -> dict[str, Any]:
    path = socket_path()
    encoded = (json.dumps(payload, separators=(",", ":")) + "\n").encode()
    if len(encoded) > MAX_MESSAGE:
        raise ValueError("approval request is too large")

    client: socket.socket | None = None
    deadline = time.monotonic() + 3.0
    last_error: Exception | None = None

    while True:
        try:
            stat = os.stat(path)
            if stat.st_uid != os.getuid():
                raise PermissionError("approval socket is not owned by the current user")
            candidate = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            candidate.settimeout(timeout)
            candidate.connect(path)
            client = candidate
            break
        except (FileNotFoundError, ConnectionRefusedError) as error:
            last_error = error
            if time.monotonic() >= deadline:
                break
            time.sleep(0.25)

    if client is None:
        if last_error is not None:
            raise last_error
        raise ConnectionError("failed to connect to approval socket")

    with client:
        client.sendall(encoded)
        response = bytearray()
        while b"\n" not in response:
            chunk = client.recv(4096)
            if not chunk:
                raise ConnectionError("approval socket closed without a decision")
            response.extend(chunk)
            if len(response) > MAX_MESSAGE:
                raise ValueError("approval response is too large")
    result = json.loads(response.split(b"\n", 1)[0])
    if not isinstance(result, dict):
        raise ValueError("approval response must be an object")
    return result


def log_bridge(msg: str) -> None:
    try:
        import time
        with open("/tmp/titonium-approval-bridge.log", "a", encoding="utf-8") as f:
            f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n")
    except Exception:
        pass


def antigravity_hook() -> int:
    try:
        raw = sys.stdin.buffer.read(MAX_MESSAGE + 1)
        if len(raw) > MAX_MESSAGE:
            raise ValueError("approval payload is too large")
        payload = json.loads(raw)
        if not isinstance(payload, dict):
            raise ValueError("approval payload must be an object")
        tool_call = payload.get("toolCall", {})
        tool_name = tool_call.get("name", "")
        tool_args = tool_call.get("args", {})
        log_bridge(f"HOOK START: tool={tool_name} args={tool_args}")

        payload.update({
            "source": "antigravity",
            "requestId": str(uuid.uuid4()),
        })
        result = exchange(payload, timeout=120)
        log_bridge(f"HOOK RESULT: {result}")
        decision = result.get("decision")
        if decision not in {"allow", "deny", "ask", "force_ask"}:
            raise ValueError(f"invalid Antigravity decision: {decision}")
        response = {"decision": decision}
        if "reason" in result:
            response["reason"] = result["reason"]
        if "permissionOverrides" in result:
            response["permissionOverrides"] = result["permissionOverrides"]
        out_str = json.dumps(response)
        log_bridge(f"HOOK STDOUT: {out_str}")
        print(out_str)
    except Exception as error:  # Native Antigravity review remains the fallback.
        log_bridge(f"HOOK EXCEPTION: {error}")
        print(f"titonium approval bridge: {error}", file=sys.stderr)
        print(json.dumps({
            "decision": "force_ask",
            "reason": "Titonium unavailable; review in Antigravity",
        }))
    return 0


def real_codex_path() -> str:
    return os.environ.get("TITONIUM_REAL_CODEX", "/usr/lib/chatgpt/resources/codex")


def forward_stream(source: Any, destination: Any) -> None:
    try:
        while chunk := os.read(source.fileno(), 65536):
            destination.write(chunk)
            destination.flush()
    finally:
        destination.close()


def codex_proxy(argv: list[str]) -> int:
    real_codex = real_codex_path()
    if "app-server" not in argv:
        os.execv(real_codex, [real_codex, *argv])

    child = subprocess.Popen(
        [real_codex, *argv], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=None, bufsize=0,
    )
    assert child.stdin is not None and child.stdout is not None

    import threading
    input_thread = threading.Thread(
        target=forward_stream, args=(sys.stdin.buffer, child.stdin), daemon=True
    )
    input_thread.start()

    for raw_line in iter(child.stdout.readline, b""):
        try:
            message = json.loads(raw_line)
        except (json.JSONDecodeError, UnicodeDecodeError):
            sys.stdout.buffer.write(raw_line)
            sys.stdout.buffer.flush()
            continue

        if message.get("method") not in APPROVAL_METHODS or "id" not in message:
            sys.stdout.buffer.write(raw_line)
            sys.stdout.buffer.flush()
            continue

        params = message.get("params", {})
        method = message.get("method")

        request = {
            "source": "chatgpt",
            "requestId": str(uuid.uuid4()),
            "rpcId": message["id"],
            "method": method,
            "params": params,
        }
        try:
            result = exchange(request)
            decision = result.get("decision")
            if decision == "delegate":
                sys.stdout.buffer.write(raw_line)
                sys.stdout.buffer.flush()
                continue
            if decision not in {"accept", "acceptForSession", "decline"}:
                decision = "decline"
        except Exception as error:
            print(f"titonium approval bridge: {error}", file=sys.stderr)
            decision = "decline"
        response = {"id": message["id"], "result": {"decision": decision}}
        child.stdin.write((json.dumps(response, separators=(",", ":")) + "\n").encode())
        child.stdin.flush()

    return child.wait()


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "antigravity-hook":
        return antigravity_hook()
    if mode == "codex-proxy":
        return codex_proxy(sys.argv[2:])
    print("usage: agent_approval_bridge.py antigravity-hook|codex-proxy [...]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
