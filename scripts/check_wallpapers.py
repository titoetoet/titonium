#!/usr/bin/env python3
"""Wallpaper I/O contract: only a temporary fake hyprctl can receive Apply."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest

HELPER = Path(__file__).resolve().parents[1] / 'Titonium/Services/Wallpapers/wallpapers.py'


class WallpapersTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.catalog = self.root / 'pictures with spaces'
        self.catalog.mkdir()
        self.picture = self.catalog / 'a $(touch NEVER).png'
        # A real decoder fixture, created without a live wallpaper backend.
        subprocess.run(['magick', '-size', '2x2', 'xc:red', str(self.picture)], check=True)
        self.config = self.root / 'config/hypr/hyprpaper.conf'
        self.config.parent.mkdir(parents=True)
        self.config.write_text(f'wallpaper {{\n monitor = DP-1\n path = {self.picture}\n}}\n')
        self.log = self.root / 'calls.jsonl'
        bindir = self.root / 'bin'
        bindir.mkdir()
        fake = bindir / 'hyprctl'
        fake.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
a = sys.argv[1:]
with open(os.environ['FAKE_LOG'], 'a') as f: f.write(json.dumps(a) + '\\n')
if a == ['hyprpaper', '--help']:
    print('requests: wallpaper Arguments are [mon],[path],[fit_mode].')
    if os.getenv('HELP_ERROR'): print('error: backend failed', file=sys.stderr)
    sys.exit(int(os.getenv('HELP_EXIT', '0')))
elif a == ['-j', 'monitors']:
    print(json.dumps([{'name': 'DP-3'}] if os.getenv('MISSING_SCREEN') else [{'name': 'DP-1'}, {'name': 'DP-3'}]))
elif len(a) == 3 and a[:2] == ['hyprpaper', 'wallpaper']:
    if os.getenv('FAIL_APPLY'):
        print('failed to set wallpaper: Invalid path')
        sys.exit(0 if os.getenv('ZERO_EXIT_FAILURE') else 1)
    Path(os.environ['FAKE_CURRENT']).write_text(a[2])
else:
    sys.exit(7)
''')
        fake.chmod(0o755)
        runtime = self.root / 'run/hypr/test'
        runtime.mkdir(parents=True)
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.bind(str(runtime / '.hyprpaper.sock'))
        self.addCleanup(self.sock.close)
        self.env = dict(os.environ, PATH=f'{bindir}:' + os.environ['PATH'],
                        XDG_CONFIG_HOME=str(self.root / 'config'), XDG_STATE_HOME=str(self.root / 'state'),
                        XDG_RUNTIME_DIR=str(self.root / 'run'), HYPRLAND_INSTANCE_SIGNATURE='test',
                        FAKE_LOG=str(self.log), FAKE_CURRENT=str(self.root / 'current'))
        (self.root / 'current').write_text('original')

    def call(self, action, **kwargs):
        result = subprocess.run(['python3', str(HELPER), action, json.dumps(kwargs)],
                                env=self.env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def apply(self, **kwargs):
        return self.call('apply', directory=str(self.catalog), path=str(self.picture),
                         screen=kwargs.pop('screen', 'DP-1'), **kwargs)

    def mutations(self):
        return [a for a in map(json.loads, self.log.read_text().splitlines())
                if a[:2] == ['hyprpaper', 'wallpaper']] if self.log.exists() else []

    def test_discovery_and_preview_never_apply_or_persist(self):
        data = self.call('catalog', directory='')
        self.assertTrue(data['ok'], data)
        self.assertEqual(data['directory'], str(self.catalog))
        self.assertEqual(data['items'][0]['path'], str(self.picture))
        self.assertTrue(data['items'][0]['url'].startswith('file:///'))
        self.assertEqual(self.mutations(), [])
        self.assertFalse((self.root / 'state').exists())

    def test_catalog_rejects_nonimages_symlinks_and_is_bounded(self):
        (self.catalog / 'bad.png').write_text('not an image')
        (self.catalog / 'remote.svg').write_text('<svg/>')
        (self.catalog / 'link.png').symlink_to(self.picture)
        for i in range(150):
            (self.catalog / f'{i:03}.png').write_bytes(self.picture.read_bytes())
        data = self.call('catalog', directory=str(self.catalog))
        self.assertLessEqual(len(data['items']), 128)
        self.assertTrue(data['truncated'])
        self.assertFalse({'bad.png', 'remote.svg', 'link.png'} & {x['name'] for x in data['items']})

    def test_missing_directory_and_backend_leave_catalog_usable(self):
        self.assertEqual(self.call('catalog', directory='/does/not/exist')['error'], 'directory')
        self.sock.close()
        (self.root / 'run/hypr/test/.hyprpaper.sock').unlink()
        data = self.call('catalog', directory=str(self.catalog))
        self.assertTrue(data['items'])
        self.assertFalse(data['available'])

    def test_valid_usage_exit_one_is_supported_but_errors_are_not(self):
        self.env['HELP_EXIT'] = '1'
        data = self.call('catalog', directory=str(self.catalog))
        self.assertTrue(data['available'])
        self.env['HELP_ERROR'] = '1'
        self.assertFalse(self.call('catalog', directory=str(self.catalog))['available'])
        del self.env['HELP_ERROR']
        self.env['HELP_EXIT'] = '2'
        self.assertFalse(self.call('catalog', directory=str(self.catalog))['available'])

    def test_raster_signature_handles_png_with_jpg_filename(self):
        renamed = self.catalog / 'renamed.jpg'
        renamed.write_bytes(self.picture.read_bytes())
        data = self.call('catalog', directory=str(self.catalog))
        self.assertIn(str(renamed), [item['path'] for item in data['items']])

    def test_exact_screen_and_literal_path_single_apply_success_only_store(self):
        result = self.apply()
        self.assertTrue(result['ok'], result)
        self.assertEqual(self.mutations(), [['hyprpaper', 'wallpaper', f'DP-1,{self.picture},cover']])
        stored = json.loads((self.root / 'state/titonium/wallpapers/DP-1.json').read_text())
        self.assertEqual(stored['path'], str(self.picture))
        self.assertFalse((self.root / 'state/titonium/wallpapers/DP-3.json').exists())

    def test_wildcard_description_and_argument_injection_fail_before_backend(self):
        for name in ['', '*', 'desc:monitor', 'DP-1,DP-3', 'DP-1\nDP-3', '-j']:
            with self.subTest(name=name):
                self.assertEqual(self.apply(screen=name)['error'], 'screen')
        self.assertEqual(self.mutations(), [])

    def test_lost_screen_deleted_file_and_decode_failure_do_not_apply(self):
        self.env['MISSING_SCREEN'] = '1'
        self.assertEqual(self.apply()['error'], 'screen')
        del self.env['MISSING_SCREEN']
        self.picture.write_text('invalid')
        self.assertEqual(self.apply()['error'], 'image')
        self.picture.unlink()
        self.assertEqual(self.apply()['error'], 'image')
        self.assertEqual(self.mutations(), [])

    def test_path_outside_root_and_protocol_delimiters_rejected(self):
        outside = self.root / 'outside.png'
        outside.write_bytes(self.picture.read_bytes())
        result = self.call('apply', directory=str(self.catalog), path=str(outside), screen='DP-1')
        self.assertEqual(result['error'], 'image')
        self.picture = self.catalog / 'comma,name.png'
        self.picture.write_bytes(outside.read_bytes())
        self.assertEqual(self.apply()['error'], 'image')
        self.assertEqual(self.mutations(), [])

    def test_zero_exit_backend_error_is_not_success(self):
        self.env['FAIL_APPLY'] = '1'
        self.env['ZERO_EXIT_FAILURE'] = '1'
        self.assertEqual(self.apply()['error'], 'backend')
        self.assertFalse((self.root / 'state').exists())
        self.assertEqual((self.root / 'current').read_text(), 'original')

    def test_success_with_unwritable_state_reports_warning_without_retry(self):
        (self.root / 'state').write_text('not a directory')
        result = self.apply()
        self.assertTrue(result['ok'])
        self.assertEqual(result['warning'], 'persistence')
        self.assertEqual(len(self.mutations()), 1)

    def test_backend_failure_preserves_wallpaper_and_previous_persistence(self):
        self.assertTrue(self.apply()['ok'])
        saved = (self.root / 'state/titonium/wallpapers/DP-1.json').read_bytes()
        (self.root / 'current').write_text('original')
        self.env['FAIL_APPLY'] = '1'
        self.assertEqual(self.apply()['error'], 'backend')
        self.assertEqual((self.root / 'current').read_text(), 'original')
        self.assertEqual((self.root / 'state/titonium/wallpapers/DP-1.json').read_bytes(), saved)

    def test_view_lifecycle_selection_and_apply_with_fake_backend(self):
        project = HELPER.parents[3]
        imports = self.root / 'imports'
        imports.mkdir()
        (imports / 'qs').symlink_to(project)
        (self.root / 'Titonium').symlink_to(project / 'Titonium')
        (self.root / 'config/i18n').symlink_to(project / 'config/i18n')
        (self.root / 'config/defaults').symlink_to(project / 'config/defaults')
        shell = self.root / 'shell.qml'
        view_url = (self.root / 'Titonium/Bar/center/WallpapersContent.qml').as_uri()
        shell.write_text('''import QtQuick
import Quickshell
import qs.Titonium.Services.Wallpapers
ShellRoot {
    id: root
    property var view: null
    property int stage: 0
    function require(value, message) { if (!value) { console.error(message); Qt.quit(); } }
    Component.onCompleted: {
        require(!WallpapersService.active && !WallpapersService.busy, "inactive service started");
        WallpapersService.applyTo("DP-1", "ignored while inactive");
        require(!WallpapersService.busy, "inactive Apply started");
        let component = Qt.createComponent(VIEW_URL);
        require(component.status === Component.Ready, component.errorString());
        view = component.createObject(root, {width: 700, height: 420, screenName: "DP-1", active: false});
        require(view !== null, "view creation failed");
        view.active = true;
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if ((!root.view && root.stage !== 3) || WallpapersService.busy) return;
            if (root.stage === 0 && WallpapersService.items.length) {
                root.require(WallpapersService.active, "visible view not active");
                WallpapersService.setVisible(root, true);
                root.view.active = false;
                root.require(WallpapersService.active, "one consumer released another consumer");
                root.view.active = true;
                WallpapersService.setVisible(root, false);
                root.view.selected = WallpapersService.items[0];
                root.require(Object.keys(WallpapersService.applied).length === 0, "preview applied");
                root.view.active = false;
                root.require(!WallpapersService.active, "hidden view retained lease");
                root.view.active = true;
                root.stage = 1;
            } else if (root.stage === 1) {
                WallpapersService.applyTo("DP-1", WallpapersService.items[0].path);
                root.stage = 2;
            } else if (root.stage === 2) {
                root.require(!!WallpapersService.applied["DP-1"], "Apply did not publish success");
                root.view.destroy();
                root.stage = 3;
            } else if (root.stage === 3) {
                root.require(!WallpapersService.active, "destroyed view retained lease");
                console.log("PASS wallpapers lifecycle"); Qt.quit();
            }
        }
    }
    Timer { interval: 10000; running: true; onTriggered: { console.error("wallpapers timed out", root.stage, WallpapersService.active, WallpapersService.busy, WallpapersService.statusKey); Qt.quit(); } }
}
'''.replace('VIEW_URL', json.dumps(view_url)))
        env = dict(self.env, QT_QPA_PLATFORM='offscreen', QML_IMPORT_PATH=str(imports))
        env.pop('WAYLAND_DISPLAY', None)
        try:
            result = subprocess.run(['qs', '-n', '-p', str(shell)], env=env,
                                    capture_output=True, text=True, timeout=15)
        except subprocess.TimeoutExpired as error:
            self.fail(str(error.stdout) + str(error.stderr))
        output = result.stdout + result.stderr
        self.assertIn('PASS wallpapers lifecycle', output, output)
        self.assertNotIn('ERROR', output)
        self.assertEqual(len(self.mutations()), 1)


if __name__ == '__main__':
    unittest.main()
