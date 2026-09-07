# Connected Music: shoulders, title and continuous transition

User approved completing all remaining Connected styling and state 2 ↔ 3 motion
in one pass. Music keeps its source fallback and optional Up next behavior.

## Implementation

Connected now keeps one mapped Center overlay across compact and open modes. The
old compact window is not mapped for this profile. Compact uses a bounded input
mask; open uses the existing focus policy. Hidden/non-owner hosts remain masked
and do not render content. Other style window contracts remain unchanged.

The same black/white shoulder contour interpolates from the compact capsule's
actual geometry to the content-sized Music geometry over 300ms, OutCubic. The
bespoke outlined Music rectangle is removed. One title node keeps the cleaned song title and moves to the position beside
the artwork; the artist stays on its separate subtitle line. Controls, artwork
and source keep their final layout and fade in during the final 20% of shell
expansion. Controls are
inactive until the surface is almost fully open and throughout contraction.

Motion reverses from its current value. Outgoing Music data is retained when
switching to Focus/Timer/another context. Closed/revoked surfaces contract and
signal completion; reduced motion snaps and explicitly signals completion too.
The overlay therefore releases its exiting owner and input mask correctly.

## Verification

- Window ownership regression failed before switching Connected to one window.
- Full Connected-renderer test covers title identity/content, shoulder fill,
  intermediate geometry, open/close, reversal, transport, closed/revoked states,
  media→non-media context switching and reduced-motion completion signals.
  Review findings each received a failing regression before their fixes.
- scripts/check.sh passed, including the new renderer test and qmllint.
- 10 Music component interaction tests passed.
- Isolated smoke and protected acceptance passed. Center attention acceptance
  now checks the intentional one-overlay/no-compact-window Connected contract.
- Actual desktop captures show shoulders, compact/open endpoints and intermediate
  frames. Actual Music button clicks changed native playback Playing ↔ Paused.
- Final shell status: ready. No Hyprland configuration errors. git diff --check
  passed. No Hyprland configuration was edited.

Evidence: connected-open-live.png, connected-compact-live.png and
connected-morph-live.mp4. The video is a sequence of actual one-shot desktop
captures played at 12fps for inspection, not a measurement of animation timing.
A conventional recorder was discarded because recording correctly became the
higher-priority capture activity in Center. No synthetic design frames are used
in the delivered live preview.

## Title stability follow-up

The traveling title now uses one fixed 17px semibold Qt text layout, scaled
continuously from the compact 14px size. Font size and weight no longer change
during the morph, avoiding glyph relayout and a midpoint weight jump. The compact
capsule stays mounted to preserve the title origin; its hidden media shimmer and
scroll demand are disabled. The existing shoulder contour and final panel size
are retained.

Regression coverage verifies constant glyph size/weight, song-only title text,
delayed content reveal and disabled hidden title shimmer, alongside opening,
closing, reversal and reduced motion. These checks failed before their fixes.
The 13 compact UI cases and full check.sh passed.

The desktop images/video above predate this title follow-up. morph-mid.png and
morph-open.png are current offscreen QML fixture captures, not live desktop
evidence.
