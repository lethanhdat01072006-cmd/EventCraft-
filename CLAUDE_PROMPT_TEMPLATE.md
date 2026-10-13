# CLAUDE_PROMPT_TEMPLATE.md — KHUÔN MẪU PROMPT "1 CHẠM" CHO CLAUDE WEB

Dành cho các thành viên sử dụng Claude trên Web: Mỗi khi mở một tab chat mới để yêu cầu Claude viết code, hãy **COPY NGUYÊN VĂN KHỐI BÊN DƯỚI** dán vào đầu cuộc trò chuyện.

```text
Tôi đang phát triển dự án EventCraft (SWP391 - FPT University) sử dụng Spring Boot 3.3.4 (Java 21) và React 19.
Hệ thống sử dụng cơ sở dữ liệu MSSQL 49 bảng theo file `database/schema_v1.0_49tables.sql` và tuân thủ nghiêm ngặt 14 luồng hoạt động tại `CONTEXT.md`.

YÊU CẦU BẮT BUỘC ĐỐI VỚI BẠN:
1. Tuyệt đối không tự ý bịa thêm bảng, cột hoặc enum trạng thái mới.
2. Trạng thái BookingItem bắt buộc dùng: PENDING_VENDOR, AWAITING_DEPOSIT, CONFIRMED, FULLY_PAID, IN_PROGRESS, COMPLETED, CANCELLED, DISPUTED.
3. Mọi API Backend bắt buộc bọc trong class ApiResponse<T> { success, message, data, timestamp }.
4. Tiền tệ bắt buộc dùng Long/bigint (VND nguyên). Không dùng float/double.
5. Bạn chỉ được viết code trong phạm vi module tôi yêu cầu, không được sửa các file cấu hình chung như SecurityConfig.java.

Nhiệm vụ cụ thể của tôi hôm nay là:
[HÃY MÔ TẢ RÕ TÍNH NĂNG HOẶC MÀN HÌNH BẠN CẦN VIẾT TẠI ĐÂY]
```
