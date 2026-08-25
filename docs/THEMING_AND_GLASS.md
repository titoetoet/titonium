# Theming and glass

Theme packages contain semantic intent, not component-specific colors. Version 1 groups:

- colors: background, surface, text, border, accent and status roles;
- typography: UI and monospace families, sizes and weights;
- metrics: bar height, spacing and radii;
- motion: duration tokens and reduced-motion flag;
- materials: backend preference, opacity, tint and optical preset ID.

UI consumes `Theme.*`, `Typography.*`, `Metrics.*` and `Motion.*` only.

`MaterialSurface.backend` accepts `auto`, `native`, `qml` or `solid`. `auto` may select native
glass only when the capability adapter confirms that hyprglass is loaded and the layer
namespace is configured. Otherwise it selects the QML fallback; unsupported explicit native
selection also falls back safely and reports the resolved backend.

Milestone 0 uses a lightweight QML/solid material. Compositor synchronization arrives with
the Theme Center. It will use a generated integration file and a dedicated Platform adapter,
never `sed` against the main Hyprland source.

