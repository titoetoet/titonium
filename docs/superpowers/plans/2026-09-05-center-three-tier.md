> Historical implementation record. The 2026-09-06 assignment/activation revision in
> `../specs/2026-09-05-center-island-idle-compact-design.md` supersedes the priority
> and swapping rules below. Its runtime changes are not covered by these completed tasks.

# Center Three-Tier Implementation Plan

> **For agentic workers:** Use executing-plans to implement this plan task-by-task.

**Goal:** Align Idle/Compact with locked Privacy > Focus > Media rules.
**Architecture:** Keep domain assignment pure, views emit intents, services own audio and
capture integration. Preserve existing Banner/Expanded routing and unrelated workspace edits.
**Tech Stack:** QML/Qt Quick, Quickshell, JavaScript reducers, native PipeWire peak monitoring.
**Spec:** docs/superpowers/specs/2026-09-05-center-island-idle-compact-design.md

## Global constraints

No Operations, no rotation, five real-audio bars in both slots, Focus eligible for Satellite.
No UI-owned processes. No changes to Hyprland configuration, clipboard or protected features.

## Tasks

- [x] Assignment: revise scripts/check_center_compact.js to exercise three-way defaults,
  swaps, completion and reused privacy identities; observe failure; restrict
  CompactActivityRules.eligible to capture/focus/media and remove Focus exclusion.
  Run `node scripts/check_center_compact.js`.
- [x] UI: add QML tests for title-only media, five sampled bars, Focus ring/countdown,
  wheel intent scoping and right-click intent. Implement in CenterCompactCapsule and
  CompactActivityIcon, passing live levels separately from activity snapshots.
  Run `python3 scripts/check_center_compact_ui.py`.
- [x] Services: player-scoped MPRIS volume; shared native output-peak monitoring with
  five measured bars and no recording/persistence; explicit Focus countdown session;
  privacy capabilities and lightweight menu with session validation. Test measured history with
  silence and bounded peak samples; test action rejection for stale and unsupported contexts.
- [x] Verify: run check.sh, smoke.sh, protected_acceptance.sh and Hyprland configerrors.
  Use isolated temporary runtime for gates that reject a resident shell. Update
  CENTER_IDLE_COMPACT_FIRST_PASS.md with verified behavior and actual limits.
