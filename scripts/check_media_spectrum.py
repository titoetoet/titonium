#!/usr/bin/env python3
import importlib.util
import math
from pathlib import Path
spec=importlib.util.spec_from_file_location('spectrum',Path(__file__).resolve().parents[1]/'Titonium/Services/MediaSpectrum/spectrum.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
assert m.bands([0.0]*1024)==[0.0]*4
for band,frequency in enumerate([80,600,3000,9000]):
    samples=[.2*math.sin(2*math.pi*frequency*i/24000) for i in range(1024)]
    values=m.bands(samples)
    assert values[band]>.5,(frequency,values)
    assert all(values[band]>v+.15 for j,v in enumerate(values) if j!=band),(frequency,values)
assert m.bands([float('nan')]*1024)==[0.0]*4
try:
    m.capture_command('alsa_input.microphone')
    raise AssertionError('must never fall back to microphone capture')
except ValueError:
    pass
assert '--device=output.monitor' in m.capture_command('output.monitor')
print('PASS actual frequency bands, finite output and silence')
assert hasattr(m, 'spectrum_frame'), 'Music needs measured detailed spectrum, not repeated four-band decoration'
assert m.spectrum_frame([0.0]*1024)['spectrum'] == [0.0]*24
frame=m.spectrum_frame([.2*math.sin(2*math.pi*3000*i/24000) for i in range(1024)])
assert frame['bands'][2] > .5
assert len(frame['spectrum']) == 24 and max(frame['spectrum']) > .5
assert all(math.isfinite(v) and 0 <= v <= 1 for v in frame['spectrum'])
assert m.spectrum_frame([float('nan')]*1024)['spectrum'] == [0.0]*24
print('PASS detailed 24-band spectrum shares measured PCM and silence behavior')
