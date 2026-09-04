# Control-Anchored Edge Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Draw each application menu as a single downward extrusion from the clicked control inside its existing Top Bar pill.

**Architecture:** One screen-local `EdgeMenuWindow` renders both compact edge pills and selects the active source edge. Each pill uses one `AnchoredMenuPillShape` whose path is the union of the unchanged horizontal pill and an animated menu branch. `StartIsland` and `EndIsland` expose source-control geometry; projected DBusMenu content is clipped inside the branch.

**Tech Stack:** QML/Qt Quick Shapes, Quickshell Wayland layer-shell, JavaScript geometry rules, Node/Python static contracts.

**Spec:** `docs/superpowers/specs/2026-09-03-right-pill-connected-menu-design.md`

## Global Constraints

- The Top Bar pill remains visible and stationary while its menu opens.
- Exactly one `ShapePath` draws each pill and its active branch.
- Active Window/ChatGPT opens from its segment in the left pill; Input Method opens from its segment in the right pill.
- No connector item, filler, header, nested panel or detached popup.
- Menu width is 420dp; adaptive height is capped at 440dp and available output height.
- Open/close remain reversible at 240ms/190ms; Reduced Motion commits immediately.

---

### Task 1: Pure branch geometry

**Files:**
- Create: `Titonium/Bar/right/EdgeMenuGeometry.js`
- Create: `scripts/check_edge_menu_geometry.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Produces: `branchRect(edge, sourceX, sourceWidth, compactWidth, outputWidth, menuWidth, menuHeight, progress)`.
- Produces: `chassisRect(edge, compactWidth, branchRect)`.

- [ ] Write fixtures for left alignment, right alignment, 12dp output clamping, zero/open progress and adaptive height.
- [ ] Run `node scripts/check_edge_menu_geometry.js` and confirm it fails because the module is absent.
- [ ] Implement finite-number normalization, clamp helpers and immutable returned rectangles.
- [ ] Register the test in `scripts/check.sh` and verify it passes.

### Task 2: Publish source-control geometry

**Files:**
- Modify: `Titonium/Bar/islands/StartIsland.qml`
- Modify: `Titonium/Bar/islands/ActiveWindowPill.qml`
- Modify: `Titonium/Bar/islands/EndIsland.qml`
- Modify: `Titonium/Bar/islands/StatusPill.qml`
- Modify: `Titonium/Bar/widgets/InputMethod.qml`
- Modify: `scripts/check_right_pill.js`

**Interfaces:**
- Produces: `StartIsland.menuAnchorX/menuAnchorWidth` from the Active Window segment.
- Produces: `EndIsland.menuAnchorX/menuAnchorWidth` from Input Method.
- Consumes: coordinator intents with source edge and anchor geometry.

- [ ] Add failing contracts requiring anchors to derive from named child items rather than constants.
- [ ] Expose read-only local geometry through each presentation boundary.
- [ ] Pass anchor values with `toggleApp` and `toggleInput`.
- [ ] Verify both source-routing contracts pass.

### Task 3: One union shape path

**Files:**
- Create: `Titonium/Shared/AnchoredMenuPillShape.qml`
- Modify: `Titonium/Shared/qmldir`
- Modify: `scripts/check_right_pill.js`

**Interfaces:**
- Consumes: compact pill edge/body geometry and animated branch rectangle.
- Produces: one opaque union silhouette with one `Shape` and one `ShapePath`.

- [ ] Add a failing static contract requiring exactly one path and forbidding nested rectangles, fillers and connector items.
- [ ] Implement a clockwise non-intersecting outline with rounded branch corners and the existing inward shoulder.
- [ ] Verify left/right fixtures and static ownership contracts.

### Task 4: Replace edge-wide morph with anchored extrusion

**Files:**
- Create: `Titonium/Bar/right/EdgeMenuWindow.qml`
- Create: `Titonium/Bar/right/EdgeMenuSurface.qml`
- Modify: `Titonium/Bar/right/RightPillCoordinator.qml`
- Modify: `Titonium/Bar/right/qmldir`
- Modify: `Titonium/Bar/BarHost.qml`
- Delete: `Titonium/Bar/right/LeftPillWindow.qml`
- Delete: `Titonium/Bar/right/LeftPillSurface.qml`
- Delete: `Titonium/Bar/right/RightPillWindow.qml`
- Delete: `Titonium/Bar/right/RightPillSurface.qml`

**Interfaces:**
- Coordinator stores normalized source anchor and one reversible progress.
- Surface keeps both compact pills fully visible and places `SystemTrayMenuView` only in the active branch.

- [ ] Add failing contracts for one owner window, stationary compact geometry and branch-only clipping.
- [ ] Implement the single window and surface using `EdgeMenuGeometry` and `AnchoredMenuPillShape`.
- [ ] Preserve Escape, outside click, monitor-change close and exact compact/menu/dismissing masks.
- [ ] Remove the superseded four edge-wide owner files and exports.
- [ ] Run targeted Bar, Right Pill and SystemTray tests.

### Task 5: Acceptance, documentation and verification

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/THEMING_AND_GLASS.md`
- Modify: `docs/TESTING.md`
- Modify: `scripts/check_right_pill.js`

- [ ] Require that app/input anchors select left/right branches and the opposite pill has zero branch progress.
- [ ] Require one path per edge and no legacy detached/edge-wide menu owner.
- [ ] Document the stationary Top Bar plus control-origin extrusion motion.
- [ ] Run `git diff --check`, targeted contracts and `./scripts/check.sh`.
