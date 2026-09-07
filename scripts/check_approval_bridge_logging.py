#!/usr/bin/env python3
"""Validate metadata-only logging without touching user files or streams."""
import importlib.util
import io
from pathlib import Path
import threading
from unittest import mock

PATH = Path(__file__).with_name('approval_bridge_logging.py')


def fresh_logger():
    spec = importlib.util.spec_from_file_location('approval_bridge_logging_fixture', PATH)
    logger = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(logger)
    return logger


logger = fresh_logger()
output = io.StringIO()
with mock.patch.object(logger.sys, 'stderr', output), mock.patch('builtins.open', side_effect=AssertionError('logging must not open files')):
    logger.log_bridge('hook_request', 'received')
    logger.log_bridge('hook_result', 'allow')
assert output.getvalue().splitlines() == [
    '[titonium-approval-bridge] event=hook_request outcome=received',
    '[titonium-approval-bridge] event=hook_result outcome=allow',
]

class Sensitive:
    def __str__(self):
        raise AssertionError('payload must never be stringified')
    def __hash__(self):
        raise AssertionError('payload must never be hashed')


class SensitiveString(str):
    def __hash__(self):
        raise AssertionError('non-plain strings must never be hashed')


logger = fresh_logger()
output = io.StringIO()
with mock.patch.object(logger.sys, 'stderr', output):
    for value in ('secret-token', 'allow\nsecret-token', {'args': 'secret-token'},
                  ['secret-token'], RuntimeError('secret-token'), Sensitive(),
                  SensitiveString('allow'), None, b'allow'):
        logger.log_bridge(value, 'allow')
        logger.log_bridge('hook_result', value)
assert output.getvalue() == '', 'unknown events/outcomes must never disclose payload contents'

logger = fresh_logger()
output = io.StringIO()
with mock.patch.object(logger.sys, 'stderr', output):
    def flood():
        for _ in range(200):
            logger.log_bridge('proxy_error', 'error')
    threads = [threading.Thread(target=flood) for _ in range(8)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
assert len(output.getvalue().splitlines()) == 32, 'diagnostic output must have a strict per-process budget'
assert len(output.getvalue().encode()) < 4096

logger = fresh_logger()
with mock.patch.object(logger.sys, 'stderr', None):
    logger.log_bridge('hook_error', 'error')
with mock.patch.object(logger.sys, 'stderr') as broken:
    broken.write.side_effect = OSError('secret-token in sink error')
    logger.log_bridge('hook_error', 'error')
    broken.flush.assert_not_called()

print('PASS approval metadata logging redaction, output budget, and sink-failure isolation')
