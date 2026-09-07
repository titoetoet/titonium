# Source fallback — superseded

The user requested restoring the reference design: always show UP NEXT beneath
the spectrum with artwork and next-track metadata. When queue data is absent,
keep the same layout with an unavailable message; do not substitute Source/Chrome.

## Previous implementation — 2026-09-06

Approved behavior: show the media source and playing/paused/stopped state below
the spectrum when there is no upcoming track. A real next track takes precedence.
The source row opens the native player only when MPRIS CanRaise permits it.

Source identity comes from the player. YouTube is identified only from a matching
xesam:url hostname, never inferred from the track title or artist. Chromium can
omit that URL; the live capture therefore correctly shows Chrome. Its CanRaise
was false, so the row is informational and has no open-source icon. Native Raise
can open the player; it cannot guarantee selecting a specific browser tab.

Validation: source mapping tests, 10 QML interaction tests, scripts/check.sh,
isolated smoke and protected acceptance passed. Final readability adjustment
sets the source label tone explicitly so disabled actions do not dim information;
10 QML tests passed again. Read-only review found no important issues.
Live GPU evidence: source-fallback-live.png. No media playback was changed.
