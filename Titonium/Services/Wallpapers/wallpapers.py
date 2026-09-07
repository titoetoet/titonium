#!/usr/bin/env python3
"""Bounded local catalog and explicit hyprpaper 0.8 wallpaper transaction.

No shell, daemon startup, config writes, preload/unload, wildcard or fallback output.
CLI prints one JSON result. Catalog is read-only; only acknowledged Apply writes state.
"""
import fcntl
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import time

MAX_ITEMS = 128
MAX_ENTRIES = 1024
MAX_BYTES = 32 * 1024 * 1024
MAX_PIXELS = 40_000_000
FORMATS = {'.png': 'PNG', '.jpg': 'JPEG', '.jpeg': 'JPEG', '.webp': 'WEBP'}


class Failure(Exception):
    pass


def run(argv, timeout=3):
    return subprocess.run(argv, capture_output=True, text=True, timeout=timeout, check=False)


def config_directories():
    config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'hypr/hyprpaper.conf'
    try:
        with config.open() as stream:
            text = stream.read(65536)
    except (OSError, UnicodeError):
        return []
    directories = []
    for line in text.splitlines():
        match = re.match(r'\s*path\s*=\s*(.+?)\s*$', line)
        if not match:
            continue
        path = Path(match[1].strip().strip('"').strip("'")).expanduser()
        if path.is_absolute() and path.parent.is_dir() and str(path.parent) not in directories:
            directories.append(str(path.parent))
    return directories


def directory(value):
    if not isinstance(value, str) or not value.strip() or '\x00' in value:
        raise Failure('directory')
    path = Path(value).expanduser()
    if not path.is_absolute() or not path.is_dir():
        raise Failure('directory')
    return path.resolve()


def image_info(path, root, decode=False):
    try:
        # Direct children only. Reject links and protocol/ImageMagick metacharacters.
        if path.is_symlink() or path.parent.resolve() != root or not path.is_file():
            raise Failure('image')
        if any(c in str(path) for c in ',\n\r\x00[]'):
            raise Failure('image')
        if path.suffix.lower() not in FORMATS or not 0 < path.stat().st_size <= MAX_BYTES:
            raise Failure('image')
        with path.open('rb') as stream:
            header = stream.read(16)
        fmt = ('PNG' if header.startswith(b'\x89PNG\r\n\x1a\n') else
               'JPEG' if header.startswith(b'\xff\xd8\xff') else
               'WEBP' if header[:4] == b'RIFF' and header[8:12] == b'WEBP' else '')
        if not fmt:
            raise Failure('image')
        source = fmt + ':' + str(path)
        limits = ['-limit', 'memory', '512MiB', '-limit', 'map', '0', '-limit', 'disk', '0', '-limit', 'thread', '1']
        probe = run(['magick', 'identify', *limits, '-ping', '-format', '%w %h %n', source], timeout=1)
        dimensions = probe.stdout.split()
        if probe.returncode or len(dimensions) != 3:
            raise Failure('image')
        width, height, frames = map(int, dimensions)
        if width <= 0 or height <= 0 or width * height > MAX_PIXELS or frames != 1:
            raise Failure('image')
        if decode:
            result = run(['magick', *limits, source, '-resize', '1x1', 'null:'], timeout=5)
            if result.returncode:
                raise Failure('image')
        return {'path': str(path), 'url': path.as_uri(), 'name': path.name,
                'width': width, 'height': height}
    except (OSError, ValueError, subprocess.TimeoutExpired):
        raise Failure('image') from None


def backend_available():
    runtime = os.environ.get('XDG_RUNTIME_DIR', '')
    instance = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
    if not runtime or not instance or '/' in instance:
        return False
    try:
        sock = Path(runtime) / 'hypr' / instance / '.hyprpaper.sock'
        if not stat.S_ISSOCK(sock.stat().st_mode):
            return False
        help_result = run(['hyprctl', 'hyprpaper', '--help'])
        # Older preload/wallpaper implementations cannot provide this transaction.
        help_text = help_result.stdout + help_result.stderr
        # Hyprctl 0.8 usage intentionally exits 1 even for a recognized --help.
        return (help_result.returncode in (0, 1)
                and 'wallpaper' in help_text
                and 'Arguments are [mon],[path],[fit_mode].' in help_text
                and not re.search(r'\b(error|failed|invalid)\b', help_text, re.I))
    except (OSError, subprocess.TimeoutExpired):
        return False


def catalog(data):
    roots = config_directories()
    value = data.get('directory', '')
    root = directory(value or (roots[0] if roots else ''))
    items = []
    truncated = False
    deadline = time.monotonic() + 4
    with os.scandir(root) as entries:
        for index, entry in enumerate(entries):
            if index >= MAX_ENTRIES or len(items) >= MAX_ITEMS or time.monotonic() >= deadline:
                truncated = True
                break
            try:
                items.append(image_info(Path(entry.path), root))
            except Failure:
                continue
    items.sort(key=lambda item: (item['name'].casefold(), item['name']))
    return {'ok': True, 'directory': str(root), 'directories': roots, 'items': items,
            'truncated': truncated, 'available': backend_available()}


def persist(screen, path, root, fit="cover"):
    base = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state')))
    if not base.is_absolute():
        raise OSError('state directory must be absolute')
    if base.resolve().is_relative_to(Path(__file__).resolve().parents[3]):
        raise OSError('runtime state must remain outside the source tree')
    # Per-output atomic records avoid cross-screen read/modify/write races.
    destination = base / 'titonium/wallpapers'
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    temp = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=destination, delete=False) as stream:
            temp = Path(stream.name)
            json.dump({'screen': screen, 'path': str(path), 'directory': str(root), 'fit': fit}, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, destination / (screen + '.json'))
    finally:
        if temp and temp.exists():
            temp.unlink()


def apply(data):
    if journal_path().exists(): raise Failure('locked')
    screen = data.get('screen', '')
    if not isinstance(screen, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,63}', screen):
        raise Failure('screen')
    root = directory(data.get('directory', ''))
    path = Path(data.get('path', ''))
    image_info(path, root, decode=True)
    if not backend_available():
        raise Failure('unavailable')
    monitors = run(['hyprctl', '-j', 'monitors'])
    try:
        outputs = json.loads(monitors.stdout)
        if monitors.returncode or not isinstance(outputs, list) or not any(m.get('name') == screen for m in outputs):
            raise Failure('screen')
    except (ValueError, AttributeError):
        raise Failure('screen') from None
    # Exactly one mutation. Never unload first, retry, or fall back to another output.
    identity = daemon_identity() if screen == 'DP-1' else None
    invalidate_tracked(screen)
    result = run(['hyprctl', 'hyprpaper', 'wallpaper', f'{screen},{path},cover'], timeout=8)
    if result.returncode or re.search(r'error|failed|invalid', result.stdout + result.stderr, re.I):
        raise Failure('backend')
    warning = ''
    try:
        if screen == 'DP-1':
            snapshot = {'screenName': screen, 'path': str(path), 'fit': 'cover'}
            track_acknowledged(snapshot, identity)
            update_managed_policy(snapshot)
        persist(screen, path, root)
    except (OSError, Failure):
        warning = 'persistence'
    return {'ok': True, 'screen': screen, 'path': str(path), 'warning': warning}



def state_directory():
    base = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state')))
    if not base.is_absolute() or base.resolve().is_relative_to(Path(__file__).resolve().parents[3]):
        raise Failure('persistence')
    return base / 'titonium/wallpapers'


def journal_path():
    return state_directory() / 'appearance-trial.json'


def write_journal(record):
    write_record(record, "appearance-trial.json")


def write_record(record, name):
    destination = state_directory()
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=destination, delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(record, stream)
            stream.flush(); os.fsync(stream.fileno())
        os.replace(temporary, destination / name)
        sync_directory(destination)
    except OSError:
        raise Failure('persistence') from None
    finally:
        if temporary and temporary.exists(): temporary.unlink()


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try: os.fsync(fd)
    finally: os.close(fd)


def read_journal(generation=None):
    try:
        record = json.loads(journal_path().read_text())
        if not isinstance(record, dict) or record.get('version') != 1:
            raise Failure('persistence')
    except (OSError, ValueError):
        raise Failure('persistence') from None
    if generation is not None and record.get('generation') != generation:
        raise Failure('stale')
    return record


def remove_journal():
    journal_path().unlink()
    sync_directory(state_directory())


def local_image(value):
    if not isinstance(value, str) or not value or '\x00' in value:
        raise Failure('image')
    path = Path(value)
    if not path.is_absolute(): raise Failure('image')
    image_info(path, path.parent.resolve(), decode=True)
    return str(path)


def verify_screen(screen):
    # Appearance is deliberately scoped to the existing primary screen policy.
    if screen != 'DP-1': raise Failure('screen')
    response = run(['hyprctl', '-j', 'monitors'])
    try:
        outputs = json.loads(response.stdout)
        if response.returncode or not isinstance(outputs, list) or not any(m.get('name') == screen for m in outputs):
            raise Failure('screen')
    except (ValueError, AttributeError): raise Failure('screen') from None



def daemon_identity():
    runtime = os.environ.get('XDG_RUNTIME_DIR', '')
    instance = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
    if not runtime or not instance or '/' in instance: raise Failure('unavailable')
    sock = Path(runtime) / 'hypr' / instance / '.hyprpaper.sock'
    try:
        info = sock.stat()
        if not stat.S_ISSOCK(info.st_mode): raise Failure('unavailable')
        return {'instance': instance, 'socket': str(sock.resolve()), 'device': info.st_dev,
                'inode': info.st_ino, 'created': info.st_ctime_ns,
                'boot': Path('/proc/sys/kernel/random/boot_id').read_text().strip()}
    except OSError: raise Failure('unavailable') from None


def managed_policy_path():
    return state_directory() / 'managed-policy.json'


def read_managed_policy():
    try:
        record = json.loads(managed_policy_path().read_text())
        if record.get('version') != 1 or record.get('screenName') != 'DP-1': raise Failure('persistence')
        return validate_snapshot(record)
    except (OSError, ValueError, AttributeError): raise Failure('persistence') from None


def validate_snapshot(record):
    if not isinstance(record, dict) or record.get('screenName') != 'DP-1': raise Failure('baseline')
    if record.get('fit') not in ('cover', 'contain', 'tile', 'fill'): raise Failure('baseline')
    return {'screenName': 'DP-1', 'path': local_image(record.get('path')), 'fit': record['fit']}


def invalidate_tracked(screen):
    if screen != 'DP-1': return
    path = state_directory() / 'managed-current.json'
    if path.exists():
        path.unlink()
        sync_directory(state_directory())


def track_acknowledged(snapshot, identity):
    if snapshot['screenName'] != 'DP-1': return
    # A daemon replacement during IPC cannot establish a trustworthy baseline.
    if daemon_identity() != identity: raise Failure('baseline')
    write_record({'version': 1, 'identity': identity, 'snapshot': snapshot}, 'managed-current.json')


def tracked_baseline(screen):
    try:
        data = json.loads((state_directory() / 'managed-current.json').read_text())
        if data.get('version') != 1 or data.get('identity') != daemon_identity(): raise Failure('baseline')
        snapshot = validate_snapshot(data.get('snapshot'))
        if snapshot['screenName'] != screen: raise Failure('baseline')
        return snapshot
    except (OSError, ValueError, TypeError, AttributeError): raise Failure('baseline') from None


def update_managed_policy(snapshot):
    if snapshot['screenName'] == 'DP-1' and managed_policy_path().exists():
        write_record({'version': 1, **snapshot}, 'managed-policy.json')


def appearance_initialize(data):
    if journal_path().exists(): raise Failure('locked')
    snapshot = validate_snapshot({'screenName': data.get('screen'), 'path': data.get('path'), 'fit': data.get('fit', 'cover')})
    # Explicit opt-in establishes reality by acknowledged IPC, never configuration inference.
    set_wallpaper(snapshot)
    write_record({'version': 1, **snapshot}, 'managed-policy.json')
    persist(snapshot['screenName'], snapshot['path'], Path(snapshot['path']).parent, snapshot['fit'])
    return {'ok': True, 'managed': True, 'canCaptureBaseline': True, 'capabilityError': '', 'snapshot': snapshot}


def recover_managed_baseline():
    if not managed_policy_path().exists(): return
    try:
        tracked_baseline('DP-1')
        return
    except Failure:
        pass
    # Recovery already resolved any trial journal before reaching this point.
    set_wallpaper(read_managed_policy())


def capture_baseline(screen):
    verify_screen(screen)
    if not backend_available(): raise Failure('unavailable')
    response = run(['hyprctl', 'hyprpaper', 'get-active'])
    # Do not infer fit or actual daemon state from configuration/persisted records.
    # Backends without a structured, complete snapshot fail closed.
    try:
        rows = json.loads(response.stdout)
        if response.returncode or not isinstance(rows, list): raise Failure('baseline')
        matches = [r for r in rows if isinstance(r, dict) and r.get('monitor') == screen]
        if len(matches) != 1 or matches[0].get('fit') not in ('cover', 'contain', 'tile', 'fill'):
            raise Failure('baseline')
        return {'screenName': screen, 'path': local_image(matches[0].get('path')), 'fit': matches[0]['fit']}
    except (ValueError, TypeError, Failure):
        return tracked_baseline(screen)


def set_wallpaper(snapshot):
    screen = snapshot['screenName']; verify_screen(screen)
    path = local_image(snapshot['path'])
    fit = snapshot['fit']
    if fit not in ('cover', 'contain', 'tile', 'fill'): raise Failure('baseline')
    if not backend_available(): raise Failure('unavailable')
    identity = daemon_identity()
    invalidate_tracked(screen)
    response = run(['hyprctl', 'hyprpaper', 'wallpaper', f'{screen},{path},{fit}'], timeout=5)
    if response.returncode or re.search(r'error|failed|invalid', response.stdout + response.stderr, re.I):
        raise Failure('backend')
    track_acknowledged({'screenName': screen, 'path': path, 'fit': fit}, identity)


def appearance_begin(data):
    if journal_path().exists(): raise Failure('locked')
    generation = data.get('generation')
    if not isinstance(generation, int) or isinstance(generation, bool): raise Failure('request')
    candidate = data.get('candidate')
    if not isinstance(candidate, dict): raise Failure('request')
    fit = data.get('fit', 'cover')
    if fit not in ('cover', 'contain', 'tile', 'fill'): raise Failure('baseline')
    path = local_image(data.get('path'))
    baseline = capture_baseline(data.get('screen'))
    record = {'version': 1, 'generation': generation, 'phase': 'trial', 'baseline': baseline,
              'target': {'screenName': baseline['screenName'], 'path': path, 'fit': fit}, 'candidate': candidate}
    # Durable intent precedes the first side effect, even if IPC times out.
    write_journal(record)
    set_wallpaper(record['target'])
    return {'ok': True, 'snapshot': baseline, 'lease': True}


def appearance_saving(data):
    record = read_journal(data.get('generation'))
    record['phase'] = 'saving'; write_journal(record)
    return {'ok': True, 'lease': True}


def appearance_rollback(data):
    record = read_journal(data.get('generation'))
    set_wallpaper(record['baseline'])
    remove_journal()
    return {'ok': True, 'lease': False, 'snapshot': record['baseline']}


def appearance_commit(data):
    record = read_journal(data.get('generation'))
    if record.get('phase') != 'saving': raise Failure('request')
    target = record['target']
    try:
        persist(target['screenName'], target['path'], Path(target['path']).parent, target['fit'])
        sync_directory(state_directory())
        update_managed_policy(target)
        remove_journal()
    except OSError: raise Failure('persistence') from None
    return {'ok': True, 'lease': False, 'screen': target['screenName'], 'path': target['path']}


def appearance_follow(data):
    # The candidate is already committed by Preferences. Auto generations are isolated
    # from interactive coordinator callbacks; the same journal protocol protects crashes.
    request = dict(data, generation=-1)
    try:
        appearance_begin(request)
        appearance_saving(request)
        return appearance_commit(request)
    except (Failure, OSError, subprocess.TimeoutExpired):
        if journal_path().exists():
            record = read_journal()
            if record.get('generation') == -1 and record.get('phase') == 'trial':
                appearance_rollback(request)
        raise


def appearance_probe(data):
    result = {'ok': True, 'canCaptureBaseline': False, 'capabilityError': '', 'managed': managed_policy_path().exists()}
    try:
        capture_baseline('DP-1')
        result['canCaptureBaseline'] = True
    except Failure as error:
        result['capabilityError'] = str(error)
    except subprocess.TimeoutExpired:
        result['capabilityError'] = 'timeout'
    except (OSError, ValueError, TypeError):
        result['capabilityError'] = 'unavailable'
    return result


def appearance_recover(data):
    if not journal_path().exists():
        try: recover_managed_baseline()
        except (Failure, OSError, subprocess.TimeoutExpired):
            return {**appearance_probe({}), 'lease': False}
        return {**appearance_probe({}), 'lease': False}
    record = read_journal()
    request = {'generation': record['generation']}
    if record.get('phase') == 'saving' and record.get('candidate') == data.get('persisted'):
        result = appearance_commit(request)
    else:
        result = appearance_rollback(request)
    recover_managed_baseline()
    return {**result, **appearance_probe({})}


def main():
    try:
        action, payload = sys.argv[1:]
        data = json.loads(payload)
        if not isinstance(data, dict):
            raise Failure('request')
        actions = {'catalog': catalog, 'apply': apply, 'appearance-begin': appearance_begin,
                   'appearance-saving': appearance_saving, 'appearance-rollback': appearance_rollback,
                   'appearance-commit': appearance_commit, 'appearance-recover': appearance_recover,
                   'appearance-probe': appearance_probe, 'appearance-follow': appearance_follow,
                   'appearance-initialize': appearance_initialize}
        if action not in actions:
            raise Failure('request')
        if action in ('catalog', 'appearance-probe'):
            result = actions[action](data)
        else:
            lock_root = Path(os.environ.get('XDG_RUNTIME_DIR', tempfile.gettempdir())) / ('titonium-wallpapers-' + str(os.getuid()))
            lock_root.mkdir(parents=True, exist_ok=True, mode=0o700)
            with (lock_root / 'transaction.lock').open('a') as lock:
                try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError: raise Failure('locked') from None
                result = actions[action](data)
    except Failure as error:
        result = {'ok': False, 'error': str(error)}
    except subprocess.TimeoutExpired:
        result = {'ok': False, 'error': 'timeout'}
    except (OSError, ValueError, TypeError):
        result = {'ok': False, 'error': 'request'}
    try:
        result['lease'] = journal_path().exists()
        result['managed'] = managed_policy_path().exists()
    except Failure: result['lease'] = True
    print(json.dumps(result))


if __name__ == '__main__':
    main()
