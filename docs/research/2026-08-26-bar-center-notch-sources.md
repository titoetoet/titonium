# Bar and Center Notch Reference Sources

## Ambxst

- Repository: `https://github.com/Axenide/Ambxst`
- Inspected revision: `65b7940`
- License: AGPL-3.0
- Files inspected:
  - `modules/notch/Notch.qml`
  - `modules/notch/NotchContent.qml`
  - `modules/widgets/dashboard/Dashboard.qml`
  - `modules/widgets/dashboard/DashboardView.qml`

Titonium retains the top-attached compact/expanded silhouette, true screen centering, 48 logical
pixel icon rail, moving selection highlight, vertical separator, clipped content viewport and
lazy destruction of replaced pages.

Titonium rejects Ambxst's global visibility/config graph, theme imports, persistent heavy loaders,
`MultiEffect` transition blur, GPU mask construction and backend dependencies.

## Caelestia

- Repository: `https://github.com/caelestia-dots/shell`
- Inspected revision: `1e33753`
- License: GPL-3.0
- Files inspected:
  - `modules/bar/popouts/Wrapper.qml`
  - `modules/bar/popouts/ClipWrapper.qml`
  - `modules/bar/popouts/Content.qml`

Titonium retains only the lifecycle principle: load incoming content before entry, finish outgoing
motion before destruction, and keep at most one transient owner per screen.

## DankMaterialShell

- Repository: `https://github.com/AvengeMedia/DankMaterialShell`
- Inspected revision: `ea0b158`
- License: MIT

DMS remains a later reference for responsive Settings navigation, lazy settings pages and
consumer-driven system monitoring. No DMS Settings or monitoring code belongs to this Bar slice.

## Local implementation statement

No upstream source was copied into Titonium. The implementation uses Titonium-owned QML,
repository-local JavaScript domain helpers and existing semantic tokens.
