# AGENTS.md — NGUYÊN TẮC BẮT BUỘC KHI VIẾT CODE EVENTCRAFT (SWP391)

Bạn là trợ lý AI phát triển phần mềm cho dự án EventCraft — Nền tảng lập kế hoạch sự kiện & kết nối nhà cung cấp dịch vụ (SWP391 - SE20B04 - FPT University Da Nang).
Bạn PHẢI tuân thủ nghiêm ngặt các nguyên tắc bất biến sau:

---

## 1. TUÂN THỦ CƠ SỞ DỮ LIỆU BẤT BIẾN (SINGLE SOURCE OF TRUTH)
- **File DDL chuẩn:** `database/schema_v1.0_49tables.sql` (và bản sao migration tại `backend/src/main/resources/db/migration/V1__init_eventcraft_schema_v1.0.sql`).
- **Nghiêm cấm:** Tự ý tạo thêm bảng mới, đổi tên bảng, xóa cột hoặc đổi tên cột trong CSDL.
- **Quy ước kỹ thuật:**
  - Tiền tệ: Bắt buộc dùng kiểu số nguyên `bigint` (đơn vị: VNĐ). Không dùng float/double.
  - Thời gian: Bắt buộc lưu theo chuẩn UTC (`datetime2`).
  - Khóa ngoại & Ràng buộc: Tuân thủ 100% các bảng quan hệ 3NF.
  - Xóa mềm: Bảng `users` và `services` dùng `is_deleted = 1`. Các bảng giao dịch, hợp đồng, ví, tranh chấp có trigger cấm xóa vật lý (BR-30).

---

## 2. BẤT BIẾN TẬP HỢP TRẠNG THÁI (STATUS ENUMS)
Nghiêm cấm tự bịa các trạng thái lạ như `'PENDING'`, `'PAID'`, `'SUCCESS'`, `'DONE'`. Bắt buộc dùng đúng các giá trị enum sau:
- **`booking_items.status`:** `PENDING_VENDOR`, `AWAITING_DEPOSIT`, `CONFIRMED`, `FULLY_PAID`, `IN_PROGRESS`, `COMPLETED`, `REJECTED`, `EXPIRED`, `CANCELLED`, `DISPUTED`.
- **`bookings.status`:** `PENDING_VENDOR`, `AWAITING_DEPOSIT`, `ACTIVE`, `COMPLETED`, `CANCELLED`.
- **`contracts.status`:** `DRAFT`, `ACTIVE`, `COMPLETED`, `TERMINATED`, `EXPIRED`.
- **`contract_appendices.status`:** `ISSUED`, `SIGNED`, `VOIDED`.
- **`slot_locks.status`:** `ACTIVE`, `CONSUMED`, `RELEASED`, `EXPIRED`.
- **`escrow_holdings.status`:** `HELD`, `RELEASED`, `REFUNDED`, `PARTIALLY_REFUNDED`, `FROZEN`.
- **`disputes.status`:** `OPEN`, `VENDOR_RESPONDED`, `UNDER_REVIEW`, `RESOLVED`.
- **`users.status`:** `PENDING_VERIFY`, `ACTIVE`, `LOCKED`.
- **`vendors.status`:** `PENDING_KYC`, `APPROVED`, `REJECTED`, `SUSPENDED`.
- **`services.status`:** `DRAFT`, `ACTIVE`, `HIDDEN`.

---

## 3. CHUẨN GIAO TIẾP API (BACKEND & FRONTEND CONTRACT)
- Mọi Controller Backend bắt buộc bọc dữ liệu trả về qua class dùng chung `ApiResponse<T>`:
  ```json
  {
    "success": true,
    "message": "Thông điệp kết quả",
    "data": { ... },
    "timestamp": "2026-10-14T00:00:00Z"
  }
  ```
- Định danh tài nguyên RESTful chuẩn: danh từ số nhiều (ví dụ: `/api/services`, `/api/bookings`, `/api/wallets`).
- Frontend sử dụng Axios Interceptor tại `src/api/client.js` để tự động đính kèm `Authorization: Bearer <token>`.

---

## 4. BẢO VỆ TÍNH TOÀN VẸN SỔ CÁI KÉP & VÍ (DOUBLE-ENTRY LEDGER)
- Khi hạch toán bất kỳ biến động số dư nào trong hệ thống, bắt buộc ghi đủ 2 dòng đối ứng vào bảng `wallet_transactions` với cùng một `journal_id` (1 dòng `DEBIT` ví nguồn, 1 dòng `CREDIT` ví đích với số tiền bằng nhau tuyệt đối).
- Bất biến kiểm toán: View `vw_check_ledger_unbalanced` luôn phải trả về 0 dòng!

---

## 5. PHẠM VI TRÁCH NHIỆM FILE (MODULE SCOPING)
- AI chỉ được phép tạo mới hoặc chỉnh sửa file trong phạm vi module được người dùng giao việc.
- Tuyệt đối không chỉnh sửa đè lên `SecurityConfig.java`, file cấu hình chung, hoặc code thuộc quyền quản lý của thành viên khác nếu không được yêu cầu rõ ràng.
