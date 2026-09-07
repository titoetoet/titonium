"""Four-band output-monitor spectrum. PCM stays in memory and is never persisted."""
import cmath
import ctypes
import json
import math
import os
import signal
import struct
import subprocess
import sys

SIZE = 1024
RATE = 24000
EDGES = (20, 160, 2000, 6000, 12000)
WINDOW = [0.5 - 0.5 * math.cos(2 * math.pi * i / (SIZE - 1)) for i in range(SIZE)]


def spectrum_frame(samples):
    if len(samples) != SIZE or any(not math.isfinite(v) for v in samples):
        return {"bands": [0.0] * 4, "spectrum": [0.0] * 24}
    values = [complex(v * w) for v, w in zip(samples, WINDOW)]
    j = 0
    for i in range(1, SIZE):
        bit = SIZE >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j ^= bit
        if i < j:
            values[i], values[j] = values[j], values[i]
    length = 2
    while length <= SIZE:
        step = cmath.exp(-2j * math.pi / length)
        for start in range(0, SIZE, length):
            twiddle = 1
            for k in range(start, start + length // 2):
                left = values[k]
                right = values[k + length // 2] * twiddle
                values[k], values[k + length // 2] = left + right, left - right
                twiddle *= step
        length *= 2
    def aggregate(edges):
        power = [0.0] * (len(edges) - 1)
        for k in range(1, SIZE // 2):
            hz = k * RATE / SIZE
            for band in range(len(power)):
                if edges[band] <= hz < edges[band + 1]:
                    power[band] += abs(values[k]) ** 2
                    break
        return [round(max(0.0, min(1.0, (20 * math.log10(max(1e-12,
            math.sqrt(v) * 2 / SIZE)) + 60) / 54)), 4) for v in power]
    # Both views share the SAME FFT and output-monitor listener.
    detailed_edges = [40 * (12000 / 40) ** (i / 24) for i in range(25)]
    return {"bands": aggregate(EDGES), "spectrum": aggregate(detailed_edges)}


def bands(samples):
    return spectrum_frame(samples)["bands"]


def capture_command(monitor):
    if not monitor or not monitor.endswith('.monitor'):
        raise ValueError('An explicit output monitor is required')
    return ['parec', '--device=' + monitor, '--raw', '--format=float32le',
            '--rate=24000', '--channels=1', '--latency-msec=50',
            '--client-name=Titonium Spectrum', '--stream-name=Titonium Spectrum',
            '--property=media.category=Monitor', '--property=stream.monitor=true']


def terminate_on_parent_exit():
    parent = os.getppid()
    ctypes.CDLL(None).prctl(1, signal.SIGTERM)
    if os.getppid() != parent:
        os._exit(1)


def stop(signum, frame):
    raise SystemExit(0)


def main():
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    child = None
    try:
        child = subprocess.Popen(capture_command(sys.argv[1]), stdout=subprocess.PIPE,
                                 stderr=subprocess.DEVNULL, preexec_fn=terminate_on_parent_exit)
        while True:
            frame = child.stdout.read(SIZE * 4)
            if len(frame) != SIZE * 4:
                break
            print(json.dumps(spectrum_frame(struct.unpack('<1024f', frame))), flush=True)
    except (OSError, ValueError, IndexError, BrokenPipeError):
        pass
    finally:
        if child is not None:
            child.terminate()
            try:
                child.wait(timeout=1)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()


if __name__ == '__main__':
    main()
