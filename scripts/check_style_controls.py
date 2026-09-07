#!/usr/bin/env python3
"""Run real style paint/control QML against inert runtime services."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='titonium-style-controls-') as temp:
    base = Path(temp)
    module = base / 'qs/Titonium'
    for folder in ('Shared', 'Theme', 'Services/Appearance'):
        shutil.copytree(ROOT / 'Titonium' / folder, module / folder)
    runtime = module / 'Core/Runtime'; runtime.mkdir(parents=True)
    (runtime/'qmldir').write_text('module qs.Titonium.Core.Runtime\nsingleton Preferences 1.0 Preferences.qml\nsingleton I18n 1.0 I18n.qml\n')
    (runtime/'Preferences.qml').write_text('''pragma Singleton
import QtQuick
QtObject { property var effectiveState: ({appearance:{themeId:"modern-flat",mode:"dark"},accessibility:{reducedMotion:true}})
 readonly property var settings: effectiveState
 readonly property var bar: ({height:44}) }
''')
    (runtime/'I18n.qml').write_text('''pragma Singleton
import QtQuick
QtObject { function tr(key, values) { return key; } }
''')
    runner=shutil.which('qmltestrunner') or '/usr/lib/qt6/bin/qmltestrunner'
    env={**os.environ,'QT_QPA_PLATFORM':os.environ.get('STYLE_QPA','offscreen'),'QT_QUICK_BACKEND':os.environ.get('STYLE_BACKEND','software')}
    if os.environ.get('STYLE_LINT') == '1':
        lint=shutil.which('qmllint') or '/usr/lib/qt6/bin/qmllint'
        files=[module/'Shared/StylePaint.qml',module/'Shared/StyleFocusRing.qml',*sorted((module/'Shared/styles').glob('*.qml'))]
        checked=subprocess.run([lint,'-I',str(base),*[str(f) for f in files]],capture_output=True,text=True,timeout=60)
        print(checked.stdout,end='');print(checked.stderr,end='')
        if checked.returncode: raise SystemExit(checked.returncode)
    result=subprocess.run([runner,'-input',str(ROOT/'scripts/fixtures'/globals().get('FIXTURE_NAME', 'style_controls')),'-import',str(base)],env=env,capture_output=True,text=True,timeout=90)
    print(result.stdout,end='');print(result.stderr,end='')
    if result.returncode or any(x in result.stdout+result.stderr for x in ['QWARN','TypeError','ReferenceError','Binding loop','Unable to assign']):
        raise SystemExit(result.returncode or 1)
