#!/usr/bin/env python3
"""Appearance transactions use isolated fake backend; never contact the desktop."""
import importlib.util
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
import subprocess
import os
import json

spec = importlib.util.spec_from_file_location('wallpapers', Path(__file__).resolve().parents[1] / 'Titonium/Services/Wallpapers/wallpapers.py')
w = importlib.util.module_from_spec(spec)
spec.loader.exec_module(w)

class TransactionTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.old = self.root / 'old.png'; self.new = self.root / 'new $(touch NEVER).png'
        self.old.write_bytes(b'image'); self.new.write_bytes(b'image')
        self.current = str(self.old); self.calls = []; self.backendFails = False; self.capture = True
        self.enter(patch.dict(os.environ, XDG_STATE_HOME=str(self.root / 'state')))
        self.enter(patch.object(w, 'backend_available', return_value=True))
        self.identity = {'socket': 'fake-session-1'}
        self.enter(patch.object(w, 'daemon_identity', side_effect=lambda: self.identity, create=True))
        self.enter(patch.object(w, 'image_info', side_effect=self.image))
        self.enter(patch.object(w, 'run', side_effect=self.backend))
        self.data = dict(screen='DP-1', path=str(self.new), generation=4, candidate={'themeId':'glass'})
    def enter(self, context):
        context.start(); self.addCleanup(context.stop)
    def image(self, path, root, decode=False):
        if not path.is_file(): raise w.Failure('image')
        return {}
    def backend(self, argv, timeout=3):
        self.calls.append(argv)
        if argv == ['hyprctl', '-j', 'monitors']: return subprocess.CompletedProcess(argv,0,'[{"name":"DP-1"}]','')
        if argv == ['hyprctl', 'hyprpaper', 'get-active']:
            return subprocess.CompletedProcess(argv,0,json.dumps([{'monitor':'DP-1','path':self.current,'fit':'cover'}]) if self.capture else 'invalid request','')
        if argv[:2] == ['hyprctl','hyprpaper'] and argv[2]=='wallpaper':
            if self.backendFails: raise subprocess.TimeoutExpired(argv, timeout)
            self.current=argv[3].split(',')[1]
            return subprocess.CompletedProcess(argv,0,'ok','')
        raise AssertionError(argv)
    def test_target_fit_preserved_in_apply_commit_and_recovery(self):
        self.data['fit'] = 'contain'
        w.appearance_begin(self.data)
        self.assertEqual(w.read_journal()['target']['fit'], 'contain')
        self.assertEqual(self.calls[-1][-1], f'DP-1,{self.new},contain')
        w.appearance_saving({'generation':4})
        w.appearance_recover({'persisted': self.data['candidate']})
        self.assertFalse(w.journal_path().exists())
        self.assertEqual(json.loads((w.state_directory()/'DP-1.json').read_text())['fit'], 'contain')
    def test_invalid_target_fit_never_mutates_or_journals(self):
        self.data['fit'] = 'cover,DP-3'
        with self.assertRaises(w.Failure): w.appearance_begin(self.data)
        self.assertEqual(self.current, str(self.old))
        self.assertFalse(w.journal_path().exists())
    def test_empty_recovery_probes_capability_without_mutation(self):
        result = w.appearance_recover({'persisted': {}})
        self.assertTrue(result['ok']); self.assertFalse(result['lease'])
        self.assertTrue(result['canCaptureBaseline'])
        self.assertEqual(self.current, str(self.old))
        self.assertFalse(w.state_directory().exists())
    def test_unsupported_recovery_remains_ready(self):
        self.capture = False
        result = w.appearance_recover({'persisted': {}})
        self.assertTrue(result['ok']); self.assertFalse(result['lease'])
        self.assertFalse(result['canCaptureBaseline'])
        self.assertEqual(result['capabilityError'], 'baseline')
        self.capture = True
        self.assertTrue(w.appearance_probe({})['canCaptureBaseline'])
    def test_persisted_follow_commits_without_settings_write(self):
        result = w.appearance_follow(self.data)
        self.assertTrue(result['ok']); self.assertFalse(result['lease'])
        self.assertEqual(self.current, str(self.new))
        self.assertFalse(w.journal_path().exists())
    def test_persisted_follow_failed_apply_restores_and_releases(self):
        original = w.set_wallpaper
        count = [0]
        def fail_once(snapshot):
            count[0] += 1
            if count[0] == 1: raise w.Failure('backend')
            return original(snapshot)
        with patch.object(w, 'set_wallpaper', side_effect=fail_once):
            with self.assertRaises(w.Failure): w.appearance_follow(self.data)
        self.assertEqual(self.current, str(self.old)); self.assertFalse(w.journal_path().exists())
    def test_managed_initialization_enables_unsupported_capture(self):
        self.capture = False
        with self.assertRaises(w.Failure): w.capture_baseline('DP-1')
        result = w.appearance_initialize(dict(screen='DP-1', path=str(self.old), fit='contain'))
        self.assertTrue(result['canCaptureBaseline'])
        self.assertEqual(w.capture_baseline('DP-1')['fit'], 'contain')
        self.assertEqual(self.current, str(self.old))
    def test_managed_trial_updates_tracker_but_not_committed_baseline(self):
        self.capture = False
        w.appearance_initialize(dict(screen='DP-1', path=str(self.old), fit='cover'))
        w.appearance_begin(self.data)
        self.assertEqual(w.capture_baseline('DP-1')['path'], str(self.new))
        self.assertEqual(w.read_managed_policy()['path'], str(self.old))
        w.appearance_rollback({'generation':4})
        self.assertEqual(w.capture_baseline('DP-1')['path'], str(self.old))
    def test_new_daemon_requires_reapply_then_restores_last_committed(self):
        self.capture = False
        w.appearance_initialize(dict(screen='DP-1', path=str(self.old), fit='cover'))
        w.appearance_begin(self.data); w.appearance_saving({'generation':4}); w.appearance_commit({'generation':4})
        self.identity = {'socket': 'fake-session-2'}; self.current = 'daemon default'
        with self.assertRaises(w.Failure): w.capture_baseline('DP-1')
        result = w.appearance_recover({'persisted': self.data['candidate']})
        self.assertTrue(result['canCaptureBaseline']); self.assertEqual(self.current, str(self.new))
    def test_managed_failed_mutation_invalidates_tracked_baseline(self):
        self.capture = False
        w.appearance_initialize(dict(screen='DP-1', path=str(self.old), fit='cover'))
        self.backendFails = True
        with self.assertRaises(subprocess.TimeoutExpired): w.appearance_begin(self.data)
        with self.assertRaises(w.Failure): w.capture_baseline('DP-1')
        self.assertTrue(w.journal_path().exists())
    def test_bootstrap_rejects_pending_trial_and_other_monitor(self):
        with self.assertRaises(w.Failure): w.appearance_initialize(dict(screen='DP-3', path=str(self.old)))
        w.appearance_begin(self.data)
        with self.assertRaises(w.Failure): w.appearance_initialize(dict(screen='DP-1', path=str(self.old)))
    def test_managed_restart_resolves_pending_trial_before_initialization(self):
        self.capture = False
        w.appearance_initialize(dict(screen='DP-1', path=str(self.old), fit='contain'))
        w.appearance_begin(self.data)
        self.identity = {'socket': 'new-daemon'}; self.current = 'default'
        start = len(self.calls)
        result = w.appearance_recover({'persisted': {}})
        self.assertTrue(result['canCaptureBaseline'])
        mutations = [call for call in self.calls[start:] if call[:3] == ['hyprctl','hyprpaper','wallpaper']]
        self.assertEqual(len(mutations), 1)
        self.assertEqual(mutations[0][3], f'DP-1,{self.old},contain')
    def test_managed_bootstrap_timeout_does_not_opt_in(self):
        self.capture = False; self.backendFails = True
        with self.assertRaises(subprocess.TimeoutExpired):
            w.appearance_initialize(dict(screen='DP-1', path=str(self.old)))
        self.assertFalse(w.managed_policy_path().exists())
        self.assertFalse(w.appearance_probe({})['canCaptureBaseline'])
    def test_probe_does_not_restore_managed_after_restart(self):
        self.capture = False
        w.appearance_initialize(dict(screen='DP-1', path=str(self.old)))
        self.identity = {'socket':'new-daemon'}; self.current = 'default'
        result = w.appearance_probe({})
        self.assertTrue(result['managed']); self.assertFalse(result['canCaptureBaseline'])
        self.assertEqual(self.current, 'default')
    def test_trial_rollback_and_lease(self):
        result=w.appearance_begin(self.data); self.assertTrue(result['ok'])
        self.assertEqual(self.current,str(self.new))
        self.assertFalse((w.state_directory()/'DP-1.json').exists())
        with self.assertRaises(w.Failure): w.apply(dict(screen='DP-1',path=str(self.new),directory=str(self.root)))
        with self.assertRaises(w.Failure): w.appearance_rollback({'generation':3})
        w.appearance_rollback({'generation':4}); self.assertEqual(self.current,str(self.old))
        self.assertFalse(w.journal_path().exists())
    def test_commit_and_crash_recovery(self):
        w.appearance_begin(self.data)
        w.appearance_saving({'generation':4})
        w.appearance_recover({'persisted':{'themeId':'glass'}})
        self.assertEqual(json.loads((w.state_directory()/'DP-1.json').read_text())['path'],str(self.new))
        self.assertFalse(w.journal_path().exists())
    def test_crash_before_settings_save_rolls_back(self):
        w.appearance_begin(self.data); w.appearance_recover({'persisted':{'themeId':'neutral'}})
        self.assertEqual(self.current,str(self.old))
    def test_unreadable_baseline_rejects_without_mutation(self):
        self.capture=False
        with self.assertRaises(w.Failure): w.appearance_begin(self.data)
        self.assertEqual(self.current,str(self.old)); self.assertFalse(w.journal_path().exists())
    def test_timeout_retains_recoverable_journal(self):
        self.backendFails=True
        with self.assertRaises(subprocess.TimeoutExpired): w.appearance_begin(self.data)
        self.assertTrue(w.journal_path().exists()); self.backendFails=False
        w.appearance_rollback({'generation':4}); self.assertFalse(w.journal_path().exists())
    def test_same_candidate_trial_recovery_still_restores(self):
        w.appearance_begin(self.data)
        w.appearance_recover({'persisted': self.data['candidate']})
        self.assertEqual(self.current, str(self.old))
    def test_saving_failure_does_not_release_lease(self):
        w.appearance_begin(self.data)
        with patch.object(w, 'write_journal', side_effect=w.Failure('persistence')):
            with self.assertRaises(w.Failure): w.appearance_saving({'generation': 4})
        self.assertEqual(w.read_journal()['phase'], 'trial')
    def test_monitor_loss_preserves_recovery_journal(self):
        w.appearance_begin(self.data)
        with patch.object(w, 'verify_screen', side_effect=w.Failure('screen')):
            with self.assertRaises(w.Failure): w.appearance_rollback({'generation':4})
        self.assertTrue(w.journal_path().exists())
    def test_missing_candidate_and_daemon_fail_before_journal(self):
        self.new.unlink()
        with self.assertRaises(w.Failure): w.appearance_begin(self.data)
        self.assertFalse(w.journal_path().exists())
        self.new.write_bytes(b'image')
        with patch.object(w, 'backend_available', return_value=False):
            with self.assertRaises(w.Failure): w.appearance_begin(self.data)
        self.assertFalse(w.journal_path().exists())
    def test_stale_commit_and_persist_failure_retain_journal(self):
        w.appearance_begin(self.data); w.appearance_saving({'generation':4})
        with self.assertRaises(w.Failure): w.appearance_commit({'generation':3})
        with patch.object(w, 'persist', side_effect=OSError('disk')):
            with self.assertRaises(w.Failure): w.appearance_commit({'generation':4})
        self.assertTrue(w.journal_path().exists())
    def test_missing_restore_retains_lease(self):
        w.appearance_begin(self.data); self.old.unlink()
        with self.assertRaises(w.Failure): w.appearance_rollback({'generation':4})
        self.assertTrue(w.journal_path().exists())

class LargeRasterTest(unittest.TestCase):
    def test_large_jpeg_within_pixel_cap_decodes_under_bounded_memory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / 'large photo.jpg'
            subprocess.run(['magick', '-limit', 'memory', '512MiB', '-limit', 'map', '0',
                '-limit', 'disk', '0', '-limit', 'thread', '1', '-size', '6966x4672', 'xc:navy', str(path)],
                check=True, capture_output=True, timeout=10)
            info = w.image_info(path, root, decode=True)
            self.assertEqual((info['width'], info['height']), (6966, 4672))

if __name__=='__main__': unittest.main()
