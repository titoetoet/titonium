# Performance rules

Idle cost is an architecture property.

- Use native reactive models and signals before timers or command polling.
- Share one listener in a Service singleton when Bar, overlay and OSD need the same state.
- Keep heavy feature trees behind `Loader.active`; closing a transient surface releases its tree.
- Do not run infinite animations, shaders, `MultiEffect`, visualizers or render loops while hidden.
- Keep bar delegates bounded and avoid rebuilding models when a stable signature has not changed.
- Cache only derived values that are expensive and invalidated by a clear source signal.

A timer or subprocess requires a documented reason, bounded interval/lifetime and focused test.
Neither may live in UI. Measure a new module with the surface closed and open; investigate steady
RSS growth, wakeups or CPU regressions before visual polish.

Exclusive layer-shell focus is also observable state. `FocusArbiter` is the sole grant authority;
`FocusDiagnostics` records its effective acquire/release transitions and reports overlapping owners
for OverlayHost, Center, Settings and connected edge menus. It does not poll or mutate focus. The
protected acceptance gate runs the public Center → Spotlight → Settings path in an isolated shell,
requires each release before the following acquisition, and rejects conflict or missing-owner
diagnostics. Edge Menu remains covered by the pure arbiter regression because it has no safe public
IPC seam.

The current Neutral Utility baseline is opaque and solid. Compositor blur/glass is not part of the
skeleton and must not be introduced as an implicit dependency of a functional module.
