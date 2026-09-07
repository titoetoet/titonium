# Appearance, Themes và Advanced

Ngày: 2026-09-06. Phạm vi: thiết kế sản phẩm và kỹ thuật trong cùng đợt triển khai. Advanced là giao diện custom của người dùng, không phải lý do hoãn thiết kế kỹ thuật.

## Hành vi

- Mở rộng Settings → Appearance hiện có. Basic gồm Dark / Light / System, theme cards, preview, wallpaper và nút Advanced.
- Theme quyết định palette và material. Mode quyết định biến thể sáng/tối. Connected/Classic tiếp tục là layout tại Bar; đổi theme không đổi layout, mascot, kích thước bar hoặc state chức năng.
- Có Glass, Soft và Graphite; cả ba hỗ trợ Light/Dark. Giữ Neutral hiện có làm preset tương thích cho cấu hình cũ; không tự đổi diện mạo người dùng khi migration.
- Chọn card, mode và chỉnh Advanced chỉ cập nhật bản nháp cùng preview trong Settings. Xem thử mới đưa bản nháp lên shell trong 15 giây. Giữ bản xem thử đưa nó vào giao dịch Settings; Apply chung lưu toàn bộ giao dịch, Cancel bỏ toàn bộ giao dịch theo hành vi hiện có. Nhãn phải nói rõ Giữ bản xem thử chưa lưu.
- Hết thời gian, Escape, khóa session hoặc mất màn hình sở hữu hủy trial. Đổi trang kết thúc trial trước khi chuyển. Chỉnh sửa Appearance khác bị khóa trong trial.
- Hoàn tác sau Apply phục hồi phần Appearance và wallpaper của lần Apply thành công gần nhất trong phiên; không phục hồi toàn bộ Settings. Lần Apply kế tiếp thay mốc hoàn tác. Tắt hoàn tác khi có bản nháp chưa lưu hoặc đang ghi file.
- Advanced đóng mặc định; đóng Advanced không xóa custom. Có reset từng trường và reset custom của theme đang chọn. Custom được nhớ riêng theo theme và theo Light/Dark.
- Reduced Motion dùng duy nhất accessibility.reducedMotion hiện có, đặt control trong Advanced; không lưu một bản thứ hai dưới appearance.

## Advanced bản đầu

Màu nhấn #RRGGBB; opacity nền 0.85–1; độ mạnh viền 0–1; bóng 0–1; sheen/hover glow 0–1; radiusScale 0.75–1.25 cho panel/control thông thường; motionScale 0.5–1.5. Reduced Motion luôn ưu tiên hơn motionScale. Không giảm opacity text/icon; focus ring luôn nhìn thấy. Radius của silhouette Connected và input mask vẫn theo geometry renderer, không nhân radiusScale một cách toàn cục.

Custom lưu dưới themeOverrides[themeId][light|dark]; thiếu trường nghĩa là dùng preset. Accent text được chọn theo độ tương phản; nếu accent không phù hợp cho text trên nền thì dùng màu semantic có độ tương phản đạt yêu cầu. Trạng thái lỗi/thành công vẫn phân biệt và không bị thay bằng accent.

## Ownership kỹ thuật

- Core/Runtime/Preferences giữ persistence, validation, migration và giao dịch Settings.
- Services/Appearance cung cấp mode hệ thống và snapshot token đã resolve; không đọc Theme hoặc view. Theme giữ facade semantic không I/O; tên token hiện có ổn định.
- Settings/AppearanceCoordinator giữ draft, trial và mốc hoàn tác trong phiên; không sở hữu Process/FileView. Một timer trial ở coordinator, không có timer trên mỗi card.
- Services/Wallpapers sở hữu Hyprpaper adapter và trạng thái wallpaper. Appearance và Center dùng cùng capability này; không có backend thứ hai trong Themes.
- Wallpaper mặc định là keep: không đổi ảnh hiện tại. Người dùng có thể chọn theme pair hoặc file riêng. File riêng giữ nguyên khi đổi mode; theme pair đi theo mode khi người dùng đã chọn chính sách đó.
- Wallpaper tác động DP-1 theo ScreenPolicy hiện có; DP-3 không đổi. Chỉ thực hiện trial wallpaper khi đã chụp được baseline có thể phục hồi. Backend lỗi phải báo lỗi và không báo Apply thành công.
- Glass dùng gradient, outline, sheen và shadow bằng primitive QML. Không hứa có backdrop blur/refraction như raster tham chiếu; không thêm shader, hyprglass hoặc sửa compositor để đạt hiệu ứng. Mức nền đặc là fallback.

## Tính nhất quán và phục hồi

Một candidate Appearance gồm theme, mode, custom và wallpaper policy. Trial là lớp runtime tạm, không ghi file. Settings draft khác được giữ nguyên khi trial quay lại. Ghi settings atomic chỉ sau wallpaper chuẩn bị/áp dụng thành công; lỗi ghi phải phục hồi wallpaper, giữ committedState cũ và cho retry. Callback bất đồng bộ có generation để bỏ kết quả cũ.

Giao dịch liên quan wallpaper cần recovery journal ngoài Git: ghi baseline và candidate trước side effect; xóa journal sau commit hoặc rollback hoàn tất. Khi khởi động đọc persisted preferences và journal để hoàn tất candidate nếu đã commit, hoặc phục hồi baseline nếu chưa commit. Không ép ảnh cũ lên màn hình không còn hợp lệ. Lỗi phục hồi được hiển thị, không giả định rollback thành công.

## Hoàn thành

Basic và Advanced đều hoạt động; cả ba theme và Neutral có Light/Dark; System có fallback Dark khi platform không cung cấp preference; trial/Apply/Cancel/undo/migration và failure recovery được kiểm tra. Renderer không bị remount khi đổi theme. Kiểm tra Settings, Bar, Dock, Center, popups, notifications, Spotlight và Window Switcher ở Connected/Classic, scale 1/1.5 và Reduced Motion.

Nguồn kiểm chứng: [Qt QStyleHints](https://doc.qt.io/qt-6/qstylehints.html) mô tả colorScheme và Unknown; metadata QtQuick cài tại máy có colorSchemeChanged. [Hyprpaper](https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/) cung cấp wallpaper qua IPC; máy có v0.8.4. Adapter phải theo CLI của bản cài, không lấy lệnh từ tài liệu latest một cách mặc định. Không sao chép code theme bên ngoài.
