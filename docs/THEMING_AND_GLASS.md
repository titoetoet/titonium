# Theme baseline

The skeleton uses a static **Neutral Utility** token layer:

- `Theme/Theme.qml`: semantic light/dark colors;
- `Theme/Typography.qml`: SF Pro Display with Noto Sans fallback;
- `Theme/Metrics.qml`: 4/8 grid, 44px bar, 36px controls and small radii;
- `Theme/Motion.qml`: short durations with reduced-motion collapse;
- `Shared/*`: thin controls that consume only semantic tokens.

It is solid, opaque and compositor-independent. There is no theme catalog, material resolver,
glass backend, shader, blur or `hyprland.lua` synchronization in the current runtime.

Future repository research may evaluate matugen or a simple `colors.json` input. The accepted
design must keep semantic token names stable, load data once, validate/fallback safely and avoid
forcing any functional module to import a theme provider directly.

Hybrid glass remains a possible future appearance module, not a skeleton capability. If revived,
hyprglass must be treated as optional and version-sensitive, with a solid fallback and zero source
mutation or automatic compositor reload. Theme work never reads, edits or reloads either Hyprland
configuration file.
