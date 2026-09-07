# Center: Compact, Normal Banner và Expanded

Trạng thái: thiết kế được triển khai ngày 06/09/2026 sau yêu cầu trực tiếp của người dùng. Quyết định V1 và kết quả nằm ở phần đầu implementation plan cùng ngày; các lựa chọn bên dưới là lịch sử thiết kế.

## Các quyết định được giữ lại

- Compact trình bày trạng thái ngắn gọn, thường trực.
- Normal Banner là lớp xem nhanh: tự hiện khi có sự kiện có ý nghĩa hoặc khi hover Compact; tự thu lại khi không còn cần xem.
- Click chính vào nội dung Compact hoặc Normal Banner mở Expanded, giữ ngữ cảnh của nội dung vừa click.
- Normal Banner không phải dashboard hoặc bảng điều khiển thu nhỏ. Không đặt play/pause, slider, checkbox hoặc nút trông như thao tác trực tiếp nhưng thực tế chỉ mở Expanded.
- Expanded có bốn tab: Dashboard, Tasks, Monitoring, Wallpapers. Focus nằm trong Tasks.
- Không có tab Music riêng. Music nằm trong Dashboard, gồm artwork, tên bài/nghệ sĩ, play/pause, chuyển bài và tiến trình. Nội dung tổng quan khác của Dashboard chưa chốt; không tự thêm card để lấp đầy trang.
- Primary và Satellite tiếp tục hiển thị các hoạt động song song theo arbiter hiện có. Vị trí hiển thị không quyết định tab đích.
- Click Primary, Satellite hoặc Banner đều mở cùng một Expanded, chọn tab theo nội dung: Music → Dashboard; Focus/task → Tasks; cảnh báo tài nguyên → Monitoring. Quy tắc này thay thế phương án Music giữ tab cũ và highlight thanh dùng chung.
- Connected và Classic dùng chung hành vi, giữ cấu trúc hình khối riêng của từng kiểu.

“Click bất cứ thành phần nào” ở đây chỉ nói đến nội dung Center Compact/Normal Banner; không thay đổi hành vi Wi-Fi, Bluetooth, Input Method, tray hoặc các control khác trên bar.

## Đề xuất mặc định để thực hiện, chưa phải số đo đã kiểm chứng

- Hover dwell 300ms trước khi mở Banner; rời vùng tương tác có grace period 250ms.
- Compact và Banner là một vùng xem nhanh logic. Di chuyển qua khoảng cách giữa chúng trong Classic không làm đóng/mở chập chờn.
- Banner mở bởi hover: ở lại khi con trỏ hoặc focus bàn phím còn trong vùng; rời vùng thì đóng sau 250ms.
- Banner mở bởi sự kiện: dùng TTL của chính loại sự kiện hiện có. Hover tạm dừng TTL; rời vùng tiếp tục thời gian còn lại, với tối thiểu 250ms để tránh đóng ngay.
- Expanded không bị timer Banner đóng. Escape, nút đóng hoặc click ngoài là các cách đóng; giữ chính sách pin hiện có và xác minh tương tác này trước khi thay đổi.
- Khi đang xem Banner, giữ nguyên danh tính nội dung và đích click. Sự kiện thông thường mới được coalesce ở arbiter, không chen vào dưới con trỏ. Nội dung đã mất phải có trạng thái unavailable, không chuyển click sang mục khác.
- Music chỉ trình bày control trong Dashboard. Đổi tab không dừng playback; khi quay lại đọc trạng thái thật từ service, không reset player.
- Chỉ lối mở idle không có ngữ cảnh mới dùng tab gần nhất; mặc định đề xuất là Dashboard nếu chưa có lịch sử. Click nội dung cụ thể luôn ưu tiên tab đích, kể cả Expanded đã mở. Chưa thêm persistence.

## Phân biệt Normal với Critical

Kế hoạch này thay đổi Normal Banner. Không chuyển yêu cầu phê duyệt, cảnh báo Critical hoặc nội dung cần phản hồi bắt buộc thành thông báo tự tắt. Giữ chính sách ưu tiên, xác nhận và hàng đợi Critical đang có; kiểm tra xung đột khi người dùng đang xem hoặc thao tác.

Critical là mức độ ưu tiên, không phải đích điều hướng: cảnh báo CPU/RAM/GPU → Monitoring, lỗi task → Tasks; nguồn chưa ánh xạ giữ detail an toàn và cần quyết định rõ trước implementation. Không ánh xạ mọi Critical vào Monitoring.

## Nội dung các tab

| Tab | Mục đích | Phạm vi khởi đầu đề xuất |
| --- | --- | --- |
| Dashboard | Tổng quan và Music | Music theo phiên media hiện có; phần tổng quan bổ sung cần thiết kế riêng |
| Tasks | Chọn việc và tập trung làm việc đó | Hiển thị Today Focus và điều khiển phiên Focus hiện có |
| Monitoring | Xem trạng thái tài nguyên khi cần | CPU, RAM, GPU và dữ liệu thực có từ SystemMonitorService; giá trị thiếu hiển thị unavailable |
| Wallpapers | Chọn hình nền | Catalog ảnh cục bộ, xem trước rồi áp dụng rõ ràng |

Dashboard chứa Music; không có thanh Music bắt buộc xuyên các tab. Preview wallpaper không tự áp dụng. Monitoring chỉ lấy mẫu khi tab đang được xem; vì vậy không hứa hẹn tự cảnh báo CPU lúc tab đóng. Cảnh báo nền cần một thiết kế vòng đời riêng nếu được yêu cầu.

## Những điểm phải quyết định trước các nhánh tính năng tương ứng

1. Tasks: chỉ Today Focus/phiên Focus, hay danh sách task có thêm/sửa/hoàn thành/lưu trữ? Không suy ra quyền ghi vào daily-focus.md từ việc thêm tab.
2. Wallpapers: thư mục ảnh nào, backend nào đang thực sự chạy, áp dụng màn hình hiện tại hay nhiều màn hình, và lưu lựa chọn ở đâu?
3. Dashboard: nội dung tổng quan ngoài Music và trạng thái khi không có media chưa được chốt; không tự biến thành một dashboard nhiều widget.
4. Click ngữ cảnh ngoài Focus/Music/Monitoring, ví dụ screenshot hay notification: giữ đích chi tiết đang có trong Expanded, không ép về Tasks và không tự tạo thêm tab. Cần kiểm tra các đích thực tế trước khi thay renderer.

Các điểm này không ngăn thiết kế state machine, khung tab hoặc tích hợp Music; chúng ngăn việc tự phát triển một ứng dụng Tasks/Wallpapers lớn hơn phạm vi đã thống nhất.

## Không thuộc đợt này

- Redesign themes, dark glass, border/sheens/shadows hoặc thay wallpaper tự động.
- Tự mở rộng Dashboard ngoài phạm vi đã chốt, tab Music, task sync, lịch, Kanban, tải ảnh trực tuyến.
- Thay đổi border cửa sổ hoặc làm lại hover/state của bar đã thực hiện trong phiên.
- Viết code, chạy triển khai, commit, restart hoặc thay đổi cấu hình trong bước lập kế hoạch.
