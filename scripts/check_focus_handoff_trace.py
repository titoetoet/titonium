#!/usr/bin/env python3

"""Validate one cursor-bounded canonical Titonium focus-log transition."""

import re
import sys
from dataclasses import dataclass
from pathlib import Path


CANONICAL_EVENT = re.compile(
    r"^\s*INFO qml: \[titonium\]\[focus\] (acquired|released) (\S+)(?:\s+.*)?$")


@dataclass(frozen=True)
class FocusEvent:
    line: int
    action: str
    owner: str


def fail(message: str) -> int:
    print(f"FAIL focus handoff trace: {message}", file=sys.stderr)
    return 1


def pending(message: str) -> int:
    print(f"PENDING focus handoff trace: {message}", file=sys.stderr)
    return 2


def events_after(log_file: Path, cursor: int) -> list[FocusEvent]:
    lines = log_file.read_text(encoding="utf-8").splitlines()
    if cursor < 0 or cursor > len(lines):
        raise ValueError(f"cursor {cursor} is outside 0..{len(lines)}")
    events: list[FocusEvent] = []
    for line_number, line in enumerate(lines[cursor:], start=cursor + 1):
        match = CANONICAL_EVENT.fullmatch(line)
        if match:
            events.append(FocusEvent(line_number, match.group(1), match.group(2)))
    return events


def require_event(events: list[FocusEvent], action: str, owner: str) -> int:
    if any(event.action == action and event.owner == owner for event in events):
        return 0
    return pending(f"waiting for exact {action} {owner}")


def require_handoff(events: list[FocusEvent], old_owner: str, new_owner: str) -> int:
    releases = [event for event in events
                if event.action == "released" and event.owner == old_owner]
    acquisitions = [event for event in events
                    if event.action == "acquired" and event.owner == new_owner]

    if not acquisitions:
        if releases:
            return pending(f"waiting for exact acquired {new_owner} after line {releases[0].line}")
        return pending(f"waiting for exact released {old_owner}")
    if not releases:
        return fail(f"missing exact release {old_owner} before acquired {new_owner}")

    first_release = releases[0]
    first_acquisition = acquisitions[0]
    if first_acquisition.line <= first_release.line:
        return fail(f"acquired {new_owner} on line {first_acquisition.line} before exact release "
                    f"{old_owner} on line {first_release.line}")
    if len(acquisitions) > 1:
        return fail(f"duplicate acquired {new_owner} after cursor at lines "
                    + ", ".join(str(event.line) for event in acquisitions))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 5:
        print("usage: check_focus_handoff_trace.py EVENT|handoff LOG CURSOR ACTION OWNER "
              "| handoff LOG CURSOR OLD_OWNER NEW_OWNER", file=sys.stderr)
        return 64
    command, raw_log_file, raw_cursor = argv[:3]
    log_file = Path(raw_log_file)
    try:
        cursor = int(raw_cursor)
        events = events_after(log_file, cursor)
    except (OSError, ValueError) as error:
        return fail(str(error))

    if command == "event" and len(argv) == 5:
        return require_event(events, argv[3], argv[4])
    if command == "handoff" and len(argv) == 5:
        return require_handoff(events, argv[3], argv[4])
    print("invalid focus handoff trace arguments", file=sys.stderr)
    return 64


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
