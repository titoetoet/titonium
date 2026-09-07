#!/usr/bin/env python3
"""Check candidate paint isolation and frozen legacy popup presentation."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name("check_style_controls.py")), init_globals={"FIXTURE_NAME":"style_integration"})
