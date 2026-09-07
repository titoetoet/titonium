# Source cleanup implementation plan

**Goal:** Remove verified disconnected source and generated clutter, preserving current runtime behavior.
**Architecture:** Retain Classic/Connected routes and the neutral Center host. Retire old components and their registrations; redirect meaningful popup checks to the active Classic implementations.
**Spec:** User-approved stages 1 and 2 of the cleanup proposal in this task.
**Constraints:** Preserve existing working-tree changes, runtime data, protected features, active mascot modules, test fixtures and font. No renderer optimization in this batch.

- [x] Capture Git status and pass the static baseline.
- [x] Back up the current tree outside the repository before removing files.
- [x] Remove the reviewed paths and prune matching qmldir exports.
- [x] Retarget popup checks to current Classic implementations; preserve Connected coverage. Remove obsolete disconnected-view assertions, retaining domain and active UI checks.
- [x] Run the full static gate and inspect all changes relative to the backup.
- [x] Run safe foreground validation where session access permits; document live-gate limitations.
- [x] Remove generated Python bytecode, unused icon, and empty directories; report exact removals.

Removal manifest: /tmp/titonium-cleanup-removals.json. Recovery snapshot: /tmp/titonium-before-cleanup.tar.gz.

Results and live verification limits: `docs/SOURCE_CLEANUP.md`.
