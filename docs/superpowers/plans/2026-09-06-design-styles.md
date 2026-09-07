# Titonium Design Styles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai năm ngôn ngữ thiết kế thật cho Titonium, giữ Connected/Classic độc lập, giữ giao dịch Appearance và kiểm chứng native glass trước khi tuyên bố full fidelity.

**Architecture:** Appearance resolve immutable design tokens; Shared controls giữ nội dung/state/input và delegate paint sang renderer theo style. Layout tiếp tục sở hữu geometry/mask/lifecycle. Native glass là capability có kiểm chứng và rollback riêng, không là dependency bắt buộc của shell.

**Tech Stack:** QtQuick/QML trên Qt 6.11.2 hiện cài, Quickshell, JavaScript thuần/Node vm, Python + qmltestrunner; Hyprland 0.56.2 chỉ tích hợp trong giới hạn được duyệt.

**Spec:** `docs/superpowers/specs/2026-09-06-design-styles-design.md`.

**Status:** kế hoạch để review, chưa thực thi. Các contract/code snippets dưới đây là test/implementation seams cụ thể; đây không phải assertion rằng các file mới đã tồn tại. Native adapter là task phụ thuộc kết quả spike, không có API compositor giả định sẵn.

## Global Constraints

- Giữ `schemaVersion: 8`; persisted key vẫn là `appearance.themeId`. 5 public IDs mới + 4 private legacy IDs.
- Runtime data ngoài Git; không sửa/reload hai `hyprland.lua`, không tự cài/load compositor plugin.
- UI không Process/FileView/persistence; Services không import view; mỗi thư mục QML có qmldir và import qs.Titonium.*; chuỗi UI dùng I18n.tr().
- Geometry, input mask, bar/dock layout, exclusive zone, native host và lifecycle không đổi do design style.
- Style motion áp dụng control paint; layout-motion không đổi khi đổi style. Reduced Motion luôn ưu tiên.
- Giữ Spotlight/keybindings, Input Method, dynamic screen/lazy overlay lifecycle. Không refactor protected business logic.
- Không launch app, ghi clipboard, thay wallpaper thật trong automated tests. DP-3 không bị tác động.
- Không screenshot/render polling mới. Không reset/stage toàn bộ cây làm việc đang dirty.
- Native glass thiếu evidence thì báo dependency/giới hạn; không đổi tên sheen thành refraction để vượt nghiệm thu.
- Đọc lại AGENTS.md, ARCHITECTURE.md, MODULE_CONTRACT.md, CODING_FLOW.md, TESTING.md và spec trước implementation.

## Dependency và mốc review

```text
0. Snapshot + baseline
  ├─ 1. Glass feasibility → quyết định native-ready / blur-only / fallback-only
  └─ 2. Catalog + compatibility + token contract
       → 3. Paint host + state + motion boundary
       → 4. Flat / Material / Neumorphism specimen
       → 5. Glass / Liquid specimen + native integration nếu task 1 đạt
       → 6. Shared controls và consumer audit
       → 7. Appearance preview / Advanced / transactions
       → 8. Shell integration + full verification
```

Mốc A: review spec/plan trước code. Mốc B: review specimen năm styles trên cùng scene trước chuyển toàn shell. Mốc C: review actual Connected/Classic + performance/rollback. Có thể tiếp tục các phần không phụ thuộc backend trong khi native gate chưa đạt; không tự giảm yêu cầu full glass.

## Task 0 — Snapshot đúng cây hiện tại và baseline

**Files:** không sửa production. Tạo manifest/diff/copy dưới `/tmp/titonium-design-styles-*`; ghi evidence trong `docs/DESIGN_STYLES_QA.md` khi có kết quả.

**Consumes:** working tree hiện tại có Appearance/Center chưa commit. **Produces:** baseline file hashes, kiểm tra trước sửa, isolated snapshot có thể chạy.

- [ ] Đọc `git status --short`, `git diff --stat` và diff các file cần sửa. Ghi cả untracked files bằng manifest SHA256; loại `.git` và runtime data khỏi copy.
- [ ] Dùng workflow worktree khi phù hợp nhưng đưa đúng uncommitted snapshot vào sandbox; verify toàn bộ SHA256 trước test. Không checkout HEAD-only. Không áp diff sang cây chính nếu source hash đã đổi sau baseline.
- [ ] Chạy baseline và lưu exit/log riêng, không coi failure có sẵn là lỗi của styles:

```bash
./scripts/check.sh > /tmp/titonium-design-styles-baseline-check.log 2>&1
```

- [ ] Chạy smoke/protected từ isolated snapshot với private XDG data, giữ shell resident. Ghi D-Bus skips đúng lý do. Thu screenshot baseline DP-1 khi được phép, tránh nội dung nhạy cảm; đo scene specimen riêng cho performance.
- [ ] Ghi danh sách files ownership; mỗi task tạo diff nhỏ, review trước chuyển task. Chỉ commit file của task sau verification và tách khỏi user changes; không bắt buộc commit cả cây dirty.

**Acceptance:** copy phản ánh cả untracked code; baseline logs và hashes tồn tại; không đổi settings/compositor/live app state.

**Concurrent-work observation trong lúc viết plan:** so với manifest planning, sáu file đổi từ công việc khác: `Titonium/Bar/right/EdgeMenuGeometry.js`, `Titonium/Bar/right/EdgeMenuSurface.qml`, `Titonium/Shared/AnchoredMenuPillShape.qml`, `scripts/check_edge_contour.py`, `scripts/check_edge_menu_geometry.js`, `scripts/check_right_pill.js`. Turn planning chỉ tạo hai tài liệu này. Không phục hồi sáu file hoặc dùng mô tả geometry cũ làm expected fixture; task 0 phải đọc lại phiên bản mới và lấy baseline mới trước implementation.

## Task 1 — Spike backend kính với verdict có bằng chứng

**Create:** `docs/research/2026-09-06-glass-backend.md`. Probe code chỉ trong `/tmp/titonium-glass-spike-*`, không giữ như production.

**Consumes:** Qt/Hyprland versions và live namespace inventory. **Produces:** verdict, pinned source/license inventory, capability contract và integration decision cụ thể.

- [ ] Xác minh read-only `hyprctl version`, `hyprctl plugin list`, `hyprctl layers -j`, Qt version. Không suy ra plugin đang loaded từ một đoạn config.
- [ ] Resolve SHA của HyprGlass bằng repository metadata/`git ls-remote`, đọc `.hyprland-version`, `hyprpm.toml`, `LICENSE` và các files trong spec §11 tại SHA đó. Ghi source URL + SHA + license + exact lines/pattern cần dùng. Nếu network/metadata thiếu thì ghi audit chưa đủ, không import.
- [ ] Tìm API thực tế cho layer scope/effect disable/rollback trên Hyprland cài. Không viết lệnh dựa vào syntax version cũ. Đối chiếu native blur và HyprGlass: alpha mask, per-namespace, output scoping, lease restore và plugin-loss.
- [ ] Kiểm chứng trên fixture panel có plain rectangle và chính Connected path; đặt một pattern chuyển động phía sau. Chỉ chạy native experiment khi backend/setup đã có và đủ phạm vi được phép. Nếu cần setup ngoài repo, chuẩn bị patch/commands đã kiểm tra và nêu dependency riêng.
- [ ] Ghi verdict theo bảng:

| Verdict | Evidence cần có | Hành động |
| --- | --- | --- |
| native-ready | Refraction background thật, no feedback, mask/morph đúng, Flat disable đúng, rollback đúng | Cho phép adapter task 5 |
| blur-only | Blur background thật đạt; refraction chưa đạt | Glassmorphism native; Liquid fallback, requirement còn mở |
| fallback-only | Chưa có backend đạt | QML core tiếp tục; không báo full glass complete |

- [ ] Ghi artifact path/video, performance baseline, limitation và setup ownership. Nếu backend cần sửa global compositor state hoặc không restore được thì verdict không được native-ready.

**Acceptance:** có câu trả lời khả thi, không có placeholder API hay binary ABI chưa kiểm chứng. Không cần test suite cho throwaway spike; cần evidence thực tế hoặc lý do không thể thử.

## Task 2 — Catalog, legacy compatibility và design tokens

**Create:** `Titonium/Services/Appearance/LegacyThemeCatalog.js`, `scripts/check_design_styles.js`.

**Modify:** `ThemeCatalog.js`, `AppearanceRules.js`, `AppearanceService.qml`, `config/defaults/settings.json`, `config/schemas/settings.schema.json`, `scripts/validate_config.py`, `Titonium/Settings/AppearanceTransaction.js`; cập nhật `check_appearance_rules.js`, `check_preferences.js`, `check_settings_schema.py`, `check_appearance_transaction.js`.

**Interfaces:** `ThemeCatalog.catalog()` → 5 public descriptors; `lookup(id)` → public/legacy descriptor hoặc null; `AppearanceRules.resolve(appearance, systemMode, reducedMotion)` → snapshot spec §6.2. Descriptor có `legacy`, `design`, `variants`, `wallpapers`.

- [ ] Viết failing test bằng harness Node vm hiện có. New test load production JS bằng cùng cách remove `.pragma/.import`, inject dependency contexts, không viết fake resolver.

```js
const ids = Array.from(catalog.catalog(), x => x.id);
assert.deepEqual(ids, ['glassmorphism', 'material', 'liquid-glass',
  'modern-flat', 'neumorphism']);
const flat = rules.resolve({themeId:'modern-flat',mode:'dark'}, 'light', false);
const soft = rules.resolve({themeId:'neumorphism',mode:'dark'}, 'light', false);
assert.equal(flat.design.depthTreatment, 'none');
assert.equal(soft.design.depthTreatment, 'dual-shadow');
assert.equal(soft.design.fieldTreatment, 'inset');
assert.equal(rules.resolve({themeId:'liquid-glass'},'dark',false)
  .design.requiredBackdrop, 'refraction');
```

- [ ] Chạy `node scripts/check_design_styles.js`, xác nhận fail vì thiếu contract. Sau đó giữ nguyên bốn legacy palettes/materials bằng extraction vào LegacyThemeCatalog, không sửa số liệu trong extraction.
- [ ] Implement public descriptors theo spec matrix; `lookup` dùng kiểm tra own/allowlist tránh `constructor`/`__proto__`. Normalize lấy allowed IDs từ source chung; schema/Python validator đồng bộ explicit enum. Không bỏ legacy override.
- [ ] Giữ v6/v7 migration Neutral, v8 legacy chính xác; fresh defaults Modern Flat. Đừng sửa Dock projection hoặc schemaVersion chỉ để thêm ID. Assert lỗi malformed theme về documented fallback.
- [ ] Chặn custom thay structural treatment: Flat luôn không shadow/sheen, opaque styles opacity 1; vẫn preserve unused override. Existing legacy numeric clamps không đổi.
- [ ] Test 10 style/mode pairs, System unknown→Dark, finite numeric boundaries, accent text/foreground contrast, no input mutation, override isolation, legacy exact snapshot và không đổi modules khi merge:

```js
const settings = {appearance:{themeId:'neutral'}, modules:{
  bar:{style:'connected',height:44}, dock:{style:'follow-topbar'}},
  accessibility:{reducedMotion:false}};
const base = transaction.pick(settings);
const next = transaction.mergeCandidate(settings, base, {
  appearance:{themeId:'material',mode:'dark'},reducedMotion:false});
assert.deepEqual(JSON.parse(JSON.stringify(next.modules)), settings.modules);
```

- [ ] Run focused rules/preferences/schema/transaction tests, review diff. Register new script in check.sh at task 8 after it passes.

**Acceptance:** 5 public styles, private old configs lossless, structural distinction testable independently of colors, existing transaction API unchanged.

## Task 3 — Paint host, state và motion boundary

**Create:** `Titonium/Shared/StylePaint.qml`, `Titonium/Shared/StyleRules.js`, `Titonium/Shared/StyleFocusRing.qml`, `scripts/check_style_rules.js`, `scripts/check_style_controls.py`, `scripts/fixtures/style_controls/tst_styles.qml`.

**Modify:** `Titonium/Shared/qmldir`, `Titonium/Theme/Theme.qml`, `Titonium/Theme/Motion.qml`.

**Interfaces:** StylePaint nhận tokens/role/state/geometry/backdropCapability theo spec. `StyleRules.paint(tokens, role, state)` trả `{fill, foreground, outline, depthTreatment, inset, stateLayerOpacity}`; `controlMotion(tokens)` trả `{durationMs, curve, pressScale}`. `StyleFocusRing` nhận focused/enabled/radii/focusColor, luôn ở ngoài material opacity.

- [ ] Thêm failing pure tests: neumorphic field inset dù không hover; pressed button inset; selected luôn có indicator contrast; disabled không hover/ripple; reduced duration zero. Không chỉ assert tên renderer.
- [ ] Thêm QML test thực về focus/value preservation, dùng contract consumer có TextInput và Button bên ngoài paint Loader:

```qml
function test_style_switch_preserves_editing() {
    editor.text = "Titonium";
    editor.forceActiveFocus();
    editor.select(1, 4);
    var focused = editor.activeFocus;
    specimen.tokens = specimen.resolve("neumorphism", "dark");
    wait(20);
    compare(editor.text, "Titonium");
    compare(editor.selectionStart, 1);
    compare(editor.selectionEnd, 4);
    compare(editor.activeFocus, focused);
}
```

`specimen.resolve(id,mode)` là helper fixture gọi production AppearanceService.resolveCandidate; `editor` là TextInput thật trong specimen. Fixture không fake StyleRules hoặc StylePaint.

- [ ] Run red tests, implement state resolver + paint-only Loader. Tạo stub renderers chỉ trong test fixture khi kiểm tra host lifecycle; khi kiểm tra actual style phải dùng production renderer.
- [ ] Thêm `Theme.design` facade. Thêm `Motion.controlDuration`/`controlCurve`/`controlPressScale` bằng StyleRules; giữ `fast/normal/slow` cho layout tương thích. New style `motionScale` không đi vào layout; legacy motion giữ behavior cũ. Kiểm tra theme switch không thay normal/slow của layout đối với năm styles mới.
- [ ] Verify runtime không đọc service từ renderer value-only; Loader không bao content hoặc handlers, không own Timer/Process; ring còn rõ khi borderStrength=0.

**Acceptance:** thay paint không mất focus/caret/value, không đổi bounds; Reduced Motion hoạt động giữa animation; motion layout invariant.

## Task 4 — Flat, Material, Neumorphism trên component specimen

**Create:** `Titonium/Shared/styles/{qmldir,FlatPaint.qml,MaterialPaint.qml,NeumorphicPaint.qml}`, `scripts/fixtures/style_controls/StyleSpecimen.qml`.

**Modify:** StylePaint dispatch, style control tests.

**Consumes:** normalized tokens/roles/states. **Produces:** ba renderer thật, không duplicated interaction logic.

- [ ] Failing QML behavior/render checks: Flat shadow absent; Material depth/state layer changes on press; Neumorphism light/dark shadow pair và raised→inset. Test focus independent và same geometry trên mỗi state.
- [ ] Implement Flat trước để có baseline renderer. Material dùng bounded elevation + tonal roles; press ripple clip trong shape, không loop. Neumorphism pair shadows cho rect + inset field treatment; sử dụng Qt Effects chỉ sau GPU/software fixture chứng minh hỗ trợ.
- [ ] Specimen cùng palette/size/content: panel, button primary/secondary/quiet, field, toggle, slider, menu row; các state rest/hover/pressed/selected/focus/disabled. Component được dùng runtime, không một mockup riêng.
- [ ] Run `python3 scripts/check_style_controls.py`; xuất ảnh Light/Dark bằng grabImage dưới temp artifact path. Test CPU/offscreen fallback riêng với GPU path; không suy ra GPU đúng chỉ từ software test.
- [ ] Review ảnh: khác biệt phải rõ khi đổi cùng accent và khi chuyển grayscale. Tune số liệu spec trong diff có ghi lý do; không đổi metrics layout để làm screenshot đẹp.

**Acceptance:** ba style khác cấu tạo control và depth, đủ states, no new idle animation.

## Task 5 — Frosted và Liquid, tích hợp backend có điều kiện

**Create:** `Titonium/Shared/styles/FrostedPaint.qml`, `LiquidPaint.qml`; nếu native gate đạt mới tạo `Titonium/Services/Glass/{qmldir,GlassService.qml,GlassRules.js}` và `scripts/check_glass_rules.js`, `scripts/check_glass_service.py`.

**Modify:** StylePaint, specimen/tests, AppearanceCoordinator chỉ khi cần effect lease; service composition thêm đúng một activation theo kiến trúc repo.

**Consumes:** task 1 verdict + exact API/revision. **Produces:** hai local renderers và capability evidence. Không tạo inert Glass service nếu chỉ có fallback.

- [ ] Failing renderer tests: frosted không lens treatment, liquid có bezel/specular riêng; text opacity 1; missing capability dùng opaque-safe treatment; style preference không bị đổi khi capability mất.
- [ ] Implement QML treatments theo spec; không dùng screenshot texture của desktop. Scene mẫu trong preview có thể cung cấp item texture nhưng ghi rõ demonstration.
- [ ] Nếu native-ready/blur-only, định nghĩa concrete service adapter từ API đã kiểm chứng. Unit-test argv/request allowlist, per-owner generation, out-of-order callbacks, unsupported version, backend loss và no-global-effects trước native calls.
- [ ] Nếu adapter mutate runtime effect, implement lease `prepare(candidate,generation)`, `activate(generation)`, `restore(generation)`, `finalize(generation)` với signals có generation; `prepare` trả baseline handle hoặc failure, không success trước capture baseline. Một lease cho toàn Appearance transaction; timeout/cancel/owner-loss/save-failure restore trước release. Rollback failure hiển thị và cho retry, không báo restore xong.
- [ ] Fixture fake backend phải chứng minh cycle:

```text
capture old → activate liquid → Keep → save failure → restore old
capture old → activate liquid → timeout → restore old
capture old → activate liquid → Apply success → finalize once
stale activate success → ignore logical commit → reconcile current desired state
```

- [ ] Nếu không có native gate, ghi phần fidelity chưa đạt và thực hiện renderer/fallback độc lập. Chuẩn bị dependency decision; không đánh dấu task native completed.
- [ ] Native manual probe: background pattern chuyển động, connected morph, Flat disable, resource release; lưu before/after và frame data.

**Acceptance:** hai style không chỉ khác palette; native claims tương ứng verdict/evidence; không có compositor mutation chưa được review.

## Task 6 — Gắn Shared controls, audit consumer, giữ API

**Modify:** `Titonium/Shared/{Surface,Panel,Button,Toggle,Slider,Select,InteractionFeedback}.qml`; `Titonium/Settings/components/SettingRow.qml` khi có chrome; thêm `FieldPaint.qml` + qmldir nếu giúp tái dùng background của Qt TextField mà không thay control semantics.

**Tests:** existing `check_shared_controls.py`, `check_appearance_material.py`, `check_interaction_feedback.js`, new style control suite.

- [ ] Thêm failing event tests mỗi control: một click một signal; Tab/Space/Enter; disabled; slider drag/keyboard; ComboBox open/select/Escape; background opacity không giảm text/icon.
- [ ] Replace riêng background/track/thumb/delegate paint. Giữ tất cả signals, activate(), checkable/autoToggle, selected, contentAlignment, explicit backgroundRadius, accessibility roles và value binding. Không thay QML root type của consumer nếu phá alias/property contract.
- [ ] Surface/Panel chuyển default radius về style, explicit per-corner radius giữ nguyên; shadow clip có chủ đích, focus ring nằm trên mọi sheen layer.
- [ ] Audit `rg -n 'Rectangle|background:|#[0-9a-fA-F]{6}|border.width|radius:' Titonium/Settings Titonium/Bar Titonium/Dock Titonium/Overlays Titonium/Notifications` và ghi bảng path/role/decision trong QA doc. Đừng blanket replace Rectangle.
- [ ] Run focused suites; cập nhật static tests chỉ nơi contract presentation chủ đích thay đổi, không xóa behavioral test để đạt green.

**Acceptance:** APIs không đổi, focus và control semantics giữ nguyên, không double-painted background, không copy renderer logic vào từng consumer.

## Task 7 — Appearance cards, preview chung renderer, Advanced và persistence

**Modify:** `Titonium/Settings/pages/AppearancePage.qml`, `components/{ThemePreview,ThemeCard,AppearanceAdvanced}.qml`, `AppearanceCoordinator.qml`, `AppearanceTransaction.js`, `config/i18n/{en,vi}.json`.

**Tests:** `scripts/fixtures/appearance_ui/tst_appearance.qml`, `check_appearance_ui.py`, `check_appearance_coordinator.py`, `check_appearance_transaction.js`; wallpaper existing tests.

- [ ] Failing UI tests: đúng 5 public cards, legacy current notice ngoài cards, label Liquid Glass/Glassmorphism không bị cắt, narrow 2-column/wide 3-column. Card keyboard selects local candidate only.
- [ ] ThemePreview dùng StylePaint/actual controls với explicit tokens; layout-preview local mặc định từ current layout nhưng có thể toggle mà không ghi Settings. Stub chỉ native services trong fixture, không stub renderer.
- [ ] Advanced lấy field availability từ style, giữ pinned edit mode; accent nằm riêng, reset từng field/style đúng scope. Opaque styles không expose opacity slider như active setting. Existing legacy controls giữ compatibility.
- [ ] Wallpaper dependency: style thiếu pair → UI cho chọn keep trước khi startTrial/Apply; điều chỉnh guard và copy để không gọi beginAppearance với empty path. Candidate còn policy theme thì Try/Apply disabled kèm action rõ, không silently patch persisted settings. Custom/keep không bị đổi khi chọn style.
- [ ] Test local select, trial, deadline, Keep, Cancel, Apply failure/retry, finalization retry, undo, unrelated page dirty, monitor loss, reduced-motion changes; lưu và load new IDs qua actual Preferences fixture.

```js
for (const id of ['glassmorphism','material','liquid-glass','modern-flat','neumorphism']) {
  const candidate = {appearance:{themeId:id,mode:'dark'},reducedMotion:false};
  const edited = transaction.override(candidate, 'dark', 'accent', '#12ab56');
  assert.equal(edited.appearance.themeOverrides[id].dark.accent, '#12ab56');
  assert.equal(candidate.appearance.themeOverrides, undefined);
}
```

- [ ] Run existing appearance + wallpaper test family; verify i18n parity. No native media/network/volume/wallpaper side effects từ preview.

**Acceptance:** UI phản ánh renderer thật và backend thực; chọn card không mutate runtime; Apply/Cancel/Undo giữ contract; legacy appearance không tự đổi.

## Task 8 — Shell integration, Connected/Classic invariants và QA

**Modify paint only:** `Shared/ConnectedPillShape.qml`, `Shared/AnchoredMenuPillShape.qml`; chrome dưới `Bar/center`, `Bar/classic`, `Bar/right/EdgeMenuSurface.qml`, `Dock/DockSurface.qml`, `Dock/DockItemMenuSurface.qml`, `Settings/SettingsWorkspace.qml`, popup surfaces/rows dưới Overlays, `Notifications/ToastCard.qml` và history; protected Spotlight/Switcher background theo coverage.

**Create:** `scripts/check_style_layout_contract.js`, `scripts/check_style_layout_ui.py`, `docs/DESIGN_STYLES_QA.md`.

**Modify docs/gates:** `scripts/check.sh`, `docs/THEMING_AND_GLASS.md`, `docs/ARCHITECTURE.md`, `docs/TESTING.md`.

- [ ] Failing layout fixture trước integration: store connected bodyWidth/bodyHeight/safeRadius, anchored attachmentX/branch bounds và Classic rect; đổi 5 styles/2 modes và compare snapshot. Assert renderer/content instance identity, focus owner và active descriptor generation.
- [ ] Apply paint to exact shared path; không duplicate path topology. Test clipped shadow vùng concave và frame morph trung gian, không chỉ mở xong. Classic giữ detached spacing và mask.
- [ ] Consumer checklist đủ nhóm spec §9; mỗi raw Rectangle còn lại ghi intentional content/chrome exception. Giữ app icons/artwork/mascot colors.
- [ ] Capture 40 specimen combinations (5×2×2×2 scale), actual shell captures cho từng nhóm/2 layout; thêm System, Reduced Motion, fallback/backend-loss, long Vietnamese text và keyboard. Ghi tên capture chứa style/layout/mode/scale/state.
- [ ] Run performance protocol spec §10 so với task 0, 20 cycles resource checks; record p95/CPU và verdict theo budget. Nếu chưa có GPU counter thì ghi unknown, không suy từ screenshot.
- [ ] Đăng ký pure/QML tests mới trong check.sh. Chạy full required gates từ snapshot phù hợp:

```bash
./scripts/check.sh
./scripts/smoke.sh
./scripts/protected_acceptance.sh
hyprctl configerrors
```

- [ ] Review diff chỉ file task, verify no change to protected config hashes/unrelated work. Chuyển implementation đã test về main workspace theo source hash, không overwrite file đã đổi đồng thời; re-run focused integration sau chuyển.
- [ ] QA doc có từng requirement: implemented / automated / visual / limitation, paths/logs/exit code/source revision, native verdict và regression notes. Ghi phần skip tường minh.

**Acceptance:** Connected/Classic invariant có evidence, các gates đạt hoặc limitation được báo đúng, bộ năm styles đủ state/consumer coverage. Nếu native glass chưa đạt thì kết quả vẫn là partial đối với full scope, không đánh dấu toàn bộ task complete.

## Self-review của bản kế hoạch

- 5 styles: task 2/4/5; component states: task 3/4/6.
- Connected/Classic, geometry và layout motion: task 3/8.
- Legacy/config/overrides: task 2/7; transaction/wallpaper: task 5/7.
- Glass feasibility/version/license: task 1; actual native evidence: task 5/8.
- Preview cùng renderer/i18n/Advanced: task 7.
- Required checks, visual/performance, protected boundaries: task 0/8.
- Việc chưa được giải quyết bằng plan: backend native chưa đạt feasibility gate; không giả định API hoặc tự nới phạm vi compositor. Task 1 phải biến bất định này thành quyết định có evidence trước adapter production.
