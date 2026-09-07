# Pixel Stage Dog

View-only mascot for `modules.bar.mascot = "dog"`. `BarPage` uses the existing Preferences preview/Apply/Cancel transaction. The component is loaded only while the idle mascot is visible. It owns no native service, persistence, click action or input mask.

Local source: `/home/cole/Projects/Mascot/mascots/dog`, metadata Puppy 1.0.0, author Titonium Team. No Git revision or license file is present in that local source. The front/back PNG frames, bone and heart are reused; no third-party repository was introduced. The original unused sprite and curtain bitmaps are not shipped here. The source component in Mascot and this copy differ only in the relative assets URL.

The 12-second cycle approaches for 2.2 seconds, stays at the rim for 6 seconds, turns for 0.4 seconds, retreats for 2.2 seconds and waits inside. Hovering the central dog region queues one of wave/feed/pet, avoiding the previous choice. An approach/retreat completes before a queued reaction; reactions last 2.1 seconds and finish even if the pointer leaves. Holding hover does not repeat. The host still owns click-to-open Center. The canonical showcase API remains available (`peekHovered`, `walkState`, `autoWalkLoop`, loop toggle and all five action buttons); bark and curtain controls are not part of automatic hover selection.

A single frame clock drives the active view. Reduced Motion resets to a static front pose; unloading releases all animation. The bitmap crop omits the original baked-in floor and edge fragments; separate paws extend four scaled logical pixels below the pill. Curtains are compact QML shapes. Six two-color stars have offset brightness phases.

Validation: `node scripts/check_preferences.js`, `python3 scripts/check_center_compact_ui.py`, and the normal `scripts/check.sh` gate. The Qt fixture uses real pointer events and covers selection/unload, repeat suppression, different next reaction, click routing, Reduced Motion, approach/turn/retreat and clipping at Bar heights 40/64 in both styles.
