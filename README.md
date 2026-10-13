# EventCraft — Intelligent Event Planning & Multi-Vendor Marketplace Platform

Nền tảng lập kế hoạch sự kiện & kết nối nhà cung cấp dịch vụ thông minh (B2B Quote-First Event Marketplace).
* **Môn học:** SWP391 (Syllabus ID: 14177) — Fall 2026 — Lớp SE20B04 — Đại học FPT Đà Nẵng.
* **Repository chính thức:** https://github.com/lethanhdat01072006-cmd/EventCraft-

---

## 👥 Đội Ngũ Phát Triển (Nhóm 5 Thành Viên)
1. **Lê Thành Đạt (Leader)** — Phụ trách Kiến trúc hệ thống, Core Booking Flow, Khóa Slot nguyên tử, Hợp đồng điện tử.
2. **Nam (Frontend Lead)** — Phụ trách Kiến trúc Frontend React 19, Luồng tạo sự kiện, Giỏ hàng, Ký hợp đồng & Thanh toán.
3. **Ly (Frontend & QA)** — Phụ trách Giao diện Vendor, Quản lý dịch vụ & lịch, Kiểm thử giao diện và kịch bản Test.
4. **Ngọc (Backend Developer)** — Phụ trách Master Data, Vendor KYC, Danh mục dịch vụ đơn/gói, Quản lý lịch bận.
5. **Hưng (Backend Developer)** — Phụ trách Bảo mật, Sổ cái kép đối ứng, Hệ thống Ví nội bộ, Ký quỹ Escrow, Tích hợp VNPay.

---

## 🛠️ Công Nghệ Chuẩn (Tech Stack)
* **Backend:** Spring Boot 3.3.4, Java 21 LTS, Spring Security 6, JJWT 0.11.5, Spring Data JPA, Lombok. Cổng chạy chuẩn: **`8080`**.
* **Frontend:** React 19, Vite 8.3, Tailwind CSS v4, Axios Interceptor, React Router v7, `@react-oauth/google`. Cổng chạy chuẩn: **`5173`**.
* **Cơ sở dữ liệu:** Microsoft SQL Server 2022/2025 (`EventCraft`), cổng **`1433`**, driver `mssql-jdbc`. Cấu hình `spring.jpa.hibernate.ddl-auto=none`.

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Dự Án

### 1. Cơ sở dữ liệu (Database)
1. Mở SQL Server Management Studio (SSMS) hoặc Azure Data Studio.
2. Mở file [database/schema_v1.0_49tables.sql](database/schema_v1.0_49tables.sql) và Execute toàn bộ script.
3. Kiểm tra: Đảm bảo cơ sở dữ liệu `EventCraft` được tạo thành công với đúng **49 bảng**, 19 triggers, 3 views và seed data.

### 2. Backend (Spring Boot)
```bash
cd backend
mvn clean install
mvn spring-boot:run
```
* Backend chạy tại: `http://localhost:8080`

### 3. Frontend (React 19 + Vite)
```bash
cd frontend
npm install
npm run dev
```
* Frontend chạy tại: `http://localhost:5173` (đã cấu hình Proxy `/api` tự động sang cổng 8080).

---

## 🤖 Hướng Dẫn Sử Dụng Trợ Lý AI (AI Single Source of Truth)
* **Thành viên dùng Antigravity IDE:** Hệ thống tự động nạp [AGENTS.md](AGENTS.md) và [CONTEXT.md](CONTEXT.md) làm luật bất biến.
* **Thành viên dùng Claude Web:** Mở file [CLAUDE_PROMPT_TEMPLATE.md](CLAUDE_PROMPT_TEMPLATE.md), copy đoạn prompt mẫu dán vào đầu mỗi phiên làm việc.
