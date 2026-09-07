# Center Island: Idle and Compact UI/UX

Date: 2026-09-05
Status: Locked by user. Supersedes the previous four-tier and hidden-Focus draft.
Assignment, activation and transient capture feedback revised and confirmed on 2026-09-06; these revisions are
design decisions, not a claim that runtime implementation has been updated.

## Scope

Only Idle and Compact. Banner and Expanded design remain deferred. Their existing
entry actions are retained. Satellite is an area within Compact, not a state.

## State 1: Idle

### Meaning and appearance

Idle means no activity belonging to Center Island is active. It does not mean that
all operating-system processes have stopped. Hidden activities, including an undisplayed
Focus session, still prevent Idle. An activity needing no attention is not sufficient
reason to enter Idle.

The sleeping mascot sits inside a small Center Island body: a top-attached notch in
Connected and a pill-shaped capsule in Classic.
Only the mascot is displayed. Pig is the default. Users can select bundled mascots
in Settings; drawings and animations are QML templates maintained in source code.
The capsule keeps fixed bounds during mascot reactions.

### Interaction

| Event | Behavior |
| --- | --- |
| Resting, no pointer interaction | Pig sleeps with gentle breathing. |
| Pointer enters | Pig wakes and selects a reaction from the curated collection. |
| Pointer remains | Pig continues the selected reaction. |
| Pointer leaves | Pig settles back to sleep. |
| Click capsule | Request Expanded with an empty resting view; its design is deferred. |
| Return from Expanded with no active activity | Return to Idle. |
| First activity starts | Leave Idle for the appropriate activity presentation. |
| Last activity ends | Idle becomes the resting presentation again. |

The initial hover collection is drinking coffee, coding, and walking. Selection is
random, avoiding the previous reaction when possible. Walking stays inside the capsule.
Mascot actions do not create activities or change the Island's semantic Idle status.
Opening Expanded does not create an activity either.

Existing source references:

- `demos/pig_variants/SleepyPig.qml`: sleep breathing and a wake-up trigger.
- `demos/pig_variants/IslandPig.qml`: action selection and in-Island movement.
- `demos/pig_variants/CoffeePig.qml`, `CoderPig.qml`, and `WalkingPig.qml`: curated actions.
- `Titonium/Bar/islands/CenterPigMascot.qml`: current perimeter-walking integration,
  which differs from the new contained sleeping design.

The existing SleepyPig wake-up timer is not the new hover contract: the proposed
behavior remains awake while hovered and settles on pointer leave.

## State 2: Compact

Connected retains its top-attached notch with curved shoulders in both Idle and
Compact. Classic uses the oval capsule. Both contain Primary and an icon-only
Satellite within one shared body, with no external gap.
Height follows Topbar Settings. Width follows content within logical-monitor-relative
bounds; media titles fade at 200px and scroll only on hover/focus. Countdown and elapsed digits use monospace
and tabular numerals. Width changes smoothly and the capsule stays centered.
Satellite has a stable hit area and subtle chip background, stronger on hover/focus.

| Priority | Activity | Primary | Satellite |
| --- | --- | --- | --- |
| 2 | Privacy: recording, microphone, screen sharing | Pulsing red dot and elapsed time | Subtle pulsing red dot |
| 1 | Focus / Pomodoro | Focus icon and fixed-width countdown | Focus icon and depleting radial ring, no text |
| 3 | Media | Four thin frequency-reactive bars and cleaned track title | Three reactive bars only |

Compact trial format now includes artist metadata as `Title - Artist`; album art stays
out of scope. Remove only bracketed metadata tags recognized by regex, plus hashtags;
preserve meaningful parentheses. Use trackArtist to identify a whole artist segment
on either side of a separator. Preserve ambiguous multi-part titles rather than
assuming the first part is an artist. Do not invent Unknown Artist. This supersedes
the earlier blanket bracket removal and first-token truncation rules.
Cap title width at 200 logical pixels,
with a trailing alpha fade. Overflow scrolls only on hover or keyboard focus.
Shimmer applies only to the Primary song title: stationary glyphs with a dim base
and an angled light sweep every 1.8 seconds. Pause, Reduced Motion and hover scrolling
disable shimmer. Reduced Motion also disables scrolling.

Bars are 3px wide, spaced 2px apart, fully rounded, vertically centered, and range
from 3–14px with 160ms damping. Use muted monochrome. Primary samples four real
frequency bands; Satellite combines the middle bands into one. Output-monitor FFT
provides measured levels, never synthetic loops. Silence, pause and unavailable audio
settle to short bars. Reduced Motion uses still bars and a static privacy indicator.

### Assignment

- Active activities determine slot ownership by priority: Focus > Privacy/Recording > Media.
- Outside transient capture feedback, Primary holds the highest-priority eligible activity; Satellite holds the next.
- With all three active: Focus Primary, Privacy Satellite, Media hidden.
- With Recording and Media active: Recording Primary, Media Satellite throughout
  recording; Recording does not relinquish Primary after an announcement timeout.
- Reassess when activity eligibility changes. Do not restore slots from interaction history.
- No pinning, manual swapping, automatic rotation, or arbitrary app picking.
- Routine metadata/countdown updates do not change assignment. Stable equal-priority
  ordering retains current order.
- A new privacy session does not permanently displace an active higher-priority Focus
  activity. Recording-start feedback may temporarily occupy Primary as specified below.
- Paused media retains its slot under the existing lifecycle; stopped/closed media leaves.
- Click Primary or Satellite to open that activity's Normal (code mode: Banner).
  Satellite activation never swaps slots or promotes the selected activity.
- Closing Normal returns to Compact with slots determined by current activity priority.
  For example: Focus Primary + Media Satellite -> open Media Normal -> close ->
  Focus Primary + Media Satellite, provided both activities remain eligible.
- Keyboard activation follows the same target-specific opening behavior.

### Transient capture feedback (confirmed 2026-09-06)

- Successful screenshot saving and recording start temporarily occupy Primary for
  6 seconds (the selected default within the approved 5–7 second range), including
  while Focus is active. This is a timed exception to activity priority.
- Screenshot feedback says “Đã lưu ảnh chụp”. Activating it opens Normal with a
  preview of the exact screenshot associated with that event. Retain the event's
  image identity; do not resolve it by looking up whichever screenshot is latest.
- Recording-start feedback shows a red dot and “Đang ghi hình”. Activating it opens
  Normal for that recording session. Starting recording never automatically opens Banner.
- The previous Primary activity moves to Satellite during feedback. Where a
  recording indicator would otherwise be displaced (for example Focus + Recording
  followed by a screenshot), keep a visible recording red dot within the Island.
- After expiry, remove transient feedback and compute slots from currently active
  activities using Focus > Recording/Privacy > Media; do not restore historical slots.
- With Focus + Recording, expiry yields Focus Primary / Recording Satellite.
  With Recording + Media, Recording stays Primary and changes from its announcement
  to elapsed time; Media stays Satellite. Screenshot feedback leaves Compact on expiry.
- Expiry must not close a Normal view the user has opened, including screenshot preview.
- These capture events do not force an already open Normal/Expanded view back to Compact.
- This revision covers screenshot-save success and recording start. It does not
  finalize generic system notifications or recording-stop/failure feedback.

### Actions

- Wheel volume adjustment is scoped strictly to the visible Media hit area, in either
  slot, and targets that player. Focus/Privacy scrolling never changes volume.
- Right-click Privacy opens a lightweight menu of supported actions, such as Mute
  Microphone or Stop Recording. No invisible immediate stop or mute gesture.
- Validate the context/session again before executing a menu action.
- Clear keyboard focus feedback is retained; no swap affordance is presented.

### Removed from this scope

Operations tier, Progress template, builds, downloads, renders, AI Agents (including
stubs), counters and generic external integration schemas. Underlying services may
continue serving other shell features. Notifications retain their existing separate
presentation policy; they do not compete for the two Compact activity slots.
The screenshot-save and recording-start feedback specified above is an explicit
exception for capture events, not a general notification-slot policy.

## Implementation parameters

The existing measured first-pass geometry is retained: capsule height Topbar minus
8 (minimum 24), Idle width 2.4 times capsule height, Compact minimum max(3 heights,
7.5% monitor width), maximum max(minimum,25% monitor width), bounded to usable width.
These are implementation parameters, not additional unresolved interaction rules.
Provider capabilities determine which privacy actions can actually be offered.

## Acceptance

- Idle sleep/hover/leave behavior remains unchanged and stays inside fixed bounds.
- Three-way default is Focus Primary, Privacy Satellite, Media hidden.
- Outside transient feedback, Recording remains Primary over Media until eligibility changes.
- New privacy sessions, Focus completion and privacy completion obey priority assignment
  and the explicit recording-start feedback exception.
- Clicking either slot opens the Normal of that slot's activity without reordering slots;
  keyboard activation behaves identically.
- Opening Media from Satellite and closing it preserves Focus Primary / Media Satellite
  when both remain eligible; changes during Normal are resolved using current priority.
- Focus countdown and any displayed Focus ring continue updating.
- Media has four bars in Primary and three in Satellite; only Primary contains a cleaned title.
- Audio silence/unavailability and Reduced Motion do not show fabricated animation.
- Only wheel input over Media emits a player-volume action.
- Right-click Privacy opens supported actions without activating Banner or swapping.
- Unsupported/completed activities do not keep Compact active.

## Capture feedback acceptance

- Screenshot-save success and recording start show 6-second Primary feedback without
  automatically opening Banner, including when Focus is active.
- Clicking screenshot feedback opens the exact associated image; recording feedback
  opens its associated session. Opening Normal is not undone by feedback expiry.
- Verify expiry with Focus + Recording, Recording + Media, and screenshot-only cases;
  use current activity eligibility, including activities ending during feedback.
- Focus + Recording + screenshot retains a visible recording dot while Focus is Satellite.
- Normal/Expanded is not forcibly collapsed by capture feedback.

## Remaining design scope

Implementation ruling: overlapping feedback is latest-wins without a queue; a user-opened
screenshot keeps its original image until closed. Screenshot Normal uses a bounded,
aspect-preserving preview with loading/unavailable states in both themes.
Recording-stop/failure messages and generic system-notification policy remain outside
this implementation. Runtime verification is recorded in the implementation plan.
