#!/usr/bin/env python3
"""No clipboard access: synthetic PNG bytes and temporary cache; copy uses injected process."""
import importlib.util
import io
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / 'Titonium/Services/Clipboard/clipboard_io.py'

class ClipboardIO(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SOURCE.exists(), 'bounded stdin/cache adapter is missing')
        spec = importlib.util.spec_from_file_location('clipboard_io', SOURCE)
        self.api = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.api)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.cache = Path(self.temp.name) / 'cache'
        self.png = b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR' + struct.pack('>II', 10, 20) + b'\x08\x06\x00\x00\x00' + b'\x00'*4

    def test_capture_uses_stdin_and_unique_paths(self):
        with patch('subprocess.run', side_effect=AssertionError('must not reread clipboard')):
            a = self.api.capture(io.BytesIO(self.png), str(self.cache))
            b = self.api.capture(io.BytesIO(self.png), str(self.cache))
        self.assertEqual(Path(a['path']).read_bytes(), self.png)
        self.assertEqual((a['width'], a['height']), (10,20))
        self.assertNotEqual(a['path'], b['path'])
        self.assertEqual(a['md5'], b['md5'])

    def test_capture_limits_and_private_modes(self):
        self.assertIsNone(self.api.capture(io.BytesIO(b'x' * (self.api.MAX_IMAGE_BYTES + 1)), str(self.cache)))
        self.assertIsNone(self.api.capture(io.BytesIO(b'not png'), str(self.cache)))
        a = self.api.capture(io.BytesIO(self.png), str(self.cache))
        self.assertEqual(Path(a['path']).stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.cache.stat().st_mode & 0o777, 0o700)

    def test_cleanup_only_owned_regular_direct_children(self):
        a = self.api.capture(io.BytesIO(self.png), str(self.cache))
        outside = Path(self.temp.name) / ('a'*32+'.png'); outside.write_bytes(b'keep')
        link = self.cache / ('b'*32+'.png'); link.symlink_to(outside)
        unrelated = self.cache/'notes.txt'; unrelated.write_text('keep')
        self.api.cleanup(str(self.cache), [a['path'], str(outside), str(link), str(unrelated)])
        self.assertFalse(Path(a['path']).exists())
        self.assertEqual(outside.read_bytes(), b'keep')
        self.assertTrue(link.is_symlink())
        self.assertTrue(unrelated.exists())

    def test_text_rejects_oversize_without_partial_record(self):
        self.assertEqual(self.api.read_text(io.BytesIO('😀'.encode()*16000)), '😀'*16000)
        self.assertIsNone(self.api.read_text(io.BytesIO('😀'.encode()*17000)))

    def test_copy_failures_propagate_without_real_clipboard(self):
        a = self.api.capture(io.BytesIO(self.png), str(self.cache))
        with patch('subprocess.run') as run:
            run.return_value.returncode = 1
            self.assertFalse(self.api.copy_image(a['path']))
            run.assert_called_once()
        self.assertFalse(self.api.copy_image(str(self.cache/'missing.png')))
        with patch('subprocess.run', side_effect=FileNotFoundError()):
            self.assertFalse(self.api.copy_image(a['path']))

if __name__ == '__main__': unittest.main()
