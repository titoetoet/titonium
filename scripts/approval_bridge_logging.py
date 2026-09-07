"""Bounded approval diagnostics: fixed metadata only, stderr, no owned log files.

Never pass tool arguments, reasons, RPC payloads, paths or exception messages.
Unknown values are discarded without converting them to strings.
"""
from __future__ import annotations

import sys
import threading

_EVENTS = frozenset({
    "hook_request", "hook_result", "hook_error",
    "proxy_request", "proxy_result", "proxy_error", "proxy_exit",
})
_OUTCOMES = frozenset({
    "received", "completed", "error", "timeout", "unavailable", "invalid",
    "delegate", "allow", "deny", "ask", "force_ask",
    "accept", "acceptForSession", "decline", "cancel",
})
_remaining_records = 32
_lock = threading.Lock()


def log_bridge(event: str, outcome: str) -> None:
    """Emit an allowlisted metadata record; logging failure never affects review."""
    global _remaining_records
    if type(event) is not str or type(outcome) is not str:
        return
    if event not in _EVENTS or outcome not in _OUTCOMES:
        return
    with _lock:
        if _remaining_records == 0:
            return
        _remaining_records -= 1
        try:
            sys.stderr.write(f"[titonium-approval-bridge] event={event} outcome={outcome}\n")
            sys.stderr.flush()
        except Exception:
            # Do not stringify sink errors; they can include sensitive data too.
            pass
