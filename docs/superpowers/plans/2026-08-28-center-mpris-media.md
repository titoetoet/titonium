# Center MPRIS Media Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add event-driven MPRIS playback projection so track/playback transitions temporarily occupy Center while a small media indicator remains during playback.

**Architecture:** One `MprisService` singleton exclusively imports Quickshell MPRIS, selects a player through pure deterministic rules and publishes semantic events into the existing `CenterAttentionService`. Center continues to render the shared descriptor/indicator contract and never imports MPRIS.

**Tech Stack:** Quickshell/QML, `Quickshell.Services.Mpris`, pure JavaScript, Node.js fixtures, Python architecture checks, Bash/manual acceptance.

**Spec:** `docs/superpowers/specs/2026-08-28-center-attention-system-design.md`

## Global Constraints

- Complete `2026-08-28-center-core-daily-focus.md` and its manual checkpoint first.
- Exactly one file may import `Quickshell.Services.Mpris`.
- Playing beats paused; equivalent players use most-recent meaningful change then stable identity.
- Initial discovery emits no false transient event.
- Track change/resume/pause use Center-owned policy priorities/TTLs; callers send no raw priority.
- Duplicate native property signals with an unchanged normalized signature emit nothing.
- Media disappearance/stop clears the passive indicator without taking over Center.
- No media CLI, process polling, artwork, visualizer or player controls in this slice.

---

## File structure

```text
Titonium/Services/Mpris/
├── MprisRules.js       # normalize players, rank selection and derive transitions
├── MprisService.qml    # sole native owner and Center publisher
└── qmldir

scripts/
├── check_mpris_rules.js
├── check_mpris.py
└── mpris_acceptance.sh
```

### Task 1: Define deterministic player projection and transition rules

**Files:**
- Create: `Titonium/Services/Mpris/MprisRules.js`
- Create: `scripts/check_mpris_rules.js`
- Modify: `scripts/check.sh`

**Interfaces:**
- Consumes: value facts `{ identity, playbackState, trackTitle, trackArtist, changedAt }[]` and a
  previous projection.
- Produces: `normalizePlayer(raw)`, `select(players)`, `signature(player)`, and
  `transition(previous, selected, now)` returning `{ next, event }`.

- [ ] **Step 1: Write failing ranking and transition fixtures**

Cover these exact cases:

```js
const playing = { identity: "player.a", playbackState: "playing",
    trackTitle: "Awake", trackArtist: "Tycho", changedAt: 20 };
const paused = { identity: "player.b", playbackState: "paused",
    trackTitle: "Other", trackArtist: "Artist", changedAt: 40 };
assert.equal(rules.select([paused, playing]).identity, "player.a");

const baseline = rules.transition(null, playing, 1000);
assert.equal(baseline.event, null);
assert.equal(baseline.next.title, "Tycho · Awake");

const changed = rules.transition(baseline.next, {
    ...playing, trackTitle: "A Walk", changedAt: 30,
}, 2000);
assert.equal(changed.event.kind, "track_changed");
assert.equal(changed.event.title, "Tycho · A Walk");
```

Also assert playing→paused emits `paused`, paused→playing emits `resumed`, unchanged signatures emit
null, blank title is not a track event, disappearance emits no event, equivalent candidates use
`changedAt` descending then `identity` ascending, and normalized output contains no native object.

- [ ] **Step 2: Run the fixture and verify it fails**

Run: `node scripts/check_mpris_rules.js`

Expected: FAIL because `MprisRules.js` is missing.

- [ ] **Step 3: Implement minimal pure projection rules**

Normalize playback to `playing`, `paused` or `stopped`; join non-empty artists with `, `; render
`Artist · Title` when both exist and Title alone otherwise. `transition(null, selected, now)` always
establishes a baseline with `event: null`. Compare track identity before playback state so a new
track produces only `track_changed`, not an additional resume event.

- [ ] **Step 4: Run tests and add them to the static gate**

Run: `node scripts/check_mpris_rules.js`

Expected: PASS. Add it immediately after `check_center_attention_rules.js` in `scripts/check.sh`.

- [ ] **Step 5: Commit pure rules**

```bash
git add Titonium/Services/Mpris/MprisRules.js scripts/check_mpris_rules.js scripts/check.sh
git commit -m "feat: define mpris center transitions"
```

### Task 2: Add the sole native MPRIS service and Center adapter

**Files:**
- Create: `Titonium/Services/Mpris/MprisService.qml`
- Create: `Titonium/Services/Mpris/qmldir`
- Create: `scripts/check_mpris.py`
- Modify: `Titonium/App.qml`
- Modify: `scripts/check.sh`
- Modify: `config/i18n/vi.json`
- Modify: `config/i18n/en.json`

**Interfaces:**
- Consumes: `Mpris.players` and native player property-change signals.
- Produces: readonly `selectedPlayer` value descriptor, `playing`, `title`, `snapshot()`; publishes
  `{ source: "media", kind, id: "media:current", deduplicationKey: "media:current", title, icon,
  createdAt }` and sets indicator ID `media`.

- [ ] **Step 1: Write a failing architecture contract**

`scripts/check_mpris.py` must count exactly one MPRIS import in Titonium, require the singleton
declaration/qmldir/App import, require `MprisRules.transition`, `CenterAttentionService.publish`,
`CenterAttentionService.setIndicator`, and reject `Process`, `Timer`, `FileView`, native player
objects in public properties, Bar imports and raw `priority`/`ttl` fields.

- [ ] **Step 2: Run the architecture contract and verify it fails**

Run: `python3 scripts/check_mpris.py`

Expected: FAIL because the service module is missing.

- [ ] **Step 3: Implement projection from value facts only**

Use the native singleton as the sole source:

```qml
import Quickshell.Services.Mpris
import qs.Titonium.Services.Center
import "MprisRules.js" as MprisRules

readonly property var playerFacts: Mpris.players.values.map(player => ({
    identity: player.identity || player.dbusName || "",
    playbackState: MprisPlaybackState.toString(player.playbackState).toLowerCase(),
    trackTitle: player.trackTitle || "",
    trackArtist: player.trackArtist || "",
    changedAt: root.changeTimes[player.identity || player.dbusName || ""] || 0,
}))
```

The installed Quickshell API exposes `identity`, constant `dbusName`, `trackTitle`, string
`trackArtist`, `playbackState`, and the signals `trackTitleChanged`, `trackArtistChanged` and
`playbackStateChanged`. Use an `Instantiator` with `model: Mpris.players`; each delegate is a
`Connections` targeting `modelData` and calls `root.markChanged(modelData.dbusName)` from those
three handlers. A separate `Connections { target: Mpris.players }` recomputes on `valuesChanged`.
`recompute()` runs the pure transition once, publishes only non-null events and sets `media` active
only when the projection is playing.

- [ ] **Step 4: Add translations and focused verification**

Add equal keys for media indicator and fallback labels. Run:

```bash
node scripts/check_mpris_rules.js
python3 scripts/check_mpris.py
python3 scripts/check_center_attention.py
./scripts/check.sh
```

Expected: PASS with no new qmllint warning and no media transition at shell startup.

- [ ] **Step 5: Commit the service**

```bash
git add Titonium/Services/Mpris Titonium/App.qml config/i18n scripts/check_mpris.py scripts/check.sh
git commit -m "feat: publish mpris events to center"
```

### Task 3: Add safe MPRIS acceptance and manual checkpoint

**Files:**
- Create: `scripts/mpris_acceptance.sh`
- Modify: `Titonium/App.qml`
- Modify: `scripts/check.sh`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: `MprisService.snapshot()` and `CenterAttentionService.snapshot()`.
- Produces: read-only IPC `mpris.state()`; no play/pause/seek/player mutation.

- [ ] **Step 1: Add the read-only IPC/static requirement**

```qml
IpcHandler {
    target: "mpris"
    function state(): string { return MprisService.snapshot(); }
}
```

Reject control methods from IPC and add `bash -n scripts/mpris_acceptance.sh` to `check.sh`.

- [ ] **Step 2: Implement read-only live acceptance**

The script starts an isolated foreground shell, records MPRIS and Center state, requires clean
startup logs and verifies repository/Hyprland hashes and DP-1-only Bar ownership. It must not start,
stop or control a real player. If no isolated fake MPRIS player is available, report native state
and leave transition verification to pure tests plus the manual checkpoint.

- [ ] **Step 3: Run full gates**

```bash
bash -n scripts/mpris_acceptance.sh
./scripts/check.sh
./scripts/smoke.sh
./scripts/mpris_acceptance.sh
./scripts/center_attention_acceptance.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
git diff --check
```

Expected: PASS; no user playback state changes.

- [ ] **Step 4: Document, commit and request visual review**

```bash
git add Titonium/App.qml scripts docs/ARCHITECTURE.md docs/TESTING.md
git commit -m "test: cover center mpris projection"
```

Manually play one track, change track, pause and resume. Verify TTLs of 6/2/3 seconds, return to
Daily Focus, persistent media icon only while playing, no startup flash and no Center takeover when
the player disappears. Approve before starting the timer plan.
