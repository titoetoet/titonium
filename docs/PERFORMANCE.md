# Performance policy

- No infinite animation may run while its visual is hidden or inactive.
- No periodic poller may run without at least one registered consumer.
- Use Quickshell/Qt service signals and compositor events before spawning commands.
- Hidden overlay content must not exist: use `Loader.active`, not only `visible: false`.
- Do not enable `layer.enabled` or `MultiEffect` on hidden surfaces.
- Prefer one expensive material pass per visible surface over effects on every child card.
- MenuBar idle state must not contain a frame-driven animation.
- Multi-monitor surfaces may duplicate lightweight hosts, not heavy feature trees.
- Cache immutable parsing/results; update QML models incrementally to preserve delegates.
- Workspaces and active-window state subscribe to compositor models; Input Method subscribes to
  the existing Fcitx StatusNotifier item. None of these MenuBar widgets owns a timer or process.
- Clock uses one shared `SystemClock.Minutes`; seconds precision is forbidden. Calendar and its
  42 lunar conversions exist only while the transient OverlayHost Loader is active.
- Spotlight instantiates at most one fixed 5×4 page of 20 application tiles. Its Grid↔Results
  entry transition is bounded to 220 ms, resolves to zero under reduced motion and never retains
  an outgoing Loader item. Search/category/grid and Clipboard branches are Loader-owned. Density
  indicators reuse page counts and do not introduce polling; the global visibility projection is
  signal-driven and does not rediscover desktop entries.
- Arch Menu confirmation is a replacement Loader surface, not a nested retained tree. It has no
  timer, animation loop or process; only the Platform session adapter may execute an action after
  an explicit confirmation gesture.
- Settings Center is Loader-owned; only its selected page exists. Theme and Typography pages
  have no poller, effect layer or compositor integration, and live preview is signal-driven.
- Frame owns zero surfaces while disabled. Its enabled path uses one Rectangle per output with an
  empty input region; Canvas, shader, animation and timer-based repaint are prohibited.

Performance review is part of module acceptance. Document every always-on timer with its
reason and interval; absence of a reason is a defect.
