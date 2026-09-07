# Appearance Themes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai Settings → Appearance với theme, Dark/Light/System, preview an toàn, wallpaper và Advanced custom ngay trong cùng phạm vi.

**Architecture:** Mở rộng Preferences transaction hiện có; một Appearance service resolve token, Theme là facade semantic không I/O. AppearanceCoordinator tách candidate/trial khỏi giao dịch Settings; một Wallpapers service sở hữu tích hợp Hyprpaper và phục hồi side effect.

**Tech Stack:** QtQuick/QML, JavaScript thuần theo Node/vm fixtures hiện có, Quickshell, Hyprpaper v0.8.4 cài tại máy. Không thêm framework/theme engine.

**Spec:** `docs/superpowers/specs/2026-09-06-appearance-themes-design.md`.

## Global Constraints

- Runtime data ngoài Git. Không đọc, sửa hoặc reload hai file hyprland.lua từ theme.
- UI không sở hữu Process, FileView, lệnh shell hoặc persistence; Services không import feature views.
- Mỗi thư mục QML có qmldir, import qs.Titonium.*, mọi chuỗi UI qua I18n.tr().
- Giữ Spotlight/keybind, Input Method, screen lifecycle và lazy overlays theo AGENTS.md.
- Theme là facade semantic không I/O; runtime listener chỉ có một owner ở Services.
- Chỉ DP-1 theo ScreenPolicy; DP-3 không đổi. Không launch app, ghi clipboard hoặc thay wallpaper thật trong automated tests.
- Reduced Motion ưu tiên hơn mọi custom animation; không shader, MultiEffect hoặc animation vô hạn mới.
- Worktree hiện có nhiều sửa đổi chưa commit: không reset, không stage toàn bộ, không ghi đè công việc song song.
- Khi thực thi, đọc lại AGENTS.md, ARCHITECTURE.md, MODULE_CONTRACT.md, CODING_FLOW.md, TESTING.md và diff các file đụng tới.

## Hiện trạng đã kiểm tra

- AppearancePage.qml đã có Dark/Light và restoreAppearance().
- Preferences.qml có committedState, previewState, effectiveState, atomicWrites và Apply callback; SettingsCoordinator quản lý Apply/Cancel chung.
- Theme.qml hiện có semantic Light/Dark; Motion.qml đã hỗ trợ reducedMotion.
- Connected/Classic là modules.bar.style, dock có follow-topbar; không phải theme ID.
- Chưa có catalog, material resolver, system-mode adapter hoặc Wallpapers service trong cây đã kiểm tra.
- Plan Center ngày 2026-09-06 cũng đề xuất Services/Wallpapers. Task wallpaper dưới đây bổ sung kỹ thuật cho dependency chung đó; kiểm tra lại cây trước khi tạo để tránh trùng.

## Task 1 — Schema v8 và migration giữ nguyên người dùng hiện tại

**Điều chỉnh thứ tự sau audit concurrent 2026-09-06:** trước khi chạy Task 1, làm catalog/resolver thuần, reducer trial và fixture riêng trong checkout cách ly. Task 1 và wiring runtime chỉ tích hợp sau khi đối chiếu thay đổi của Center. Xem phần Parallel ownership cuối tài liệu.

**Files sửa:** `config/defaults/settings.json`, `config/schemas/settings.schema.json`, `Titonium/Core/Runtime/PreferencesValidator.js`, `Titonium/Core/Runtime/Preferences.qml`, `scripts/check_preferences.js`, `scripts/validate_config.py`; tạo `tests/fixtures/settings-v8-runtime.json`.

**Contract:** project(document, defaults, legacyDock) vẫn trả full settings; v8 thêm cấu trúc dưới đây. V7 thiếu themeId được migrate sang neutral, giữ nguyên mode; v6 Dock migration vẫn chạy. Dock subtree của v7 **và v8** phải được ưu tiên hơn legacyDock.

```json
{
  "appearance": {
    "mode": "dark",
    "themeId": "neutral",
    "themeOverrides": {},
    "wallpaper": { "policy": "keep", "customPath": "" }
  }
}
```

Allowed mode: dark/light/system. Theme IDs: neutral/glass/soft/graphite. Wallpaper policy: keep/theme/custom. Theme overrides dùng key theme ID rồi key dark/light; chỉ nhận các field Advanced trong spec, clamp số hữu hạn, loại key lạ/prototype keys. Mode/theme sai về defaults; file wallpaper không tồn tại được phát hiện ở service, không xóa lựa chọn im lặng trong validator.

- [ ] Mở rộng fixture test v6/v7/v8 trước; đổi kỳ vọng version, thêm round trip, invalid values và bảo toàn modules.
- [ ] Implement normalization schema/defaults/migration đồng bộ; cập nhật các check hard-code v7 bằng `rg -n 'settings/v7|schemaVersion.*7|v7' scripts config Titonium/Core`.
- [ ] Chạy `node scripts/check_preferences.js` và `python3 scripts/validate_config.py`; các giá trị cũ của Dock, locale, notifications, accessibility không đổi.

Fixture cốt lõi thêm vào harness vm hiện có:

```js
const next = context.project({ ...current, appearance: {
  mode: 'system', themeId: 'glass', themeOverrides: {},
  wallpaper: { policy: 'keep', customPath: '' }
}}, defaults, legacyDock);
assert.equal(next.schemaVersion, 8);
assert.equal(next.appearance.mode, 'system');
assert.equal(next.appearance.themeId, 'glass');
assert.deepEqual(plain(next.modules.dock), plain(currentProjection.modules.dock));
assert.equal(context.project(current, defaults, legacyDock).appearance.themeId, 'neutral');
```

## Task 2 — Catalog, resolver và System mode

**Tạo:** `Titonium/Services/Appearance/{qmldir,AppearanceService.qml,AppearanceRules.js,ThemeCatalog.js}`, `scripts/check_appearance_rules.js`.
**Sửa:** `Titonium/Theme/Theme.qml`, `Titonium/Theme/Motion.qml`, `Titonium/Orchestration/ServiceBootstrap.qml` nếu cần activation.

**Interfaces:** ThemeCatalog.catalog() trả mảng descriptor `{id,nameKey,variants:{light,dark},wallpapers:{light,dark}}`; mỗi variant chứa đầy đủ token hiện có của Theme.qml và material tokens. AppearanceRules.resolve(appearance, systemMode, reducedMotion) trả `{themeId,mode,colors,material,motionScale}` không mutate input. systemMode là light/dark/unknown.

AppearanceService có readonly systemMode và tokens; setTrial(candidate, generation) / clearTrial(generation) chỉ thay runtime overlay. Candidate là `{appearance,reducedMotion}` như Task 5, để preview Reduced Motion không ghi draft toàn cục. Thứ tự resolve: candidate trial hoặc appearance/accessibility từ Preferences.effectiveState → preset variant → custom theo theme/mode → accessibility constraints. Theme.qml chỉ bind service snapshot, giữ tên property để consumers không phụ thuộc provider. Motion.reduced đọc effective reducedMotion từ service, nên cả trial và settings committed đều có hiệu lực.

- [ ] Viết test resolver: system unknown→dark; explicit light thắng system dark; override chỉ ảnh hưởng theme/mode tương ứng; accentText rõ; reducedMotion thắng motionScale; thiếu token dùng Neutral.
- [ ] Dùng binding event-driven `Qt.styleHints.colorScheme` trong service; không đặt ngược property platform, không polling, không import Theme gây vòng phụ thuộc. Qt metadata local đã có property, vẫn phải qmllint/runtime verify.
- [ ] Đưa palette hiện có vào neutral; tạo Glass đủ Light/Dark đầu tiên. Soft/Graphite hoàn thiện ở Task 7 trước khi công khai cards.
- [ ] Chạy `node scripts/check_appearance_rules.js`, check preferences và qmllint qua `./scripts/check.sh`.

## Task 3 — Material dùng chung, giữ geometry và functional state

**Sửa:** `Titonium/Shared/Surface.qml`, `Panel.qml`, `InteractionFeedback.qml`, `ConnectedPillShape.qml`, `AnchoredMenuPillShape.qml`, `Titonium/Theme/Metrics.qml` nếu cần token facade mới; consumers có màu/outline hard-code trong Bar, Dock và Overlays chỉ sửa presentation tương ứng.
**Tạo:** `scripts/check_appearance_contract.js`.

**Contract:** material có backgroundOpacity, borderStrength, shadowStrength, sheenStrength, radiusScale. Background alpha chỉ áp dụng vào paint, không opacity root. Shadow dùng primitive/gradient tĩnh; Connected dùng đúng một continuous ShapePath, không tạo nền lồng hoặc thay input mask.

- [ ] Kiểm tra hard-code bằng `rg -n '#[0-9a-fA-F]{6}|customColor|opacity:|border.width' Titonium/Bar Titonium/Dock Titonium/Overlays Titonium/Notifications Titonium/Shared` và phân biệt màu nội dung cố ý với chrome theme.
- [ ] Bổ sung contract test theme không đổi modules.bar.style/dock.style, không load lại domain/host, không thêm listener ở view.
- [ ] Áp dụng material vào primitive dùng chung, giữ silhouette và explicit geometry của Connected; hover/focus dùng semantic tokens. Không nhân radiusScale vào Metrics bar/screen/shape geometry.
- [ ] Chạy `node scripts/check_appearance_contract.js`, `node scripts/check_notification_theme_contract.js`, `node scripts/check_interaction_feedback.js`, `node scripts/check_top_bar_style_lifecycle.js`.

## Task 4 — Wallpaper service dùng chung và phục hồi

**Mở rộng sau khi owner Center bàn giao:** `Titonium/Services/Wallpapers/{qmldir,WallpapersService.qml,wallpapers.py}` đã được tạo trong lúc audit. Không tạo `WallpaperService.qml` hoặc `wallpaper_io.py` song song. Có thể thêm `WallpaperRules.js` và fixture riêng khi ownership rõ; giữ `scripts/check_wallpapers.py` hiện có và bổ sung coverage transaction.

**Interfaces đích:** WallpapersService giữ các API Center đang dùng: setVisible(consumer,visible), refresh(path), applyTo(screenName,path), items, applied, busy, statusKey. Bổ sung lastError, activeByScreen, capture(screenName,generation), apply(screenName,path,generation), restore(snapshot,generation) và signal result(generation,success,snapshot,error); không đổi hành vi applyTo để ép Center vào transaction Settings. Snapshot chứa screenName/path/fit đủ để phục hồi, chỉ nhận đường dẫn local đọc và decode được. Generation cũ không cập nhật desired state; mọi tác vụ per-screen tuần tự để stale side effect được sửa về desired mới nhất.

**Khoảng cách cần tích hợp:** applyTo hiện yêu cầu active consumer và path nằm trong catalog; theme assets không tự thỏa điều kiện này. Backend apply hiện persist ngay sau đổi ảnh và coi lỗi persistence là warning. Trial Themes phải có đường tạm không persist; capture/restore và journal chưa nằm trong API đã quan sát. Cần cùng một transaction lease giữa Center và Themes: khi Themes giữ trial, Center vẫn đọc catalog nhưng Apply wallpaper bị khóa với lý do rõ; rollback chỉ chạy khi generation/ownership còn hợp lệ. Không để Cancel Themes ghi đè wallpaper vừa được Center áp dụng.

- [ ] Xác minh read-only phiên bản, daemon, IPC get-active và fit của Hyprpaper v0.8.4; lưu commands thực đã kiểm tra trong docs/THEMING_AND_GLASS.md. Không dùng cú pháp latest khi chưa đối chiếu bản cài.
- [ ] Viết test bằng backend giả: path có space/ký tự shell, file mất, decode lỗi, daemon mất, timeout, màn hình mất, callback cũ, snapshot không đọc được và rollback lỗi. Các subprocess được truyền argv, timeout 5 giây; không gọi backend live trong test.
- [ ] Implement ảnh preset Light/Dark và file picker custom, policy keep mặc định. Chỉ quét khi mở picker, giới hạn thư mục mặc định `~/Pictures/Wallpapers`; catalog preset dùng asset của app có provenance/license. Không sao chép wallpaper không rõ quyền.
- [ ] Implement capture/apply/restore cùng recovery journal ngoài Git. Nếu không chụp được baseline thì khóa thao tác có thay wallpaper, vẫn cho dùng keep và theme colors.
- [ ] Startup: committed config chọn keep thì không chạm wallpaper; policy explicit chỉ phục hồi trên màn hình eligible sau backend ready. System mode chỉ đổi ảnh khi policy theme; custom giữ nguyên.
- [ ] Chạy `python3 scripts/check_wallpapers.py` hiện có và fixtures transaction mới đăng ký ở Task 7. Giữ tương thích Center với service chung này.

## Task 5 — Draft, trial, Apply và undo không làm mất settings khác

**Tạo:** `Titonium/Settings/AppearanceCoordinator.qml`, `AppearanceTransaction.js`, `scripts/check_appearance_transaction.js`.
**Sửa:** `Titonium/Settings/{qmldir,SettingsCoordinator.qml}`, `Titonium/Core/Runtime/Preferences.qml` cho transactional patch đồng bộ khi cần.

**Interfaces:** coordinator có candidate, trialActive, deadline, busy, error; selectTheme(id), setMode(mode), setOverride(key,value), resetOverride(key), resetThemeOverrides(), startTrial(), keepTrial(), cancelTrial(), stageCandidate(), undoLastApply(). Candidate là `{appearance,reducedMotion}`; reducedMotion luôn lưu ở accessibility.reducedMotion qua Preferences.

Trial baseline là effective Appearance cùng reducedMotion và wallpaper snapshot ngay trước trial, không phải bản committed toàn cục. Trial runtime override dùng service; selected card không gọi Preferences.patch trực tiếp. Một generation/deadline 15 giây; keepTrial stage candidate vào Settings draft rồi gỡ runtime override trong cùng lượt để không flash.

- [ ] Viết pure reducer fixtures cho choose→trial→timeout, trial→keep→Cancel, Apply success/fail, unrelated setting dirty, savePending, session lock, monitor loss, stale callbacks, Reduced Motion và undo sau restart (không khả dụng).
- [ ] Stage candidate theo batch trong Preferences để appearance và accessibility đổi đồng thời; chỉ merge subtree liên quan, bảo toàn các draft khác. Đóng Advanced không xóa overrides.
- [ ] Nút Apply chung stage Appearance candidate trước nếu đang ở Appearance. Apply trang khác dùng draft đã stage; bản nháp local Appearance được giữ trong Settings session và vẫn được stage khi Apply toàn cửa sổ. Disable Apply trong trial; timeout chỉ hủy trial, candidate còn để sửa.
- [ ] Apply có wallpaper: journal baseline → apply wallpaper → Preferences.apply atomic → callback success cập nhật undo baseline và dọn journal; callback fail phục hồi wallpaper, giữ draft, hiện lỗi. Apply không wallpaper dùng đường ghi hiện có. Không báo thành công chỉ vì apply() trả true.
- [ ] Undo chỉ khi không dirty/busy, lưu lại Appearance/accessibility đã thay trong giao dịch appearance gần nhất và wallpaper baseline; merge vào settings committed mới nhất. Failed undo giữ mốc để retry. Journal phục hồi sau crash dựa trên config persisted thực, không dựa flag RAM.
- [ ] Chạy `node scripts/check_appearance_transaction.js` và `./scripts/settings_acceptance.sh` trong runtime tạm; fake failure tại write callback và wallpaper adapter.

## Task 6 — Basic và Advanced UI đầy đủ

**Sửa:** `Titonium/Settings/pages/AppearancePage.qml`, `SettingsWorkspace.qml`, `config/i18n/{vi,en}.json`.
**Tạo:** `Titonium/Settings/components/{ThemeCard.qml,ThemePreview.qml,AppearanceAdvanced.qml}` và entries qmldir; mở rộng `scripts/check_settings_pages.py`.

**Contract:** ThemeCard nhận descriptor + selected + applied, emit selectedTheme(id). ThemePreview nhận explicit resolved candidate tokens, không đọc global Theme cho nội dung preview, không screenshot màn hình và không instantiate services/domain thật. AppearanceAdvanced nhận mode-specific override values, emit field edits; Loader.active theo trạng thái mở.

- [ ] Layout cuộn trong Settings hiện có: Mode → preview → theme cards → wallpaper → Advanced; footer Apply/Cancel chung. Thêm trạng thái Đang dùng, Đang chỉnh và Đang xem thử; không đánh dấu applied trước save callback.
- [ ] Controls Advanced: accent picker/input; opacity 85–100%; border/shadow/sheen 0–100%; radius 75–125%; motion 50–150%; Reduced Motion. Giới hạn/clamp cùng validator; mỗi field có reset, theme có reset-all; custom editor sửa mode đang hiển thị, System hiển thị rõ Light/Dark resolved.
- [ ] Lúc system đổi trong khi sửa Advanced, giữ editMode tại mode bắt đầu chỉnh đến khi user chuyển mode để tránh ghi override vào nhánh khác ngoài ý muốn.
- [ ] Preview minh họa wallpaper + bar + panel + text + selected/focus states. Asset loading thất bại có placeholder; lỗi wallpaper có retry và lựa chọn giữ ảnh hiện tại.
- [ ] Keyboard navigation, Escape trial, focus ring, accessible names và i18n parity. Advanced đóng/mở không thay persisted settings.
- [ ] Chạy `python3 scripts/check_settings_pages.py`, `python3 scripts/check_settings.py` và focused Settings acceptance.

## Task 7 — Preset còn lại, acceptance và tài liệu

**Sửa:** `ThemeCatalog.js`, `scripts/check.sh`, `docs/{THEMING_AND_GLASS.md,ARCHITECTURE.md,TESTING.md}`; bổ sung assets theo thư mục Theme/assets hiện có và provenance vào README của assets.

- [ ] Hoàn thiện Soft/Graphite với cùng token contract, Light/Dark và wallpaper pair; giữ Neutral nguyên appearance cũ. Test mọi catalog variant resolve đủ token, range hợp lệ và palette đủ độ tương phản trên các nền được hỗ trợ.
- [ ] Đăng ký toàn bộ checks mới vào check.sh; cập nhật baseline docs để phân biệt facade semantic với resolver trong Services. Không nới test kiến trúc hàng loạt để pass.
- [ ] Chạy gates: `./scripts/check.sh`, `./scripts/smoke.sh`, `./scripts/protected_acceptance.sh`, `./scripts/settings_acceptance.sh`, `hyprctl configerrors`. Ghi pass/fail/skip đúng thực tế; phân biệt lỗi baseline với regression.
- [ ] Live review trên runtime tạm: Connected/Classic × Light/Dark/System × scale 1/1.5; Bar, Dock, Center compact/banner/expanded, notifications, Settings, popups, Spotlight và Switcher. Không thay hoạt động đang chạy chỉ để tạo demo.
- [ ] Kiểm tra chuyển mode khi audio/media/timer đang hoạt động không reset domain; Advanced radius không gây seam/hitbox sai; Reduced Motion kết thúc animation; idle không có repaint/polling liên tục.
- [ ] Kiểm tra Apply/restart, timeout rollback, read-only save failure, daemon unavailable và crash journal bằng harness cách ly. Không tuyên bố wallpaper transaction hoàn tất nếu chỉ test happy path.

## Mốc bàn giao

1. Schema/resolver + Glass Light/Dark/System hoạt động trên surface hiện có.
2. Basic và Advanced, draft/trial/Apply/Cancel/undo cùng wallpaper service và recovery hoạt động.
3. Soft/Graphite, toàn bộ gates và visual acceptance.

Cả ba mốc thuộc plan này. Advanced là tính năng cho người dùng custom, không phải một plan kỹ thuật bị để lại sau. Đây là tài liệu triển khai; chưa thay code runtime hoặc cấu hình người dùng trong phiên lập plan.

## Parallel ownership — audit 2026-09-06

Task đang active: **Chuẩn hóa giao diện QuickShell bar** (`01a075f0-bbb4-73c2-9cdd-03819514ecdf`), thực tế đang triển khai Center Banner/Expanded, tab contents và Wallpapers. Task **Thiết kế luồng chuyển state 1 đến 4** đã idle sau hoàn tất Compact/capture; **Lên plan Today Focus Banner** đang idle. Tên task không đủ xác định scope; các kết luận dựa trên turn gần nhất và file thực.

Repo chỉ có checkout main tại `/home/cole/Projects/titonium`; các task đều trỏ workspace `/home/cole/Projects`. Git không có unmerged entries và diff --check qua tại thời điểm audit. Điều đó không bảo đảm tránh ghi đè hoặc conflict hành vi khi nhiều worker dùng cùng filesystem. File clean chỉ có nghĩa chưa khác HEAD, không phải đã được dành riêng cho Themes.

| Phạm vi | Trạng thái/rủi ro | Cách làm |
|---|---|---|
| Services/Appearance mới, pure catalog/resolver, AppearanceTransaction.js, fixtures riêng | Chưa tồn tại tại audit; ít overlap trực tiếp | Làm trước trong checkout cách ly, chưa wiring shell |
| Settings Appearance UI và components mới | Các entry hiện clean; phụ thuộc i18n, Preferences, tokens | Có thể xây/test cách ly với explicit preview data |
| Bar/center, Core/Surfaces/Center, renderers, SurfaceRouter | Center đang sửa state/geometry/lifecycle | Để Center sở hữu trong đợt active |
| Services/Wallpapers và check_wallpapers.py | Center vừa tạo; overlap trực tiếp với Task 4 | Dùng service plural hiện có, chờ API ổn định rồi bổ sung transactional adapter |
| Theme.qml, Motion.qml, Metrics.qml, Shared Surface/Shape/feedback | Shared runtime dependency; Metrics đã dirty | Tích hợp sau checkpoint Center; token đổi có thể làm test/visual của Center thay đổi dù khác file |
| Preferences, validator, defaults/schema | Dirty do height/mascot/dock style hiện có | Migration giữ nguyên các field đó; không replace file từ HEAD |
| i18n vi/en, qmldir chung, check.sh, architecture/theme/testing docs | File tích hợp chung | Một writer từng thời điểm, merge theo key/entry rồi chạy lại kiểm tra |

Checkout cách ly phải dựa trên snapshot có cả tracked modifications và untracked files hiện tại; worktree từ HEAD đơn thuần bỏ mất phần lớn Center mới. Không commit/stash/reset thay đổi của agent khác để lấy snapshot. Ghi manifest/hash baseline, bỏ runtime/Git metadata khi tạo bản sao, và chỉ đưa patch do Themes tạo về sau khi so lại base/current. Bản sao/worktree giúp tránh ghi đè; không thay thế việc resolve API và shared behavior khi tích hợp.

Không chạy reload resident shell hoặc full live gates đồng thời với agent Center. Pure tests chạy riêng; integration/live acceptance dùng snapshot thống nhất sau bàn giao. Audit này mới là kiểm tra và phân chia đề xuất, chưa có xác nhận ownership từ agent kia và chưa bắt đầu code Themes.


## Implementation checkpoint — completed 2026-09-06

Implemented in isolated snapshot `/tmp/titonium-appearance-20260906`, then reconciled against the finished Center checkpoint and integrated into `/home/cole/Projects/titonium`. No Git index changes, commits of other work, live wallpaper changes or compositor configuration changes were made.

- [x] v8 schema/migration and catalog/resolver: Neutral, Glass, Soft, Graphite; Light/Dark/System.
- [x] Semantic/material facade and compatible Connected/Classic colors; paint-only alpha, bounded custom strengths and ordinary radii.
- [x] Basic and lazy Advanced UI with per-mode custom, local preview, trial, Apply/Cancel and scoped undo.
- [x] Shared wallpaper journal/lease, crash recovery, committed startup/System follow and runtime capability probing.
- [x] Failure fixes independently reviewed: canonical candidate journal, staged reversal, post-save finalize retry, owner-loss cleanup and stale wallpaper undo baseline.
- [x] Combined `check.sh`, qmllint, native smoke, protected acceptance and `hyprctl configerrors` passed. Settings acceptance runs inside protected gates. Notification live substep skipped because resident D-Bus ownership already exists.
- [x] Actual Settings UI loaded in an isolated headless Quickshell harness; Basic preview and Advanced controls exercised by QtTest. Original shell auto-reloaded v8 successfully and reports ready after integration.

Validation includes 15 real coordinator QML cases, 8 UI QML cases, material runtime checks, 17 wallpaper transaction fixtures plus the Center wallpaper suite, preference migration and full existing regression suite. Native private-socket tests were rerun outside the restrictive sandbox; no tests changed the actual wallpaper.

Follow-up (user-requested wallpaper configuration): Hyprpaper 0.8.4 now supports explicitly initialized Titonium-managed baseline tracking. Valid help output with exit status 1 is accepted; bounded image decoding supports the existing 5.jpg. Managed initialization, Glass wallpaper trial and rollback to 5.jpg succeeded on live DP-1. Daemon-session recovery and delayed startup are covered by isolated tests. Out-of-band wallpaper commands remain unobservable; use Titonium for wallpaper changes. Exhaustive visual review of all surfaces/scales remains a separate manual pass.

Transfer verification: 77 changed/new files matched the tested snapshot byte-for-byte; every other file from the Center checkpoint retained its hash. i18n was merged by key, preserving Center's established wallpaper error wording. No merge conflict remained. The isolation and manifests are retained under /tmp for traceability.
