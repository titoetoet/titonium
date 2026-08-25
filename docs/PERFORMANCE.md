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

Performance review is part of module acceptance. Document every always-on timer with its
reason and interval; absence of a reason is a defect.
