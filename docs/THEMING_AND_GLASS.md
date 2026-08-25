# Theming

Theme packages contain semantic intent, not component-specific colors. Version 2 groups:

- colors: background, surface, text, border, accent and status roles;
- typography: UI and monospace families, sizes and weights;
- metrics: bar height, spacing and radii;
- motion: duration tokens and reduced-motion flag;
- material policy: default/allowed backends, opacity and compositor capability.

UI consumes `Theme.*`, `Typography.*`, `Metrics.*` and `Motion.*` only.

`titonium-neutral` is the immutable restore baseline. It uses opaque tonal surfaces, one-pixel
borders, a 4/8px grid and no gradients, shadows, shaders, glass or compositor integration.
Its material policy allows only `solid`; unsupported backend requests resolve to the package
default.

The theme catalog is data-only and never references QML components. Future compositor-aware
themes require a dedicated Platform capability and explicit acceptance; theme selection and
Restore Default never read, edit or reload `hyprland.lua`.

Future packages recorded for later review are `titonium-cupertino-flat` and
`titonium-fluent-solid`.
