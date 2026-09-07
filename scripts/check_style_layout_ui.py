#!/usr/bin/env python3
"""Real Connected/Classic geometry, focus and 40 rendered style combinations."""
import os
from pathlib import Path
import runpy
import shutil
ROOT=Path(__file__).resolve().parents[1]
previous=os.environ.get('QT_SCALE_FACTOR')
try:
    for scale in ('1','1.5'):
        os.environ['QT_SCALE_FACTOR']=scale
        runpy.run_path(str(ROOT/'scripts/check_style_controls.py'),init_globals={'FIXTURE_NAME':'style_layout'})
        out=Path('/tmp/titonium-style-matrix')/('scale-'+scale)
        out.mkdir(parents=True,exist_ok=True)
        captures=list(Path('/tmp').glob('titonium-style-layout-*.png'))
        assert len(captures)==20, f'expected 20 layout captures, got {len(captures)}'
        for p in captures: shutil.move(str(p),str(out/p.name))
        print('PASS 20 layout/mode/style combinations at scale',scale)
finally:
    if previous is None: os.environ.pop('QT_SCALE_FACTOR',None)
    else: os.environ['QT_SCALE_FACTOR']=previous
