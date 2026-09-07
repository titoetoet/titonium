# Bar interaction feedback

The Connected and Classic silhouettes, fills and theme material are unchanged.
`Shared.InteractionFeedback` is a presentation-only overlay with no input ownership:

- Idle is transparent; hover fades an internal radial light over `Motion.normal` (160ms).
- Press replaces the light with a subtle flat fill, without scaling or translating controls.
- Persistent selection uses a short accent mark. Warning uses a semantic warning mark;
  neither disappears when a pointer presses the control. Workspace urgency and unread badges remain.
- Keyboard focus has an independent focus outline. Reduced Motion removes transition duration.
- Existing popup coordinators remain the source of active state in both bar styles.

The overlay is used by connectivity, pin, notification history, application, input method,
workspace and compact Center controls. Noninteractive branding and mascot animation are unchanged.
The regular Shared.Button appearance is unchanged unless `barFeedback` is enabled.

The implementation is original QML using Qt Quick Shapes `RadialGradient` and `PathRectangle`;
no external shell implementation or theme code was copied. API reference:
https://doc.qt.io/qt-6/qml-qtquick-shapes-radialgradient.html

Validation includes the state matrix (`scripts/check_interaction_feedback.js`), the real QML
component's fixed geometry/disabled state in the isolated compact UI fixture, and existing
Connected/Classic popup, routing and protected interaction tests. When a resident shell prevents
`qs -n` test startup, run live acceptance from a separate temporary copy rather than stopping it.

Window focus borders are compositor configuration, not a shell service: the dotfiles dark/light
profiles use a fixed 2px border and distinct active/inactive colors. The live Hyprland config was
updated only at its three corresponding values, with a timestamped backup alongside the original.
No focus-follows-mouse policy, window rounding, opacity, shadow or key bindings were changed.
