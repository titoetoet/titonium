# Titonium Spotlight Design QA

## Evidence

- Source visual truth: `/home/cole/.codex/generated_images/01a037cb-1907-7283-b61a-d2511a403983/exec-98c7d2ff-8ef8-4088-bdbd-76f38f52e398.png`
- Verified implementation screenshot: `/tmp/titonium-spotlight-category-rail.png`
- Final normalized comparison: `/tmp/titonium-spotlight-category-rail-compare.png`
- Source pixels: 1672 × 941, generated desktop reference, density unspecified.
- Implementation pixels: 3840 × 2160 on DP-1; Quickshell logical viewport 2560 × 1440 at scale 1.5.
- Density normalization: source panel crop 600 × 520 and implementation panel crop 1290 × 1110 were both normalized to 860 × 740 before side-by-side inspection.
- State: dark Neutral Utility theme, Applications scope, browse mode, page one, no preselected application, search field focused.

## Full-view comparison

The verified implementation preserves the reference hierarchy and updated proportions: centered solid 860 × 740 panel, identity/search/scope header, dynamic category rail, five-column by four-row application grid and proportional page indicator. Browse mode intentionally has no default application selection. The implementation remains solid and compositor-independent; it does not reproduce the reference's glass-like softness.

## Focused-region comparison

The normalized panel comparison was required because the header controls, search border, application icon scale and inter-section rhythm were too small to judge in the full desktop capture. The final crop confirms a neutral one-pixel pill search frame, three optically balanced icon-only actions, rounded category selection, 56px application icons, aligned five-column centers, and a compressed four-row rhythm above the density indicator.

## Findings

- No actionable P0, P1 or P2 findings remain.
- P3: installed application names and ordering differ from the generated mock. This is expected because Titonium renders the live DesktopEntries catalog.
- P3: desktop entries whose icon is absent from the active icon theme use category-aware Material Symbols. Inventing or bundling substitute application logos would reduce asset fidelity.
- P3: the implementation is visually sharper and flatter than the generated reference. This is intentional: the approved direction is Solid Depth with no blur, glass, shader or compositor integration.
- P3: the source uses text labels inside its scope capsule; Titonium intentionally uses the user-approved Apps/Clipboard/System icons with translated tooltips and accessible names.

## Comparison history

1. Pass 1 found a P1 scale mismatch: the implementation panel was roughly 20–25% smaller than the source. Fixed by using a bounded 920 × 800 logical frame while retaining the approved y=200 position.
2. Pass 2 found P2 header and catalog mismatches: scope buttons collapsed/appeared transparent, DesktopEntry categories were discarded, application icons were undersized, and the search focus border was accent blue. Fixed by reserving the scope rail, using tonal buttons, normalizing QStringList-like categories, adopting the shared SystemIcon resolver, using 56px icons and replacing the focus accent with a neutral stronger border.
3. Pass 3 found P2 search and fallback polish issues: the search frame was too rectangular and missing a leading search glyph; missing application icons all used the same dot-grid glyph. Fixed with a neutral pill frame, leading search icon and category-aware fallbacks.
4. Pass 4 found a P2 header-balance issue and a pagination defect: the search field consumed all remaining width, the identity/scope controls had weaker proportions than the target, and fixed 56px indicator hitboxes visibly separated compact density marks. Fixed with a 28px identity, bounded 620×48 search frame, 48px scope controls, a flexible header spacer, 4px indicator spacing and pointer-handler margins that preserve a 44px target without affecting visual layout.
5. Final pass used `/tmp/titonium-launcher-spacing-audit.png`; no actionable P0/P1/P2 differences remained after accounting for live catalog content and the explicit no-glass constraint.
6. The compactness pass found a P2 overall-scale and header-grouping mismatch: the 920 × 800 frame felt oversized and three independent scope squares did not reproduce the source's unified segmented rhythm. The frame was reduced to 860 × 740, search to 560 × 46, and the actions were regrouped into one fixed 200px capsule. The normalized post-fix evidence is `/tmp/titonium-spotlight-reference-balanced-final.png`; no actionable P0/P1/P2 differences remain in the approved scope.
7. The final user-directed pass restored three independent rounded scope controls and found a P2 vertical-rhythm mismatch: one generic 12px layout gap placed the category rail and first application row too high while stretching later rows. The content now uses an 8px top inset, a 20px header-to-category gap and a 56px category-to-grid break. Horizontal app centers and the 860 × 740 frame were retained because normalized comparison showed they already matched the reference. Browse pages no longer preselect the first application; search-result selection and Enter activation remain unchanged.
8. The category-rail pass moved only the text controls 12px down and 12px inward, raised their label size from 14px to 15px, and compensated the lower gap from 56px to 44px. The normalized comparison confirms the application icons and indicator did not move while the text baseline now follows the reference.

## Interaction and accessibility checks

- Apps, Clipboard and System retain the existing Tab-cycle order and IPC acceptance coverage.
- Icon-only scope controls expose translated accessible names and delayed hover tooltips.
- Search keeps an editable accessible role and a visible neutral focus treatment.
- Enter/search, close, clipboard isolation and transient lifecycle passed protected acceptance.

## Final result

final result: passed
