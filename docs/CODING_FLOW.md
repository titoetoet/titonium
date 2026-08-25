# Coding flow

Use this flow for every feature or setting.

1. Define user-visible behavior and acceptance cases in the milestone document.
2. Add or extend a versioned schema and its valid/invalid fixtures.
3. Define the module boundary: input properties, output signals and required capability.
4. Implement OS access in `Platform`; prefer event-driven APIs over command polling.
5. Implement state/model behavior without visual items.
6. Build UI only against semantic theme/i18n and the module boundary.
7. Register a new widget type once in `WidgetRegistry` when it is bar-composable.
8. Add Vietnamese and English keys together.
9. Gate loaders, pollers, animations and graphical effects by visibility and consumer count.
10. Run config validation, architecture checks, `qmllint`, foreground smoke test and visual QA.
11. Update the module documentation and roadmap status.

Avoid broad files that accumulate unrelated state. When a file exceeds roughly 300 lines,
check whether it has more than one reason to change before adding more code.

