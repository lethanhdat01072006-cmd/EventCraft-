# CONTEXT.md — KIẾN TRÚC NGHIỆP VỤ & 14 LUỒNG CHUẨN EVENTCRAFT

Hệ thống **EventCraft** là nền tảng lập kế hoạch sự kiện & kết nối nhà cung cấp dịch vụ thông minh (B2B Quote-First Event Marketplace).
Dự án: **SWP391 — Fall 2026 — Lớp SE20B04 — Đại học FPT Đà Nẵng**.

---

## 1. ĐỘI NGŨ PHÁT TRIỂN & PHÂN CÔNG PHẠM VI (5 THÀNH VIÊN)
1. **Lê Thành Đạt (Leader):** Kiến trúc hệ thống, Core Booking Flow, Slot Lock bi quan, Hợp đồng điện tử.
2. **Nam (Frontend Lead):** Kiến trúc React 19, Luồng tạo sự kiện, Giỏ hàng, Ký hợp đồng & Thanh toán.
3. **Ly (Frontend & QA):** Giao diện Vendor, Quản lý danh mục dịch vụ, Lịch làm việc, Kịch bản kiểm thử.
4. **Ngọc (Backend Developer):** Identity & Vendor KYC, Catalog dịch vụ đơn/gói, Quản lý lịch bận.
5. **Hưng (Backend Developer):** Bảo mật, Hệ thống ví nội bộ, Sổ cái kép đối ứng, Ký quỹ Escrow, VNPay.

---

## 2. 14 LUỒNG HOẠT ĐỘNG CHUẨN (SSoT WORKFLOWS)

### Nhóm 1: Tài khoản & Nhà cung cấp
* **Luồng 1 (Auth & OTP):** Đăng ký vai trò Host/Vendor, xác thực OTP 6 số (hiệu lực 5 phút), đăng nhập Google OAuth, sai mật khẩu 5 lần khóa 15 phút.
* **Luồng 2 (Vendor KYC):** Vendor nộp hồ sơ CCCD/GPKD (trạng thái `PENDING_KYC`). Admin duyệt (`APPROVED`) hoặc từ chối (`REJECTED`) kèm lý do. Cho phép nộp lại nhiều lần.
* **Luồng 3 (Catalog & Lịch):** Đăng dịch vụ lẻ (`SINGLE`) hoặc gói trọn gói (`BUNDLE`). Cấu hình đơn vị tính, đơn giá, sức chứa `max_concurrent`. Vendor tự chặn lịch bận trong bảng `availability_blocks`.

### Nhóm 2: Lập kế hoạch sự kiện
* **Luồng 4 (Event & AI Budget):** Host tạo sự kiện (cách ngày hiện tại tối thiểu 14 ngày), hệ thống tự sinh ngân sách mặc định (10% dự phòng, 90% chia theo tỷ lệ) và checklist lùi ngày. Tích hợp AI Gemini gợi ý ngân sách chi tiết.
* **Luồng 5 (Knapsack Suggestion):** Hệ thống lọc dịch vụ khả dụng, áp dụng thuật toán Knapsack nhiều nhóm để gợi ý 3 phương án (Tiết kiệm, Cân bằng, Chất lượng) đưa vào giỏ hàng `carts`.

### Nhóm 3: Đặt dịch vụ & Thanh toán
* **Luồng 6 (Booking Request):** Host gửi yêu cầu từ giỏ hàng. Tạo đơn `bookings`, các dịch vụ ở trạng thái `PENDING_VENDOR` (hạn phản hồi 24 giờ). Ngày và thành phố sự kiện bị khóa từ lúc này.
* **Luồng 7 (Hợp đồng & Cọc 30%):** Vendor duyệt đơn kèm phụ lục giá -> chỗ được giữ trong `slot_locks` -> dịch vụ chuyển `AWAITING_DEPOSIT`. Host đồng ý hợp đồng khung và trả cọc 30% qua VNPay hoặc Ví nội bộ. Đơn chuyển `CONFIRMED`. Tiền vào ví `ESCROW_POOL` (trạng thái `HELD`). Tạo nhóm chat sự kiện.
* **Luồng 8 (Thanh toán 70% đợt hai):** Host thanh toán 70% còn lại trước ngày sự kiện 7 ngày (D-7) -> chuyển sang `FULLY_PAID`. Nếu quá hạn D-7 không thanh toán: đơn tự động `CANCELLED`, phạt mất cọc 30%. Đến ngày diễn ra sự kiện, dịch vụ tự động chuyển `IN_PROGRESS`.
* **Luồng 9 (Nghiệm thu & Giải ngân):** Sau khi sự kiện kết thúc, Host có 72 giờ để nghiệm thu hoặc khiếu nại. Quá 72 giờ không khiếu nại, hệ thống tự động nghiệm thu (`COMPLETED`) và giải ngân từ ví `ESCROW_POOL` về ví Vendor (trừ 5% phí sàn). Cho phép đánh giá 1-5 sao.

### Nhóm 4: Ngoại lệ & Tranh chấp
* **Luồng 10 (Báo giá phát sinh):** Vendor gửi báo giá phát sinh trong chat 1-1 (`addendum_quotes`, hạn 48h). Host chấp thuận phải thanh toán 100% vào escrow, sinh phụ lục bổ sung.
* **Luồng 11 (Vendor thay thế):** Khi một vendor từ chối, hệ thống gợi ý vendor thay thế có mức giá dao động +-20% để tạo đơn mới.
* **Luồng 12 (Hủy dịch vụ/sự kiện):** Chưa cọc được hủy miễn phí; đã cọc hủy trước ngày sự kiện mất cọc 30%, hoàn 70% vào ví. Admin có quyền hủy hộ bất khả kháng (hoàn 100%).
* **Luồng 13 (Khiếu nại & Phân xử):** Mở trong vòng 72 giờ sau tiệc (`disputes`, trạng thái `DISPUTED`, escrow chuyển sang `FROZEN`). Vendor giải trình trong 48 giờ. Admin phân xử nhập tỷ lệ (`host_percent + vendor_percent = 100`) để hoàn tiền và giải ngân dứt điểm.

### Nhóm 5: Hỗ trợ & Vận hành
* **Luồng 14 (Chat, Thông báo, Ví & Demo):** Chat 1-1 và chat nhóm sự kiện (chuyển chỉ đọc sau 30 ngày), thông báo in-app, rút tiền giả lập từ ví, Virtual Clock (`clock_offset_minutes`) hỗ trợ Admin tua thời gian phục vụ demo hội đồng.

---

## 3. CƠ SỞ DỮ LIỆU & SỐ LIỆU ĐẶC THÙ
- **Tổng số bảng:** 49 bảng 3NF.
- **Tiền tệ:** `bigint` (VND nguyên).
- **Thời gian:** `datetime2` (UTC).
- **Hằng đẳng thức Sổ cái kép:** $\sum \text{Debit} = \sum \text{Credit}$ cho mỗi `journal_id`.
- **Hằng đẳng thức Escrow:** $\sum \text{amount\_held}(\text{HELD, FROZEN}) = \text{Balance(ESCROW\_POOL)}$.
