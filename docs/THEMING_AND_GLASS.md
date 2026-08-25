# Theming

Theme packages contain semantic intent, not component-specific colors. Version 2 groups:

- colors: background, surface, text, border, accent and status roles;
- typography: UI and monospace families, sizes and weights;
- metrics: bar height, spacing and radii;
- motion: duration tokens and reduced-motion flag;
- material policy: default/allowed backends, opacity and compositor capability.

UI consumes `Theme.*`, `Typography.*`, `Metrics.*` and `Motion.*` only.

Reusable visual primitives live in `Titonium.Design.Controls`. `TextLabel` resolves a named
typography variant and semantic tone, `Icon` renders the shipped Material Symbols variable
font, and `Button` owns pointer, keyboard, focus, disabled, selected and checked states. Feature
modules consume these contracts instead of restyling raw `Text` and `Rectangle` controls.

Container hierarchy is equally semantic: `Surface` selects a tonal role and owns the material
backend, `Card` adds optional pointer/keyboard interaction, and `Panel` provides the larger
popup/section radius and padding. Cards and panels compose arbitrary child content; they do not
import module state or own a Wayland window. `MaterialSurface` remains an internal renderer,
not a feature-level component.

Input controls remain state-only: `Switch` exposes checked/toggled, `Slider` exposes a bounded
range with moved/committed signals, and `Dropdown` resolves data through text/value roles while
lazy-loading its option list. They never persist settings themselves. A module model or
`ConfigStore` transaction owns the value and decides what to do with emitted changes.

`Tabs` follows the same data-only rule: a model supplies label/icon/value roles and the control
emits the selected index/value. It is one keyboard tab stop; arrow keys wrap through pages while
Home/End select the first/last page. The tab list and each page tab publish native accessibility
roles. Interactive controls must expose an accessible name, role and focusability; disabled
controls are removed from the Tab chain.

`titonium-neutral` is the immutable restore baseline. It uses opaque tonal surfaces, one-pixel
borders, a 4/8px grid and no gradients, shadows, shaders, glass or compositor integration.
Its material policy allows only `solid`; unsupported backend requests resolve to the package
default.

`titonium-hybrid-glass` is the first compatible material package. Its `auto` backend resolves
in this order: loaded native hyprglass capability, static QML optical fallback, then solid.
The QML renderer uses only translucent tonal geometry, a border and a one-pixel static
specular highlight. It does not allocate blur, a shader, `MultiEffect`, an animation or a render
loop. This fallback suggests glass but cannot sample/blur content behind the layer.

Native capability discovery is a single `hyprctl plugin list` call owned by the Platform layer.
It never retries, loads a plugin or changes compositor state. Selecting `native` while the
capability is unavailable resolves to QML safely. Actual hyprglass layer behavior remains
version-sensitive and externally configured; Titonium treats it as an optional enhancement.

The Material page appears only for a non-default package allowing QML/native backends. It edits
semantic policy values in the same preview transaction as all other Settings pages. Switching
back to Neutral removes the page and forces solid rendering regardless of old material overrides.

The theme catalog is data-only and never references QML components. Theme selection, preview,
Apply, Cancel and Restore Default never read, edit or reload `hyprland.lua`.

Future packages recorded for later review are `titonium-cupertino-flat` and
`titonium-fluent-solid`.
