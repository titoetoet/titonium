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

The current Neutral Utility baseline is opaque and solid. Compositor blur/glass is not part of the
skeleton and must not be introduced as an implicit dependency of a functional module.
