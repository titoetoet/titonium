# Coding flow

Work in reviewable capability slices, not broad milestones spanning unrelated components.

1. Write the behavior contract and decide whether the change is Core, Service or View work.
2. Search candidate repositories only after the contract is clear. Record URL, revision, license,
   relevant files and the specific pattern worth adapting.
3. Write a failing pure-domain or static contract test. For runtime bugs, reproduce and isolate
   the causal boundary before changing code.
4. Implement the smallest service adapter, then its view. Keep external names and global objects
   out of Titonium's public interface.
5. Compose the slice in one place and retain lazy loading for popups/overlays.
6. Run `scripts/check.sh`, then foreground smoke and focused live acceptance.
7. Ask for visual/interaction review before starting the next visible batch.

Prefer native Quickshell models and event signals. A process or poller requires written evidence
that no reactive primitive exists and must still live in a Service singleton. Preserve unrelated
user changes and keep commits focused enough to revert independently.
