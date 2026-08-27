# Titonium Spotlight Design QA

## Evidence

- Source visual truth: `/home/cole/.codex/generated_images/01a037cb-1907-7283-b61a-d2511a403983/exec-689e370a-ea31-46fc-b4c7-5e9973d6eb8d.png`
- Verified implementation screenshot: `/tmp/titonium-launcher-spacing-pass.png`
- Final normalized comparison: `/tmp/titonium-launcher-spacing-audit.png`
- Source pixels: 1672 × 941, generated desktop reference, density unspecified.
- Implementation pixels: 3840 × 2160 on DP-1; Quickshell logical viewport 2560 × 1440 at scale 1.5.
- Density normalization: source panel crop 600 × 520 and implementation panel crop 1380 × 1200 were both normalized to 1200 × 1040 before side-by-side inspection.
- State: dark Neutral Utility theme, Applications scope, browse mode, page one, first application selected, search field focused.

## Full-view comparison

The verified implementation preserves the reference hierarchy: centered solid panel, identity/search/scope header, dynamic category rail, five-column by four-row application grid, selected first tile and proportional page indicator. The implementation intentionally remains solid and compositor-independent; it does not reproduce the reference's glass-like softness.

## Focused-region comparison

The normalized panel comparison was required because the header controls, search border, application icon scale and selected tile were too small to judge in the full desktop capture. The final crop confirms a neutral one-pixel pill search frame, three tonal icon-only scope controls, rounded category selection, 56px application icons and a bounded selected tile.

## Findings

- No actionable P0, P1 or P2 findings remain.
- P3: installed application names and ordering differ from the generated mock. This is expected because Titonium renders the live DesktopEntries catalog.
- P3: desktop entries whose icon is absent from the active icon theme use category-aware Material Symbols. Inventing or bundling substitute application logos would reduce asset fidelity.
- P3: the implementation is visually sharper and flatter than the generated reference. This is intentional: the approved direction is Solid Depth with no blur, glass, shader or compositor integration.

## Comparison history

1. Pass 1 found a P1 scale mismatch: the implementation panel was roughly 20–25% smaller than the source. Fixed by using a bounded 920 × 800 logical frame while retaining the approved y=200 position.
2. Pass 2 found P2 header and catalog mismatches: scope buttons collapsed/appeared transparent, DesktopEntry categories were discarded, application icons were undersized, and the search focus border was accent blue. Fixed by reserving the scope rail, using tonal buttons, normalizing QStringList-like categories, adopting the shared SystemIcon resolver, using 56px icons and replacing the focus accent with a neutral stronger border.
3. Pass 3 found P2 search and fallback polish issues: the search frame was too rectangular and missing a leading search glyph; missing application icons all used the same dot-grid glyph. Fixed with a neutral pill frame, leading search icon and category-aware fallbacks.
4. Pass 4 found a P2 header-balance issue and a pagination defect: the search field consumed all remaining width, the identity/scope controls had weaker proportions than the target, and fixed 56px indicator hitboxes visibly separated compact density marks. Fixed with a 28px identity, bounded 620×48 search frame, 48px scope controls, a flexible header spacer, 4px indicator spacing and pointer-handler margins that preserve a 44px target without affecting visual layout.
5. Final pass used `/tmp/titonium-launcher-spacing-audit.png`; no actionable P0/P1/P2 differences remained after accounting for live catalog content and the explicit no-glass constraint.

## Interaction and accessibility checks

- Apps, Clipboard and System retain the existing Tab-cycle order and IPC acceptance coverage.
- Icon-only scope controls expose translated accessible names and delayed hover tooltips.
- Search keeps an editable accessible role and a visible neutral focus treatment.
- Enter/search, close, clipboard isolation and transient lifecycle passed protected acceptance.

## Final result

final result: passed
