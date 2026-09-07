"""Detect owned wf-recorder sessions and gracefully stop only matching process identities."""
import json
import os
from pathlib import Path
import signal
import sys


def identity(pid, root=Path('/proc')):
    folder = root / str(pid)
    if folder.stat().st_uid != os.getuid() or folder.joinpath('comm').read_text().strip() != 'wf-recorder':
        return None
    fields = folder.joinpath('stat').read_text().rsplit(')', 1)[1].split()
    return {'pid': int(pid), 'start': fields[19]}


def sessions(root=Path('/proc')):
    result = []
    for folder in root.iterdir():
        if not folder.name.isdigit():
            continue
        try:
            item = identity(int(folder.name), root)
            if item:
                result.append(item)
        except (OSError, ValueError, IndexError):
            continue
    return sorted(result, key=lambda item: item['pid'])


def stop(expected, root=Path('/proc')):
    accepted = False
    for item in expected:
        fd = None
        try:
            pid = item['pid']
            if type(pid) is not int or pid <= 0:
                continue
            fd = os.pidfd_open(pid)
            if identity(pid, root) != item:
                continue
            signal.pidfd_send_signal(fd, signal.SIGINT)
            accepted = True
        except (OSError, ValueError, KeyError, TypeError, IndexError):
            continue
        finally:
            if fd is not None:
                os.close(fd)
    return accepted


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == 'stop':
        sys.exit(0 if stop(json.loads(sys.argv[2])) else 1)
    print(json.dumps(sessions()), flush=True)
