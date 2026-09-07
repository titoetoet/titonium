# Glass backend spike — 2026-09-06

## Verdict and integration decision

**fallback-only for release acceptance.** A configuration-free, per-surface **native blur candidate is available**, and its installed QML API loaded in an isolated fixture. Actual blur, Connected mask/morph fidelity and performance have not been visually verified: native screenshots never completed. Liquid Glass refraction is unavailable (no plugin loaded), and upstream HyprGlass does not establish arbitrary Connected-edge optical geometry merely by supporting alpha clipping.

Proceed with QML style paint and readable fallback. A production capability must remain `{level: "none", available: false, reason: "native-backdrop-unverified", revision: "hyprland-0.56.2"}` until the rendering gate succeeds. Do not claim `blur-only` from source inspection, successful QML loading, or global blur enablement alone. Do not add compositor commands to a style or install a plugin.

## Verified local environment

Read-only commands on the host (the restricted sandbox could not reach the compositor socket):

- `hyprctl version`: Hyprland **0.56.2**, commit **efb50993780079460b0cbed1363e2166a2de1d9f**, ABI `efb50993780079460b0cbed1363e2166a2de1d9f_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6`.
- `hyprctl plugin list`: **no plugins loaded**.
- `pkg-config --modversion Qt6Core`: **6.11.2** (`qtpaths6` absent).
- `hyprctl getoption decoration:blur:enabled`: `bool: true`, `set: true`.
- `hyprctl configerrors`: empty output.
- `hyprctl layers -j`: DP-1 has `titonium-menubar`, `titonium-center-overlay`, `titonium-edge-menu`, `titonium-dock`, all resident PID 76657. DP-3 has only `hyprpaper`. Settings/popups were not opened, so additional namespaces remain uninventoried.

No config was edited/reloaded, no wallpaper changed, no user application launched, and no plugin was built/installed/loaded. Temporary QA layers had empty input masks, no exclusive zone, and were restricted to DP-1.

## Pinned source and license inventory

Source-only downloads remained in `/tmp/titonium-glass-spike-*`; no third-party implementation was imported into production.

- [HyprGlass discovery revision](https://github.com/hyprnux/hyprglass/tree/725383e86a2a79457a81cdbc2ceb33c07363bd8d): `725383e86a2a79457a81cdbc2ceb33c07363bd8d`, resolved from cloned repository metadata. `.hyprland-version` is `0.56.2`.
- Its [hyprpm.toml](https://github.com/hyprnux/hyprglass/blob/725383e86a2a79457a81cdbc2ceb33c07363bd8d/hyprpm.toml) maps the installed Hyprland commit to **77636c5711ed572ca199a84d06146ccac0951786** (v0.8.0). That exact revision was fetched and inspected separately; candidate dependency should use this release pin, not moving HEAD.
- [License at candidate pin](https://github.com/hyprnux/hyprglass/blob/77636c5711ed572ca199a84d06146ccac0951786/LICENSE): **BSD-3-Clause**, copyright 2025 Jeremy Trufier. Future adaptations must retain copyright, conditions and disclaimer, with binary redistribution notices where applicable. No code copied in this change.
- [Hyprland source matching installed runtime](https://github.com/hyprwm/Hyprland/tree/efb50993780079460b0cbed1363e2166a2de1d9f): tag clone resolved to the exact installed commit. Source audit only.

All HyprGlass references below use candidate pin **77636c5711ed572ca199a84d06146ccac0951786**. Exact files/patterns inspected:

| File | Audited implementation |
| --- | --- |
| `.hyprland-version`, `hyprpm.toml`, `LICENSE` | Target version, release mapping and license above |
| `src/PluginConfig.cpp:44-62,122-125,592-651` | global enable and window blur management default on; layer enable default off; Lua `hyprglass.layer(namespace, options)` accepts `exclude`, `preset`, `mask_threshold`, `live_resample`, `mask_mode`; pending entries committed into namespace sets/maps |
| `src/main.cpp:238-252,307-367` | `shouldGlassLayer` matches exact namespace; exclusion wins; empty inclusion set means **all namespaces**; `renderLayer` installs pre/post render passes; no output predicate in namespace matching |
| `src/main.cpp:375-386,510-554` | ABI comparison uses library suffix after `_aq_`, not commit equality; init calls `HyprlandAPI::reloadConfig()`; exit removes passes/hooks/decorations and frees state |
| `src/GlassLayerSurface.cpp:76-105,188-286,288-396` | `auto` chooses protocol region when present, else rendered-alpha threshold; explicit empty protocol region yields no effect; pre-surface sampling and temporary FBO; region list over capacity falls back to extents |
| `src/GlassLayerCompositeElement.cpp:13-32` | composites and restores framebuffer; monitor-relative bounds |
| `src/GlassRenderer.cpp:159-240` | backdrop and layer texture samplers, UV transform, mask uniforms and region uniforms |
| `src/LayerGeometry.hpp:11-24` | animated surface rectangle translated by monitor position and scaled; no arbitrary path-distance field |
| `src/Shaders.hpp:119-165,285-300` | alpha/region mask discards pixels; `getCornerSDF(uv)` and `refractionDir(uv)` still determine optical edge and direction; sharp surface pixels composed above refracted background |

Version pin agreement is **not binary ABI validation**. Nothing was compiled or loaded, and the permissive ABI suffix comparison does not prove hook safety. Loading this upstream plugin itself reloads compositor configuration and therefore violates this task's constraints.

## Configuration-free native blur API

The installed `/usr/lib/qt6/qml/Quickshell/Wayland/qmldir` reexports `Quickshell.Wayland._BackgroundEffect`. Its `quickshell-wayland-background-effect.qmltypes` exports attached **BackgroundEffect**, with writable `blurRegion: PendingRegion*`. This is a real installed API, and the fixture loaded it without errors after an initial syntax correction.

Hyprland source at the exact installed commit:

- `src/render/Renderer.cpp:3295-3308`, `IHyprRenderer::shouldBlur(PHLLS)`: global blur must already be enabled; an attached background effect takes precedence over the layer rule, and its empty region disables blur.
- `src/protocols/BackgroundEffect.cpp:25-80`: region changes commit with the surface. Destroying the effect clears protocol state on the next surface commit, which restores ordinary rule-based behavior. **Destroy is not equivalent to force-disable.**
- `src/render/OpenGL.cpp:2015-2110`: native blur uses texture stencil and intersects protocol region. The stencil's alpha discard settings still matter; a rectangular region is not proof that transparent shoulders are excluded.

Minimal API exercised in a native `PanelWindow` (candidate, not acceptance-approved integration):

```qml
import Quickshell
import Quickshell.Wayland

// Inside the existing native host, keeping its lifecycle and geometry intact:
BackgroundEffect.blurRegion: Region {
    width: requestBlur ? host.width : 0
    height: requestBlur ? host.height : 0
}
```

`requestBlur` must require the validated capability and supported glass style. Material/Flat/Neumorphism must retain an **explicit empty region**; do not remove the attached effect on each style change, since removal can reactivate an external layer blur rule. Scope follows the actual owned `wl_surface`, so no namespace-wide or output-global mutation is necessary. On destruction the client-owned effect goes away with the surface; on candidate cancellation the existing host must restore the previous region in the same generation as paint. Owner loss does not leave a global compositor option changed.

`Region` supports rectangles, rounded corners and region composition, not an arbitrary QML Shape alpha mask. `Region { item: connectedItem }` must not be advertised as extracting the Connected path. Its item bounds alone do not prove exact silhouette clipping. For a full-screen Center/Edge host, applying a host-sized blur region could blur outside the silhouette: reject until captured evidence proves clipping or a region derived from the existing geometry is supplied without changing input masks/path ownership.

The alternative layer-rule API is also real but less suitable: `hl.layer_rule({...})` returns a rule object with `set_enabled(bool)` and `is_enabled()` (`src/config/lua/objects/LuaLayerRule.cpp:32-67`). Hyprland 0.56.2 Lua config uses `hyprctl eval`; `keyword` explicitly rejects non-legacy parsers (`src/debug/HyprCtl.cpp:1163`). Namespace rules do not provide the required stable per-owned-surface/output lease. No trial lease was implemented, and no old `layerrule` command was attempted.

## Native QA and artifact record

Throwaway fixture: `/tmp/titonium-glass-spike-fixture/shell.qml`. Companion `ConnectedPillShape.qml` copies the exact existing path commands into the fixture, substituting fixed material values only. Two test layer surfaces rendered a moving black/white stripe pattern behind a plain rectangle and Connected path. The test panel had phases for requested blur, explicit empty region, and opaque paint, then an 18-second exit timer. No focus/input was requested; namespaces were `titonium-glass-spike-background` and `titonium-glass-spike-panel` on DP-1. Resident shell remained separate.

Evidence:

- `runtime.log`: `Configuration Loaded`; no BackgroundEffect property/import errors. Initial attempt had an invalid semicolon after `Region {}`; corrected before API load succeeded.
- Native raster/video artifacts: **none**. `grim -o DP-1` stalled. All identified test capture processes/runners were terminated. A final bounded `timeout 5s env WAYLAND_DEBUG=1 grim ...` showed successful `ext_image_copy_capture` negotiation, 3840×2160 buffer, damage and transform events, but no frame-ready completion. Log: `/tmp/titonium-glass-spike-fixture/grim-wayland.log`.
- Cleanup: `/tmp/titonium-glass-spike-fixture/layers-after.json` has no test namespace; `quickshell list --all` returned only resident PID 76657. DP-3 remained wallpaper-only. Version/plugin records saved alongside this file.
- Blur/moving-background fidelity, text sharpness, Connected morph/halo/seam, Flat disable rendering, cancel/owner-loss visual restore: **unverified**, not passed.
- Performance baseline, GPU/frame-time, 30-second idle and 20-cycle resource recovery: **not measured**. No numeric budget claim is made. The fixture's intentional moving stripe animation is test stimulus, not production polling.

## Setup ownership and remaining gate

Native blur needs no package install or config mutation on this machine. The next step is an operator-visible or working capture-assisted run of the bounded fixture, followed by exact Connected morph and full-screen transparent-area checks. The capture completion failure must first be diagnosed without changing global compositor state. Ordinary rectangle success would not authorize Connected blur automatically.

HyprGlass setup is a separate user/compositor-owner decision. Do not provide a paste-and-run install recipe as though compatibility and scope are proven. Before any load: build the exact release pin against matching headers in isolation, audit window behavior and output scoping, account for init's forced config reload, establish selective disable/restore ownership, and obtain native refraction/mask/performance evidence. Existing upstream namespace filtering and rectangular edge optics do not meet the Connected/output-scoped integration contract. Plugin-loss should immediately keep the selected Liquid style but lower runtime capability to none and use readable fallback.

A future blur-only verdict permits Glassmorphism native fidelity only after its actual rendered and cleanup checks pass. Liquid Glass remains backend-limited even then. Full `native-ready` remains blocked on real scene refraction, shape-correct optics, scope, rollback and performance evidence.

## Minimal host integration checks before promotion

The installed BackgroundEffect QML type exposes `blurRegion` and lifecycle methods/signals, but **no `supported` or `available` property**. Do not invent a `BackgroundEffect.supported` check. QML import/property availability proves the binding exists, not that the active compositor will blur. A capability service would need a separately validated environment result; avoid rendering a green native-available status merely because the import succeeds. The capture hang is an environment evidence limit, not proof that blur itself failed.

If implementing an explicitly experimental request path before visual promotion, retain the documented readable fallback (opacity at least .85), report rendering unverified, and do not expose it as full native fidelity. At minimum verify:

1. Existing host remains the same object across style/trial transitions; geometry, focus, input mask and exclusive zone do not change.
2. Glass requests region only on its owned surface; Material/Flat/Neumorphism hold the same attached effect with an empty region, including Cancel/timeout/save-failure paths.
3. Host teardown destroys only its own effect; dynamic output changes neither create a DP-3 fixture nor apply namespace/global rules.
4. Legacy styles and unsupported imports remain readable and do not reset the persisted style selection.
5. Rendered follow-up: moving background blur and sharp foreground, exact Connected morph silhouette and transparent full-screen areas, then empty-region disable/rollback and resource/performance budgets. Without this last check capability stays unverified.
