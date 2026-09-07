#!/usr/bin/env python3
"""Bridge Antigravity hooks and ChatGPT's Codex app-server to Titonium."""

from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import time
import threading
import uuid
from pathlib import Path
from typing import Any

from approval_bridge_logging import log_bridge

MAX_MESSAGE = 1024 * 1024
MAX_PENDING_APPROVALS = 8
APPROVAL_METHODS = {
    "item/commandExecution/requestApproval",
    "item/fileChange/requestApproval",
    "item/permissions/requestApproval",
}


def approval_enabled() -> bool:
    """Titonium approval interception is an explicit temporary opt-in."""
    return os.environ.get("TITONIUM_AGENT_APPROVAL_ENABLED") == "1"


def socket_path() -> str:
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    return os.environ.get(
        "TITONIUM_AGENT_APPROVAL_SOCKET",
        str(Path(runtime) / "titonium-agent-approval.sock"),
    )


def project_path() -> str:
    """Return the Titonium project containing this bridge."""
    return str(Path(__file__).resolve().parent.parent)


def is_quickshell_running() -> bool:
    try:
        out = subprocess.check_output(
            ["pgrep", "-u", str(os.getuid()), "-x", "qs"],
            stderr=subprocess.DEVNULL,
        )
        if out.strip():
            return True
    except Exception:
        pass
    try:
        out = subprocess.check_output(
            ["pgrep", "-u", str(os.getuid()), "-x", "quickshell"],
            stderr=subprocess.DEVNULL,
        )
        if out.strip():
            return True
    except Exception:
        pass
    return False


def exchange(payload: dict[str, Any], timeout: float = 300.0,
             stop_event: threading.Event | None = None) -> dict[str, Any]:
    path = socket_path()
    encoded = (json.dumps(payload, separators=(",", ":")) + "\n").encode()
    if len(encoded) > MAX_MESSAGE:
        raise ValueError("approval request is too large")

    stop_event = stop_event or threading.Event()
    overall_deadline = time.monotonic() + timeout
    client: socket.socket | None = None
    retry_window = min(timeout, 15.0)
    start_time = time.monotonic()
    deadline = start_time + retry_window
    grace_window = min(2.5, retry_window)
    last_error: Exception | None = None

    while True:
        if stop_event.is_set():
            raise ConnectionError("approval cancelled")
        candidate = None
        try:
            stat = os.stat(path)
            if stat.st_uid != os.getuid():
                raise PermissionError("approval socket is not owned by the current user")
            candidate = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            candidate.settimeout(max(0.001, min(0.25, overall_deadline - time.monotonic())))
            candidate.connect(path)
            client = candidate
            break
        except (FileNotFoundError, ConnectionRefusedError) as error:
            last_error = error
            # If Quickshell is running, the socket file may have been unlinked by a QML reload.
            # Ask Quickshell to reactivate the socket server via IPC.
            if is_quickshell_running():
                try:
                    subprocess.run(
                        ["qs", "-p", project_path(), "ipc", "call", "agentApproval", "activate"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        timeout=1.0,
                    )
                except Exception:
                    pass
            elif (time.monotonic() - start_time) >= grace_window:
                break
            if time.monotonic() >= deadline:
                break
            stop_event.wait(0.2)
        finally:
            if candidate is not None and candidate is not client:
                candidate.close()

    if client is None:
        if last_error is not None:
            raise last_error
        raise ConnectionError("failed to connect to approval socket")

    with client:
        client.settimeout(max(0.001, overall_deadline - time.monotonic()))
        client.sendall(encoded)
        response = bytearray()
        while b"\n" not in response:
            if stop_event.is_set():
                raise ConnectionError("approval cancelled")
            remaining = overall_deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("approval decision timed out")
            client.settimeout(min(0.25, remaining))
            try:
                chunk = client.recv(4096)
            except socket.timeout:
                continue
            if not chunk:
                raise ConnectionError("approval socket closed without a decision")
            response.extend(chunk)
            if len(response) > MAX_MESSAGE:
                raise ValueError("approval response is too large")
    result = json.loads(response.split(b"\n", 1)[0])
    if not isinstance(result, dict):
        raise ValueError("approval response must be an object")
    return result


def antigravity_hook() -> int:
    if not approval_enabled():
        print(json.dumps({
            "decision": "ask",
            "reason": "Titonium approval integration is disabled; review natively",
        }))
        return 0
    try:
        raw = sys.stdin.buffer.read(MAX_MESSAGE + 1)
        if len(raw) > MAX_MESSAGE:
            raise ValueError("approval payload is too large")
        payload = json.loads(raw)
        if not isinstance(payload, dict):
            raise ValueError("approval payload must be an object")
        log_bridge("hook_request", "received")

        payload.update({
            "source": "antigravity",
            "requestId": str(uuid.uuid4()),
        })
        result = exchange(payload, timeout=120)

        decision = result.get("decision")
        if decision not in {"allow", "deny", "ask", "force_ask"}:
            raise ValueError(f"invalid Antigravity decision: {decision}")
        response = {"decision": decision}
        if "reason" in result:
            response["reason"] = result["reason"]
        if "permissionOverrides" in result:
            response["permissionOverrides"] = result["permissionOverrides"]
        out_str = json.dumps(response)
        log_bridge("hook_result", decision)
        print(out_str)
    except Exception:  # Native Antigravity review remains the fallback.
        log_bridge("hook_error", "unavailable")
        print(json.dumps({
            "decision": "force_ask",
            "reason": "Titonium unavailable; review in Antigravity",
        }))
    return 0


def real_codex_path() -> str:
    return os.environ.get("TITONIUM_REAL_CODEX", "/usr/lib/chatgpt/resources/codex")


def write_bytes(destination: Any, data: bytes) -> None:
    """Unbuffered pipes may accept fewer bytes than requested."""
    remaining = memoryview(data)
    while remaining:
        written = destination.write(remaining)
        if not written:
            raise BrokenPipeError("stream closed")
        remaining = remaining[written:]
    destination.flush()


def forward_stream(source: Any, destination: Any, lock: Any = None) -> None:
    # Hold the shared writer lock through a complete client JSON-RPC frame,
    # including fragments, so an approval reply cannot splice into that frame.
    held = False
    try:
        while chunk := os.read(source.fileno(), 65536):
            if lock is None:
                write_bytes(destination, chunk)
                continue
            for part in chunk.splitlines(keepends=True):
                if not held:
                    lock.acquire()
                    held = True
                write_bytes(destination, part)
                if part.endswith(b"\n"):
                    lock.release()
                    held = False
    except (BrokenPipeError, OSError, ValueError):
        pass
    finally:
        if held:
            lock.release()
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
    input_lock = threading.Lock()
    output_lock = threading.Lock()
    stopping = threading.Event()
    slots = threading.BoundedSemaphore(MAX_PENDING_APPROVALS)

    def forward_output(raw_line: bytes) -> None:
        with output_lock:
            if not stopping.is_set():
                write_bytes(sys.stdout.buffer, raw_line)

    def resolve_approval(message: dict[str, Any], raw_line: bytes) -> None:
        try:
            request = {
                "source": "chatgpt", "requestId": str(uuid.uuid4()),
                "rpcId": message["id"], "method": message["method"],
                "params": message.get("params", {}),
            }
            try:
                result = exchange(request, stop_event=stopping)
                decision = result.get("decision")
                if decision == "delegate":
                    forward_output(raw_line)
                    return
                if decision not in {"accept", "acceptForSession", "decline"}:
                    decision = "decline"
            except Exception:
                log_bridge("proxy_error", "unavailable")
                decision = "decline"
            response = {"id": message["id"], "result": {"decision": decision}}
            with input_lock:
                if not stopping.is_set():
                    write_bytes(child.stdin,
                        (json.dumps(response, separators=(",", ":")) + "\n").encode())
            log_bridge("proxy_result", decision)
        except (BrokenPipeError, OSError, ValueError):
            log_bridge("proxy_error", "cancel")
        finally:
            slots.release()

    input_thread = threading.Thread(
        target=forward_stream, args=(sys.stdin.buffer, child.stdin, input_lock), daemon=True
    )
    input_thread.start()
    try:
        for raw_line in iter(child.stdout.readline, b""):
            try:
                message = json.loads(raw_line)
            except (json.JSONDecodeError, UnicodeDecodeError):
                forward_output(raw_line)
                continue
            # Permission requests have a different response contract. Keep their
            # complete native review path instead of fabricating a generic decision.
            if (not approval_enabled() or not isinstance(message, dict)
                    or not isinstance(message.get("method"), str)
                    or message.get("method") not in APPROVAL_METHODS
                    or message.get("method") == "item/permissions/requestApproval"
                    or "id" not in message):
                forward_output(raw_line)
                continue
            if not slots.acquire(blocking=False):
                forward_output(raw_line)
                log_bridge("proxy_result", "delegate")
                continue
            log_bridge("proxy_request", "received")
            worker = threading.Thread(target=resolve_approval,
                args=(message, raw_line), daemon=True)
            try:
                worker.start()
            except RuntimeError:
                slots.release()
                forward_output(raw_line)
        return child.wait()
    finally:
        stopping.set()
        if child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        child.stdout.close()
        child.stdin.close()
        log_bridge("proxy_exit", "completed")


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
