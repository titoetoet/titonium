# Center Banner & Expanded Implementation Plan

Trạng thái: đã triển khai sau yêu cầu “Ok let's go, code thôi” ngày 06/09/2026.

## Kết quả triển khai

- [x] Controller sở hữu dwell 300ms, leave grace 250ms, giữ nội dung khi hover và hủy callback cũ khi Expanded mở.
- [x] Normal Banner chỉ xem nhanh; Primary/Satellite/Banner mở tab theo nguồn nội dung.
- [x] Expanded dùng Dashboard / Tasks / Monitoring / Wallpapers, tab cố định phía trên, close bên phải, nội dung cuộn; header cuộn ngang khi hẹp.
- [x] Dashboard dùng player hiện có và hoạt động thực đang chạy; screenshot, notification và approval giữ detail/actions tại đây.
- [x] Tasks V1 dùng Today Focus và phiên Focus 25 phút hiện có, kèm jobs/timers; không thêm task CRUD.
- [x] Monitoring chỉ lấy mẫu khi Expanded mở đúng tab; mất screen hoặc đổi tab dừng demand.
- [x] Wallpapers dùng thư mục suy ra từ hyprpaper.conf hoặc thư mục nhập, preview trước, Apply đúng screen; lưu bản ghi thành công ngoài Git, không tự replay. Backend contract và giới hạn tại `Titonium/Services/Wallpapers/README.md`.
- [x] Regression riêng cho deferred preview, critical/approval, context hết hạn, narrow header và vòng lặp geometry lúc animate.

Tests điều hướng nằm trong `scripts/check_center_preview.js` (thay tên file dự kiến `check_expanded_navigation.js`). `check_center_deadline.py` dùng controller thật với service giả; `check_expanded_content.py` dùng các view thật với dữ liệu giả.

Phần dưới giữ nguyên checklist thiết kế ban đầu để truy vết, không phải danh sách công việc hiện còn chờ. Kết quả acceptance và giới hạn kiểm chứng được ghi trong `docs/TESTING.md`.

**Goal:** Tạo hành vi xem nhanh nhất quán cho Normal Banner và tổ chức Expanded thành Dashboard / Tasks / Monitoring / Wallpapers, điều hướng theo nội dung và Music trong Dashboard.

**Architecture:** Giữ controller/state machine là nơi duy nhất sở hữu mode, deadline và đích điều hướng; renderer Connected/Classic chỉ trình bày và phát intent. Expanded chia sẻ một nội dung chung bên trong surface riêng của từng kiểu. Service sở hữu dữ liệu và hành động; các tab nặng chỉ mount khi cần.

**Tech Stack:** Quickshell, Qt Quick/QML, JavaScript thuần cho transition/routing, các service Focus/MPRIS/SystemMonitor hiện có.

**Spec:** `docs/superpowers/specs/2026-09-06-center-banner-expanded-direction.md`.

## Global Constraints

- Ràng buộc plan-only ban đầu đã được thay bằng yêu cầu triển khai trực tiếp của người dùng.
- Đọc `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/MODULE_CONTRACT.md`, `docs/CODING_FLOW.md`, `docs/TESTING.md` trước khi triển khai.
- Không thay hình khối Connected/Classic, theme, border cửa sổ, keybind hoặc Input Method.
- Normal Banner không giành focus bàn phím; Expanded dùng focus ownership đang có.
- Không trùng listener/process giữa renderer, không polling ẩn; tôn trọng Reduced Motion và screen lifecycle.
- Không dùng test để launch app thật, ghi clipboard hoặc thay wallpaper thật.
- Working tree đang có nhiều thay đổi từ các công việc khác. Xác minh lại nguồn hiện tại; không reset hoặc commit gộp các thay đổi đó.
- 300ms hover / 250ms grace là mặc định đề xuất cần visual acceptance, không phải benchmark UX.

## Baseline đã kiểm tra

- `Titonium/Core/Surfaces/Center/CenterSurfaceState.js` đã có mode, destination, deadlineToken, remainingMs và generation.
- `CenterSurfaceController.qml` đã xử lý activate-compact, điều hướng và timeout; mở rộng tại đây thay vì tạo controller thứ hai.
- `Titonium/Bar/center/CenterCompactCapsule.qml` đang có tương tác media/capture trực tiếp; kiểm kê trước khi đơn giản hóa thành xem nhanh.
- Renderer Classic/Connected đang mount `MusicPlayerContent.qml` và `ScreenshotPreviewContent.qml` theo nội dung. Không xóa đường đến screenshot khi chuyển sang tab.
- `Services/Center/CenterFocusStore.qml` đọc Today Focus; `FocusSessionService.qml` sở hữu phiên Focus. Chưa thấy service Tasks độc lập.
- `Services/SystemMonitor/SystemMonitorService.qml` có activation và lịch lấy mẫu; chưa có service Wallpapers trong cây hiện tại.
- Các plan Center cũ chỉ là lịch sử triển khai. Những quyết định xung đột về vai trò Normal Banner hoặc tab Music dùng spec mới này; các chức năng không liên quan được giữ nguyên.

## Task 1 — State machine xem nhanh

**Files:** sửa `Titonium/Core/Surfaces/Center/CenterSurfaceState.js`, `CenterSurfaceController.qml`; bổ sung `scripts/check_center_surface_state.js`, `scripts/check_center_deadline.py`.

**Contract đề xuất:** mở rộng intent controller bằng `preview-enter`, `preview-leave`, `preview-open-due`, `preview-close-due`; mỗi callback mang screen và generation. Phân biệt nguồn mở `event` / `hover`; không dùng một boolean hover để thay thế mode. Giữ deadline một lần và token đang có.

- [ ] Thêm test fail cho dwell bị hủy trước 300ms, chuyển từ Compact sang Banner không đóng giữa đường, TTL pause/resume và timeout cũ sau khi vào Expanded.
- [ ] Chạy `node scripts/check_center_surface_state.js` và `python3 scripts/check_center_deadline.py`; xác nhận fail đúng hành vi còn thiếu.
- [ ] Thực hiện transition theo bảng sau; timer nằm ở controller, không ở từng renderer.

```text
compact + preview-enter       -> schedule open(now + 300, generation)
compact + preview-leave       -> invalidate scheduled open
preview-open-due + valid      -> banner(origin=hover, keyboardFocus=none)
banner + preview-enter        -> cancel close; pause event TTL if applicable
banner + preview-leave        -> hover: close after 250ms
                                event: resume max(remainingMs, 250ms)
banner + primary activation   -> expanded; invalidate all preview deadlines
expanded + any preview timer  -> unchanged
screen revoked                -> clear owner, timers and held context
```

- [ ] Test event mở trước khi dwell hoàn tất; close/reopen nhanh; Reduced Motion; màn hình mất khi timer pending.
- [ ] Chạy lại hai test trên; review diff riêng cho state machine trước khi nối UI.

## Task 2 — Banner nội dung ổn định và click-to-expand

**Files:** sửa `Titonium/Bar/center/CenterCompactCapsule.qml`, `presentations/Connected/ConnectedRenderer.qml`, `presentations/Classic/ClassicRenderer.qml`, `Titonium/Services/Center/CenterAttentionService.qml` và helper arbiter tương ứng nếu cần; mở rộng `scripts/check_center_compact_ui.py`, `scripts/check_center_attention_rules.js`.

**Consumes:** các intent preview của Task 1.
**Produces:** renderer phát `activate-compact` với `contextId` đúng nội dung đang hiển thị; controller giữ snapshot xem nhanh cùng generation, không thay đổi service facts.

- [ ] Test fail cho sự kiện B đến khi đang xem A: text/đích click vẫn thuộc A; A bị xóa không khiến click kích hoạt B.
- [ ] Cho Compact/Banner dùng một vùng hover logic, kể cả khoảng trống Classic; không mở Expanded chỉ vì hover.
- [ ] Tách phần trình bày Normal Banner khỏi control play/pause/seek. Mọi primary click và Enter/Space trên nội dung xem nhanh mở Expanded đúng ngữ cảnh.
- [ ] Lập bảng wheel/right-click hiện có trước khi thay đổi: hành động cần thiết phải có đường tương đương trong Expanded; không vô tình giữ nút có nghĩa mâu thuẫn trong Normal Banner.
- [ ] Giữ riêng Critical/approval và screenshot detail; test ngữ cảnh hết hạn và sự kiện Critical đến trong khi hover.
- [ ] Chạy `python3 scripts/check_center_compact_ui.py`, `node scripts/check_center_attention_rules.js`, `node scripts/check_center_surface_state.js`.

## Task 3 — Khung Expanded và điều hướng theo nội dung vào bốn tab

**Files:** tạo `Titonium/Bar/center/ExpandedContent.qml`, `ExpandedNavigation.js`; cập nhật `qmldir`, hai renderer, `CenterSurfaceController.qml`, `CenterSurfaceState.js`, `config/i18n/en.json`, `config/i18n/vi.json`; tạo `scripts/check_expanded_navigation.js`.

**Interface đề xuất:** `ExpandedNavigation.route(context, lastTab)` trả `{tab, reveal}`; `context` mang `source`, `kind`, `severity`, `id`. Không dùng slot Primary/Satellite hoặc severity đơn lẻ làm khóa routing. `ExpandedContent` nhận `snapshot`, `viewState`, phát `intentRequested`; không sở hữu process/store.

```javascript
// Contract cho helper thuần, chưa phải implementation.
route({source: "focus", id: "focus:session"}, "wallpapers")
// {tab: "tasks", reveal: "focus"}
route({source: "media", id: "media:current"}, "monitoring")
// {tab: "dashboard", reveal: "music"}
route({source: "monitoring", kind: "cpu", severity: "critical"}, "tasks")
// {tab: "monitoring", reveal: "metrics"}
route({source: "task", kind: "failed", severity: "critical"}, "monitoring")
// {tab: "tasks", reveal: "task"}
route(null, "")             // {tab: "dashboard", reveal: ""}
route(null, "wallpapers")   // {tab: "wallpapers", reveal: ""}
```

`source`/`kind` trong ví dụ là contract chuẩn hóa đề xuất; đối chiếu source thực có (ví dụ job) tại domain boundary trước khi nối vào helper.

- [ ] Viết test fail cho sáu case trên; invalid lastTab của idle về Dashboard; không có tab Music. Cùng context chuyển Primary ↔ Satellite vẫn đi cùng tab.
- [ ] Test đồng thời Focus + Music: click Focus vào Tasks, click Music vào Dashboard; sự kiện Critical tài nguyên thay Primary vẫn không thay route của Satellite Music. Đổi tab không dừng các hoạt động.
- [ ] Thêm selection tab lưu trong phiên; không thay `selectedContextId` bằng tabId. Click nội dung khi Expanded đang mở vẫn chọn tab đích, không toggle đóng.
- [ ] Unknown source/severity không tự vào Monitoring. Kiểm kê screenshot/notification/approval và giữ detail destination hiện có dưới Expanded; chốt ánh xạ tab cho các nguồn này trước khi phát hành, không tạo tab mới hoặc âm thầm bỏ detail.
- [ ] Mount một `ExpandedContent` ở style đang hoạt động; giữ ownership/focus policy của native host.
- [ ] Thiết kế tab bằng label rõ ràng, vùng bấm đủ rộng, selected/focus phân biệt; Left/Right điều hướng tab, Tab vào nội dung, Escape theo host.
- [ ] Đợt khung chưa hoàn tất tính năng không được phát hành với tab rỗng: chỉ kết luận Expanded hoàn chỉnh sau Dashboard/Tasks/Monitoring/Wallpapers bên dưới.
- [ ] Chạy `node scripts/check_expanded_navigation.js` cùng các check routing/lifecycle hiện có; đăng ký test mới trong `scripts/check.sh`.

## Task 4 — Dashboard chứa Music

**Files:** tạo `Titonium/Bar/center/DashboardContent.qml`; sửa `ExpandedContent.qml`, `qmldir`; tái sử dụng `MusicPlayerContent.qml`, `MusicArtwork.qml`, `MusicSeek.qml`; bổ sung `scripts/check_music_player.js` và UI fixture.

**Consumes:** media descriptor/capabilities, intent dispatch hiện có và route `{tab: "dashboard", reveal: "music"}` từ Task 3.
**Produces:** nội dung Music trong Dashboard, không có tab Music hoặc thanh Music xuyên các tab, không tạo player service thứ hai.

**Điểm quyết định:** chốt bố cục tổng quan ngoài Music và empty state Dashboard trước khi hoàn thiện trang. Không tự thêm widget để tránh cảm giác đơn điệu.

- [ ] Test fail: click Music từ Primary/Satellite/Banner luôn vào Dashboard bất kể tab cũ; pause vẫn hiển thị player; player biến mất cập nhật empty state đã chốt.
- [ ] Ghép artwork, title/artist, controls và seek; disable thao tác theo capability thật. Revalidate player/context khi dispatch, không điều khiển player cũ.
- [ ] Đổi tab chỉ unload presentation; playback và state do service giữ. Hủy seek drag chưa hoàn tất khi unmount; quay lại đọc position thật thay vì reset hoặc gửi seek cũ.
- [ ] Kiểm tra title dài, thiếu artwork, player không seek được, Reduced Motion và nguồn media biến mất trong lúc chuyển tab bằng fixture.
- [ ] Chạy `node scripts/check_music_player.js` và UI fixture, không điều khiển phiên nghe nhạc thật trong test.

## Task 5 — Tasks chứa Focus, không tự mở rộng thành task manager

**Files:** đề xuất `Titonium/Bar/center/TasksContent.qml`; dùng `Services/Center/CenterFocusStore.qml`, `FocusSessionService.qml`, `adapters/FocusCenterAdapter.qml` qua contract domain hiện có; mở rộng fixture Focus và `ExpandedContent.qml`.

**Điểm quyết định:** xác nhận Tasks V1 chỉ dùng Today Focus/phiên Focus hay cần CRUD danh sách. Nếu cần CRUD, viết plan riêng cho model/persistence trước khi thêm service; không suy ra quyền ghi store hiện có.

- [ ] Test fail: Focus đang chạy hiện đúng ở Tasks, đổi tab không dừng phiên, Banner Focus mở đúng phiên.
- [ ] Với phạm vi V1 đề xuất, trình bày việc hiện tại và actions được service hỗ trợ; trạng thái trống hướng dẫn nguồn Today Focus thực có, không hiển thị nút tạo task không hoạt động.
- [ ] Countdown dựa deadline gốc; timer hiển thị không sở hữu phiên. Chỉ phát transition bắt đầu/kết thúc đáng chú ý lên Normal Banner.
- [ ] Chạy fixture Focus hiện có và test UI tab; xác nhận không ghi file hoặc reset phiên khi mount/unmount tab.

## Task 6 — Monitoring on-demand

**Files:** đề xuất `Titonium/Bar/center/MonitoringContent.qml`; sửa `ExpandedContent.qml`, `Titonium/Services/SystemMonitor/SystemMonitorService.qml` và composition/domain thích hợp; bổ sung `scripts/check_system_monitor.py`, `scripts/check_system_monitor_rules.js`.

**Contract:** chỉ caller ở orchestration/service boundary cấp activation khi Expanded visible, tab Monitoring selected và màn hình còn hợp lệ; view nhận snapshot bất biến.

- [ ] Test fail: đóng Expanded hoặc đổi tab dừng lấy mẫu; mở lại không nhân đôi timer/process; callback generation cũ không ghi vào phiên mới.
- [ ] Hiển thị CPU/RAM/GPU và dữ liệu đã có; null là unavailable, không phải zero. Không thêm network sampling chỉ để điền một card.
- [ ] Giữ lịch lấy mẫu hiện có, không chạy Monitoring nền để tạo Banner cảnh báo. Nếu cần cảnh báo nền, tách yêu cầu riêng.
- [ ] Chạy `python3 scripts/check_system_monitor.py`, `node scripts/check_system_monitor_rules.js`, sau đó focused acceptance ở môi trường cách ly.

## Task 7 — Wallpapers là nhánh cần plan backend riêng

**Ownership đề xuất:** `Titonium/Bar/center/WallpapersContent.qml` chỉ trình bày; capability mới nằm trong `Titonium/Services/Wallpapers/` với `qmldir`, service và helper. Chưa tạo các file này trong phiên lên plan.

- [ ] Trước implementation, xác minh daemon/config đang dùng và chốt thư mục ảnh, scope màn hình, nơi lưu lựa chọn với người dùng.
- [ ] Viết plan con dựa trên ba quyết định đó; chọn API/CLI thực tế và ghi nguồn/license nếu thích nghi code bên ngoài.
- [ ] Contract bắt buộc của plan con: chọn thumbnail chỉ preview; Apply mới thực thi; chỉ cập nhật selection đã áp dụng sau thành công; thất bại giữ hình nền trước và hiển thị lỗi ngắn.
- [ ] Tests phải dùng thư mục fixture và backend giả tại ranh giới I/O; cover file bị xóa, ảnh không hỗ trợ, màn hình mất và apply thất bại. Không thay wallpaper thật trong automated acceptance.
- [ ] Không gọi toàn bộ Expanded hoàn tất trước khi có catalog/preview/apply hoạt động và đường lỗi được kiểm tra.

## Task 8 — Acceptance và bàn giao

**Files:** cập nhật `docs/ARCHITECTURE.md`, `docs/TESTING.md`, `scripts/check.sh`; bổ sung check vòng đời Expanded nếu chưa được bao phủ.

- [ ] Chạy `./scripts/check.sh`, `./scripts/smoke.sh`, `./scripts/protected_acceptance.sh`, `hyprctl configerrors`. Nếu resident shell cản `qs -n`, dùng bản sao tạm, không dừng phiên của người dùng chỉ để test.
- [ ] Review riêng Connected và Classic: auto event, hover dwell, di chuyển Compact ↔ Banner, click thành Expanded, rời chuột, Escape/outside, pin, chuyển tab, media hết phiên, màn hình mất, Reduced Motion, scale 1.0/1.5.
- [ ] Xác minh Primary/Satellite vẫn hiển thị các hoạt động song song; click cùng nội dung luôn chọn cùng tab dù slot thay đổi, kể cả khi Expanded đã mở.
- [ ] Kiểm tra task và phiên Focus không bị reset bởi tab/renderer; Monitoring ngừng lấy mẫu khi ẩn; Wallpapers không tự áp dụng khi preview.
- [ ] Kiểm tra notification/screenshot/critical/approval vẫn có đích và không bị biến thành tab trống hoặc tự-dismiss sai.
- [ ] Tổng hợp kết quả, phần chưa xác minh bằng mắt và diff chỉ thuộc phạm vi này. Chỉ commit từng phần đã kiểm chứng theo workflow được người dùng yêu cầu.

## Thứ tự ưu tiên

1. Làm và xem lại Task 1–2 trước: chốt cảm giác “rê vào xem, click đi sâu”.
2. Task 3–4 tạo cấu trúc bốn tab, routing theo nội dung và Dashboard chứa Music.
3. Tasks / Monitoring / Wallpapers phát triển theo từng nhánh; không xây đồng thời ba hệ thống khi mục tiêu xem nhanh chưa ổn.
4. Task 8 là điều kiện hoàn tất, không coi code chạy hoặc mockup đẹp là đủ.
