# Compact Media Refinement Implementation Plan

> **For agentic workers:** Use executing-plans to implement these bounded tasks.

**Goal:** Four real frequency bands in Primary, three in Satellite, clean bounded titles and title-only shimmer.
**Architecture:** Separate optional spectrum capture from the native Audio control service. Keep metadata cleanup pure and Compact-only; isolate title drawing and motion in one view.
**Tech Stack:** QML/Canvas, JavaScript, Python standard-library FFT, installed PulseAudio monitor capture.
**Spec:** User's technical specification in this task, superseding five colored bars and full raw titles.

## Constraints

Connected retains the notch. No microphone capture for analysis, no raw audio persistence.
Paused/unavailable media and Reduced Motion are still. Title width capped at 200 logical pixels.
Shimmer is only on the Primary track title, 1800ms; hover/focus alone enables overflow scrolling.

## Tasks

- [x] Pure title cleanup: failing examples for delimiter suffixes, bracketed release tags,
  meaningful parentheses, Unicode titles and empty input; implement MediaTitleRules.clean.
- [x] Spectrum: known-tone tests at 80/600/3000/9000Hz plus silence; implement four-band
  FFT over the output monitor, fail closed to zero levels, terminate child on shutdown.
  Introduce a singleton MediaSpectrumService, enabled only by visible playing media.
- [x] Visualizer: four/three bars, 3–14px, width 3px, gap 2px, muted monochrome,
  centered damped transitions. Satellite merges mid/high-mid bands.
- [x] Title view: Canvas glyph-masked light sweep, trailing alpha fade, fixed position
  while resting, hover/focus scrolling with reset on leave, reduced-motion disable.
  Test bounded width, static resting text and scrolling lifecycle through actual Qt view.
- [x] Integration: wire the spectrum demand and Compact-only title cleanup; update
  tests and docs. Run full check, isolated smoke/protected gates and live visual review (deferred: session locked, monitors off).
