# Legacy audit

The legacy shell successfully reaches `Configuration Loaded`, but its architecture has drifted
from its documentation.

Observed strengths:

- clear directory intent (`core`, `drivers`, `ui`, `features`, `windows`);
- semantic tokens and one shared surface primitive;
- multi-monitor layer surfaces and click-through masks;
- partial ref-counted polling and useful handoff documentation.

Observed constraints motivating the rewrite:

- 16,902 QML/JSON lines with several 800–1,300 line files;
- `ShellState` combines navigation, settings, persistence, theme catalog, IPC and Hyprland;
- adding a setting requires synchronized edits across ten locations;
- MenuBar popup management names every widget instance;
- Settings instantiates every tab and heavy preview on every screen;
- hardcoded strings/colors bypass documented i18n/theme rules;
- UI contains direct processes and system actions;
- `qmllint` finds a duplicate ID, a missing `cycleVisualizerMode` member and many layout/type
  warnings;
- hyprpm marks hyprglass enabled, while the active compositor currently reports no loaded
  plugins.

The audit is evidence only. Do not copy legacy implementation into the new repository.

