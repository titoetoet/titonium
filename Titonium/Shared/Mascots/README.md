# Mascots

Production mascot artwork lives here, grouped by animal.

- `Pig/`: SleepyPig (idle), CoffeePig, CoderPig and WalkingPig (hover reactions).
- Future cat and dog artwork can live in sibling `Cat/` and `Dog/` modules when implemented.

`Titonium/Bar/center/IdleMascot.qml` owns the current selection and lazy loading. The artwork remains presentation-only; this move does not add a mascot selector or change behavior.

Pig components preserve their existing `paused`, `pigColor` and `viewAngle` properties. Runtime views load production files directly; demo previews reuse these same files.
