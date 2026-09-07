"""Read-only optional MPRIS TrackList adapter. No native TrackList API in Quickshell.

Uses system DBus tools; observes signals rather than polling. No media is played,
changed, downloaded or persisted. Unsupported/shuffled queues fail closed.
"""
import json
import subprocess
import sys
from urllib.parse import urlparse

PATH = '/org/mpris/MediaPlayer2'
PLAYER = 'org.mpris.MediaPlayer2.Player'
TRACKS = 'org.mpris.MediaPlayer2.TrackList'


def next_id(tracks, current, shuffle, loop):
    if shuffle or current not in tracks:
        return None
    if loop == 'Track':
        return current
    index = tracks.index(current) + 1
    if index < len(tracks):
        return tracks[index]
    return tracks[0] if tracks and loop == 'Playlist' else None


def metadata(raw):
    title = str(raw.get('xesam:title', '')).strip()
    if not title:
        return None
    artist = raw.get('xesam:artist', [])
    if isinstance(artist, list):
        artist = ', '.join(str(x).strip() for x in artist if str(x).strip())
    art = str(raw.get('mpris:artUrl', ''))
    if urlparse(art).scheme not in ('file', 'https', 'http'):
        art = ''
    try:
        length = max(0, int(raw.get('mpris:length', 0))) / 1_000_000
    except (ValueError, TypeError, OverflowError):
        length = 0
    return {'title': title, 'artist': str(artist), 'artUrl': art, 'length': length}


def unwrap(value):
    if isinstance(value, dict):
        if 'type' in value and 'data' in value:
            return unwrap(value['data'])
        return {k: unwrap(v) for k, v in value.items()}
    if isinstance(value, list):
        return [unwrap(v) for v in value]
    return value


def call(identity, *args):
    result = subprocess.run(['busctl', '--user', '--json=short', '--timeout=2',
                             *args[:1], identity, PATH, *args[1:]],
                            capture_output=True, text=True, timeout=3, check=True)
    return unwrap(json.loads(result.stdout))


def properties(identity, interface):
    value = call(identity, 'call', 'org.freedesktop.DBus.Properties', 'GetAll', 's', interface)
    return value[0] if isinstance(value, list) else value


def snapshot(identity):
    result = {'identity': identity, 'trackId': '', 'status': 'unavailable', 'nextTrack': None}
    try:
        player = properties(identity, PLAYER)
        result['trackId'] = player.get('Metadata', {}).get('mpris:trackid', '')
        if player.get('Shuffle', False):
            return result
        tracks = properties(identity, TRACKS).get('Tracks', [])
        following = next_id(tracks, result['trackId'], False, player.get('LoopStatus', 'None'))
        if not following:
            result['status'] = 'empty' if result['trackId'] in tracks else 'unavailable'
            return result
        values = call(identity, 'call', TRACKS, 'GetTracksMetadata', 'ao', '1', following)
        entries = values[0] if isinstance(values, list) and len(values) == 1 and isinstance(values[0], list) else values
        result['nextTrack'] = metadata(entries[0]) if entries else None
        result['status'] = 'ready' if result['nextTrack'] else 'unavailable'
    except (OSError, subprocess.SubprocessError, ValueError, TypeError, KeyError, IndexError, AttributeError):
        pass
    return result


def main():
    identity = sys.argv[1] if len(sys.argv) > 1 else ''
    if not identity.startswith('org.mpris.MediaPlayer2.') or any(c.isspace() for c in identity):
        return
    monitor = None
    previous = None
    def publish():
        nonlocal previous
        value = snapshot(identity)
        if value != previous:
            print(json.dumps(value), flush=True)
            previous = value
    try:
        # Start with an optimistic snapshot, then refresh at monitor readiness.
        # Popen alone does NOT guarantee that match rules are installed yet.
        monitor = subprocess.Popen(['dbus-monitor', '--session',
            "type='signal',sender='" + identity + "',path='" + PATH + "'"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        publish()
        for line in monitor.stdout:
            if line.startswith('signal ') and any('member=' + name in line for name in (
                    'NameLost', 'PropertiesChanged', 'TrackListReplaced', 'TrackAdded', 'TrackRemoved', 'TrackMetadataChanged')):
                # dbus-monitor loses its unique name when BecomeMonitor completes;
                # this queued signal closes the initial GetAll/subscription gap.
                publish()
    except (OSError, BrokenPipeError, KeyboardInterrupt):
        pass
    finally:
        if monitor:
            monitor.terminate()
            try:
                monitor.wait(timeout=1)
            except subprocess.TimeoutExpired:
                monitor.kill()
                monitor.wait()


if __name__ == '__main__':
    import signal
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    main()
