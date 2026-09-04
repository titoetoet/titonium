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


def events_between(log_file: Path, start_cursor: int, end_cursor: int) -> list[FocusEvent]:
    lines = log_file.read_text(encoding="utf-8").splitlines()
    if start_cursor < 0 or end_cursor < start_cursor or end_cursor > len(lines):
        raise ValueError(f"cursor range {start_cursor}..{end_cursor} is outside 0..{len(lines)}")
    events: list[FocusEvent] = []
    for line_number, line in enumerate(lines[start_cursor:end_cursor], start=start_cursor + 1):
        match = CANONICAL_EVENT.fullmatch(line)
        if match:
            events.append(FocusEvent(line_number, match.group(1), match.group(2)))
    return events


def events_after(log_file: Path, cursor: int) -> list[FocusEvent]:
    return events_between(log_file, cursor, len(log_file.read_text(encoding="utf-8").splitlines()))


def require_sequence(events: list[FocusEvent], expected: list[tuple[str, str]]) -> int:
    for index, event in enumerate(events):
        if index >= len(expected):
            return fail(f"duplicate expected transition event {event.action} {event.owner} "
                        f"on line {event.line}")
        expected_action, expected_owner = expected[index]
        if (event.action, event.owner) != (expected_action, expected_owner):
            if (event.action, event.owner) in expected[:index]:
                return fail(f"duplicate expected transition event {event.action} {event.owner} "
                            f"on line {event.line}")
            return fail(f"unexpected canonical event {event.action} {event.owner} on line "
                        f"{event.line}; expected {expected_action} {expected_owner}")
    if len(events) < len(expected):
        action, owner = expected[len(events)]
        return pending(f"waiting for exact {action} {owner}")
    return 0


def require_event(events: list[FocusEvent], action: str, owner: str) -> int:
    return require_sequence(events, [(action, owner)])


def require_handoff(events: list[FocusEvent], old_owner: str, new_owner: str) -> int:
    return require_sequence(events, [("released", old_owner), ("acquired", new_owner)])


def main(argv: list[str]) -> int:
    if len(argv) != 6:
        print("usage: check_focus_handoff_trace.py EVENT|handoff LOG START_CURSOR END_CURSOR "
              "ACTION OWNER", file=sys.stderr)
        return 64
    command, raw_log_file, raw_start_cursor, raw_end_cursor, first_owner, second_owner = argv
    log_file = Path(raw_log_file)
    try:
        start_cursor = int(raw_start_cursor)
        end_cursor = int(raw_end_cursor)
        events = events_between(log_file, start_cursor, end_cursor)
    except (OSError, ValueError) as error:
        return fail(str(error))

    if command == "event":
        return require_event(events, first_owner, second_owner)
    if command == "handoff":
        return require_handoff(events, first_owner, second_owner)
    print("invalid focus handoff trace arguments", file=sys.stderr)
    return 64


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
