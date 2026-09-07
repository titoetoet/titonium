#!/usr/bin/env python3
"""Bounded wl-paste callbacks and cache operations owned by ClipboardService."""
import hashlib
import json
import os
import re
import stat
import struct
import subprocess
import sys
import uuid

MAX_TEXT_BYTES = 64 * 1024
MAX_IMAGE_BYTES = 16 * 1024 * 1024
CACHE_NAME = re.compile(r'[a-f0-9]{32}(?:-[a-f0-9]{32})?\.png\Z')


def read_text(stream):
    data = stream.read(MAX_TEXT_BYTES + 1)
    if len(data) > MAX_TEXT_BYTES:
        return None
    return data.decode('utf-8', errors='replace')


def capture(stream, cache):
    data = stream.read(MAX_IMAGE_BYTES + 1)
    if (len(data) < 33 or len(data) > MAX_IMAGE_BYTES
            or data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR'):
        return None
    width, height = struct.unpack('>II', data[16:24])
    if not width or not height:
        return None
    os.makedirs(cache, mode=0o700, exist_ok=True)
    directory = os.open(cache, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        digest = hashlib.md5(data).hexdigest()
        # A capture gets its own path so an older cleanup can never unlink a new capture.
        name = digest + '-' + uuid.uuid4().hex + '.png'
        fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                     0o600, dir_fd=directory)
        try:
            with os.fdopen(fd, 'wb') as output:
                output.write(data)
        except OSError:
            os.unlink(name, dir_fd=directory)
            raise
    finally:
        os.close(directory)
    return dict(path=os.path.join(cache, name), width=width, height=height,
                bytes=len(data), md5=digest)


def cleanup(cache, paths):
    try:
        directory = os.open(cache, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except FileNotFoundError:
        return
    try:
        for path in paths:
            if not isinstance(path, str) or os.path.dirname(path) != cache:
                continue
            name = os.path.basename(path)
            if not CACHE_NAME.fullmatch(name):
                continue
            try:
                info = os.stat(name, dir_fd=directory, follow_symlinks=False)
                if stat.S_ISREG(info.st_mode):
                    os.unlink(name, dir_fd=directory)
            except FileNotFoundError:
                pass
    finally:
        os.close(directory)


def copy_image(path):
    try:
        with open(path, 'rb') as image:
            return subprocess.run(['wl-copy', '-t', 'image/png'], stdin=image,
                                  timeout=10, check=False).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def main():
    action = sys.argv[1]
    if action == 'text':
        value = read_text(sys.stdin.buffer)
        if value is not None:
            print(json.dumps(value, ensure_ascii=False))
    elif action == 'capture':
        value = capture(sys.stdin.buffer, sys.argv[2])
        if value is not None:
            print(json.dumps(value))
    elif action == 'cleanup':
        cleanup(sys.argv[2], json.loads(sys.argv[3]))
    elif action == 'copy':
        return 0 if copy_image(sys.argv[2]) else 1
    else:
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
