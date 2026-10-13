/*
  EventCraft - Nền tảng lập kế hoạch sự kiện & kết nối nhà cung cấp dịch vụ thông minh
  Cơ sở dữ liệu Microsoft SQL Server 2019/2022 (T-SQL)

  Nội dung: 49 bảng, ràng buộc (PK, FK, UNIQUE, CHECK, DEFAULT), chỉ mục, trigger bảo vệ dữ liệu,
  view kiểm tra, dữ liệu danh mục (seed). Script dành cho cơ sở dữ liệu mới.

  Cách chạy: mở bằng SSMS hoặc Azure Data Studio và Execute (các lệnh GO là dấu ngắt batch).
  Chạy lại từ đầu: bỏ chú thích 2 dòng DROP ngay bên dưới.

  Quy ước: tiền là bigint (VND nguyên); thời gian lưu UTC (datetime2); trạng thái là varchar
  có CHECK; không xóa vật lý dữ liệu tiền, hợp đồng, báo giá, khiếu nại, đánh giá (BR-30).
*/
-- USE master; IF DB_ID(N'EventCraft') IS NOT NULL BEGIN ALTER DATABASE EventCraft SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE EventCraft; END
IF DB_ID(N'EventCraft') IS NULL CREATE DATABASE EventCraft COLLATE Vietnamese_100_CI_AS;
GO
USE EventCraft;
GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================================
-- 1. TABLES
-- ============================================================================
-- Identity & Vendor: Danh mục vai trò: HOST, VENDOR, ADMIN.
CREATE TABLE dbo.roles (
    role_id int IDENTITY(1,1) NOT NULL,
    role_name nvarchar(20) NOT NULL,
    CONSTRAINT pk_roles PRIMARY KEY (role_id),
    CONSTRAINT uq_roles_role_name UNIQUE (role_name)
);
GO

-- Identity & Vendor: Tài khoản người dùng. password_hash cho phép NULL với tài khoản chỉ đăng nhập Google; xóa mềm bằng is_deleted.
CREATE TABLE dbo.users (
    user_id bigint IDENTITY(1,1) NOT NULL,
    role_id int NOT NULL,
    email nvarchar(255) NOT NULL,
    password_hash nvarchar(255) NULL,
    full_name nvarchar(100) NOT NULL,
    phone varchar(20) NULL,
    avatar_url nvarchar(500) NULL,
    status varchar(20) NOT NULL CONSTRAINT df_users_status DEFAULT ('PENDING_VERIFY'),
    failed_login_count int NOT NULL CONSTRAINT df_users_failed_login_count DEFAULT (0),
    locked_until datetime2 NULL,
    is_deleted bit NOT NULL CONSTRAINT df_users_is_deleted DEFAULT (0),
    created_at datetime2 NOT NULL CONSTRAINT df_users_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_users PRIMARY KEY (user_id),
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT fk_users_role_id FOREIGN KEY (role_id) REFERENCES dbo.roles(role_id),
    CONSTRAINT ck_users_status CHECK (status IN ('PENDING_VERIFY', 'ACTIVE', 'LOCKED')),
    CONSTRAINT ck_users_email CHECK (email LIKE '%_@_%._%')
);
GO

-- Identity & Vendor: Liên kết tài khoản với nhà cung cấp định danh bên ngoài (Google). UNIQUE (provider, provider_user_id).
CREATE TABLE dbo.user_identities (
    identity_id bigint IDENTITY(1,1) NOT NULL,
    user_id bigint NOT NULL,
    provider varchar(20) NOT NULL,
    provider_user_id nvarchar(100) NOT NULL,
    email nvarchar(255) NOT NULL,
    created_at datetime2 NOT NULL CONSTRAINT df_user_identities_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_user_identities PRIMARY KEY (identity_id),
    CONSTRAINT fk_user_identities_user_id FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT ck_user_identities_provider CHECK (provider IN ('GOOGLE'))
);
GO

-- Identity & Vendor: Mã OTP cho đăng ký và quên mật khẩu; lưu trong cơ sở dữ liệu, hiệu lực 5 phút.
CREATE TABLE dbo.email_verifications (
    verification_id bigint IDENTITY(1,1) NOT NULL,
    user_id bigint NOT NULL,
    purpose varchar(20) NOT NULL,
    otp_hash nvarchar(255) NOT NULL,
    expires_at datetime2 NOT NULL,
    attempts int NOT NULL CONSTRAINT df_email_verifications_attempts DEFAULT (0),
    consumed_at datetime2 NULL,
    CONSTRAINT pk_email_verifications PRIMARY KEY (verification_id),
    CONSTRAINT fk_email_verifications_user_id FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT ck_email_verifications_purpose CHECK (purpose IN ('REGISTER', 'RESET_PASSWORD'))
);
GO

-- Identity & Vendor: Tài khoản ngân hàng dùng để rút tiền (nhập tay, mỗi người một tài khoản).
CREATE TABLE dbo.bank_accounts (
    bank_account_id bigint IDENTITY(1,1) NOT NULL,
    user_id bigint NOT NULL,
    bank_name nvarchar(100) NOT NULL,
    account_number varchar(30) NOT NULL,
    account_holder nvarchar(100) NOT NULL,
    CONSTRAINT pk_bank_accounts PRIMARY KEY (bank_account_id),
    CONSTRAINT uq_bank_accounts_user_id UNIQUE (user_id),
    CONSTRAINT fk_bank_accounts_user_id FOREIGN KEY (user_id) REFERENCES dbo.users(user_id)
);
GO

-- Identity & Vendor: Hồ sơ nhà cung cấp, quan hệ 1-1 với users. max_concurrent là số đơn chồng giờ tối đa của vendor.
CREATE TABLE dbo.vendors (
    vendor_id bigint IDENTITY(1,1) NOT NULL,
    user_id bigint NOT NULL,
    vendor_type varchar(15) NOT NULL,
    business_name nvarchar(150) NOT NULL,
    tax_code varchar(20) NULL,
    description nvarchar(max) NULL,
    city nvarchar(50) NOT NULL,
    district nvarchar(50) NULL,
    max_concurrent int NOT NULL CONSTRAINT df_vendors_max_concurrent DEFAULT (1),
    status varchar(20) NOT NULL CONSTRAINT df_vendors_status DEFAULT ('PENDING_KYC'),
    rating_avg decimal(3,2) NOT NULL CONSTRAINT df_vendors_rating_avg DEFAULT (0),
    review_count int NOT NULL CONSTRAINT df_vendors_review_count DEFAULT (0),
    created_at datetime2 NOT NULL CONSTRAINT df_vendors_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_vendors PRIMARY KEY (vendor_id),
    CONSTRAINT uq_vendors_user_id UNIQUE (user_id),
    CONSTRAINT fk_vendors_user_id FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT ck_vendors_vendor_type CHECK (vendor_type IN ('INDIVIDUAL', 'COMPANY')),
    CONSTRAINT ck_vendors_status CHECK (status IN ('PENDING_KYC', 'APPROVED', 'REJECTED', 'SUSPENDED')),
    CONSTRAINT ck_vendors_max_concurrent CHECK (max_concurrent >= 1),
    CONSTRAINT ck_vendors_rating CHECK (rating_avg BETWEEN 0 AND 5)
);
GO

-- Identity & Vendor: Lịch sử các lần nộp hồ sơ KYC của vendor (mỗi lần nộp một dòng).
CREATE TABLE dbo.kyc_submissions (
    kyc_id bigint IDENTITY(1,1) NOT NULL,
    vendor_id bigint NOT NULL,
    id_document_url nvarchar(500) NULL,
    business_license_url nvarchar(500) NULL,
    status varchar(15) NOT NULL CONSTRAINT df_kyc_submissions_status DEFAULT ('PENDING'),
    reject_reason nvarchar(500) NULL,
    submitted_at datetime2 NOT NULL CONSTRAINT df_kyc_submissions_submitted_at DEFAULT (SYSUTCDATETIME()),
    reviewed_by bigint NULL,
    reviewed_at datetime2 NULL,
    CONSTRAINT pk_kyc_submissions PRIMARY KEY (kyc_id),
    CONSTRAINT fk_kyc_submissions_vendor_id FOREIGN KEY (vendor_id) REFERENCES dbo.vendors(vendor_id),
    CONSTRAINT fk_kyc_submissions_reviewed_by FOREIGN KEY (reviewed_by) REFERENCES dbo.users(user_id),
    CONSTRAINT ck_kyc_submissions_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'))
);
GO

-- Identity & Vendor: Khoảng thời gian vendor tự chặn (bận, nghỉ lễ); được tính vào sức chứa.
CREATE TABLE dbo.availability_blocks (
    block_id bigint IDENTITY(1,1) NOT NULL,
    vendor_id bigint NOT NULL,
    start_at datetime2 NOT NULL,
    end_at datetime2 NOT NULL,
    reason nvarchar(200) NULL,
    CONSTRAINT pk_availability_blocks PRIMARY KEY (block_id),
    CONSTRAINT fk_availability_blocks_vendor_id FOREIGN KEY (vendor_id) REFERENCES dbo.vendors(vendor_id),
    CONSTRAINT ck_availability_blocks_time CHECK (end_at > start_at)
);
GO

-- Catalog: Loại sự kiện (dữ liệu cấu hình): tiệc cưới, sinh nhật, hội thảo, tiệc công ty.
CREATE TABLE dbo.event_types (
    event_type_id int IDENTITY(1,1) NOT NULL,
    code varchar(30) NOT NULL,
    name nvarchar(100) NOT NULL,
    CONSTRAINT pk_event_types PRIMARY KEY (event_type_id),
    CONSTRAINT uq_event_types_code UNIQUE (code)
);
GO

-- Catalog: Danh mục dịch vụ (dữ liệu cấu hình): địa điểm, tiệc, trang trí, âm thanh ánh sáng, MC, quay chụp.
CREATE TABLE dbo.service_categories (
    category_id int IDENTITY(1,1) NOT NULL,
    code varchar(30) NOT NULL,
    name nvarchar(100) NOT NULL,
    CONSTRAINT pk_service_categories PRIMARY KEY (category_id),
    CONSTRAINT uq_service_categories_code UNIQUE (code)
);
GO

-- Catalog: Thẻ mô tả dịch vụ (phong cách, ẩm thực, khu vực phục vụ).
CREATE TABLE dbo.tags (
    tag_id int IDENTITY(1,1) NOT NULL,
    name nvarchar(50) NOT NULL,
    tag_group varchar(20) NOT NULL,
    CONSTRAINT pk_tags PRIMARY KEY (tag_id),
    CONSTRAINT ck_tags_tag_group CHECK (tag_group IN ('STYLE', 'CUISINE', 'AREA'))
);
GO

-- Catalog: Dịch vụ do vendor đăng bán. service_kind phân biệt dịch vụ lẻ (SINGLE) và gói trọn gói (BUNDLE, category_id để trống). Xóa mềm bằng is_deleted.
CREATE TABLE dbo.services (
    service_id bigint IDENTITY(1,1) NOT NULL,
    vendor_id bigint NOT NULL,
    category_id int NULL,
    service_kind varchar(10) NOT NULL CONSTRAINT df_services_service_kind DEFAULT ('SINGLE'),
    name nvarchar(150) NOT NULL,
    description nvarchar(max) NULL,
    booking_mode varchar(5) NOT NULL,
    pricing_unit varchar(15) NOT NULL,
    unit_price bigint NOT NULL,
    guest_capacity int NULL,
    open_time time NULL,
    close_time time NULL,
    min_hours int NULL,
    city nvarchar(50) NOT NULL,
    district nvarchar(50) NULL,
    address nvarchar(300) NULL,
    status varchar(10) NOT NULL CONSTRAINT df_services_status DEFAULT ('DRAFT'),
    rating_avg decimal(3,2) NOT NULL CONSTRAINT df_services_rating_avg DEFAULT (0),
    review_count int NOT NULL CONSTRAINT df_services_review_count DEFAULT (0),
    is_deleted bit NOT NULL CONSTRAINT df_services_is_deleted DEFAULT (0),
    CONSTRAINT pk_services PRIMARY KEY (service_id),
    CONSTRAINT fk_services_vendor_id FOREIGN KEY (vendor_id) REFERENCES dbo.vendors(vendor_id),
    CONSTRAINT fk_services_category_id FOREIGN KEY (category_id) REFERENCES dbo.service_categories(category_id),
    CONSTRAINT ck_services_service_kind CHECK (service_kind IN ('SINGLE', 'BUNDLE')),
    CONSTRAINT ck_services_booking_mode CHECK (booking_mode IN ('DAY', 'HOUR')),
    CONSTRAINT ck_services_pricing_unit CHECK (pricing_unit IN ('PACKAGE', 'PER_PERSON', 'PER_TABLE', 'PER_HOUR', 'PER_DAY')),
    CONSTRAINT ck_services_status CHECK (status IN ('DRAFT', 'ACTIVE', 'HIDDEN')),
    CONSTRAINT ck_services_price CHECK (unit_price > 0),
    CONSTRAINT ck_services_kind_category CHECK ((service_kind = 'SINGLE' AND category_id IS NOT NULL) OR (service_kind = 'BUNDLE' AND category_id IS NULL)),
    CONSTRAINT ck_services_capacity CHECK (guest_capacity IS NULL OR guest_capacity > 0),
    CONSTRAINT ck_services_min_hours CHECK (min_hours IS NULL OR min_hours > 0),
    CONSTRAINT ck_services_hours_time CHECK ((open_time IS NULL AND close_time IS NULL) OR (open_time IS NOT NULL AND close_time IS NOT NULL AND close_time <> open_time))
);
GO

-- Catalog: Bảng nối nhiều-nhiều giữa dịch vụ và thẻ.
CREATE TABLE dbo.service_tags (
    service_id bigint NOT NULL,
    tag_id int NOT NULL,
    CONSTRAINT pk_service_tags PRIMARY KEY (service_id, tag_id),
    CONSTRAINT fk_service_tags_service_id FOREIGN KEY (service_id) REFERENCES dbo.services(service_id) ON DELETE CASCADE,
    CONSTRAINT fk_service_tags_tag_id FOREIGN KEY (tag_id) REFERENCES dbo.tags(tag_id) ON DELETE CASCADE
);
GO

-- Catalog: Danh mục thuộc một gói trọn gói và tỷ lệ phân bổ ngân sách (tổng 100%).
CREATE TABLE dbo.service_bundle_categories (
    bundle_cat_id bigint IDENTITY(1,1) NOT NULL,
    service_id bigint NOT NULL,
    category_id int NOT NULL,
    allocation_percent decimal(5,2) NOT NULL,
    description nvarchar(200) NULL,
    CONSTRAINT pk_service_bundle_categories PRIMARY KEY (bundle_cat_id),
    CONSTRAINT fk_service_bundle_categories_service_id FOREIGN KEY (service_id) REFERENCES dbo.services(service_id) ON DELETE CASCADE,
    CONSTRAINT fk_service_bundle_categories_category_id FOREIGN KEY (category_id) REFERENCES dbo.service_categories(category_id),
    CONSTRAINT ck_service_bundle_categories_pct CHECK (allocation_percent > 0 AND allocation_percent <= 100)
);
GO

-- Catalog: Ảnh portfolio của dịch vụ.
CREATE TABLE dbo.service_images (
    image_id bigint IDENTITY(1,1) NOT NULL,
    service_id bigint NOT NULL,
    image_url nvarchar(500) NOT NULL,
    sort_order int NOT NULL,
    CONSTRAINT pk_service_images PRIMARY KEY (image_id),
    CONSTRAINT fk_service_images_service_id FOREIGN KEY (service_id) REFERENCES dbo.services(service_id) ON DELETE CASCADE
);
GO

-- Event Planning: Sự kiện của Host. Ngày và thành phố bị khóa từ lúc gửi yêu cầu đặt đầu tiên (kiểm tra bằng mã nguồn).
CREATE TABLE dbo.events (
    event_id bigint IDENTITY(1,1) NOT NULL,
    user_id bigint NOT NULL,
    event_type_id int NOT NULL,
    name nvarchar(150) NOT NULL,
    event_date date NOT NULL,
    start_time time NOT NULL,
    end_time time NOT NULL,
    city nvarchar(50) NOT NULL,
    venue_mode varchar(10) NOT NULL,
    venue_address nvarchar(300) NULL,
    guest_count int NOT NULL,
    total_budget bigint NOT NULL,
    status varchar(15) NOT NULL CONSTRAINT df_events_status DEFAULT ('DRAFT'),
    created_at datetime2 NOT NULL CONSTRAINT df_events_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_events PRIMARY KEY (event_id),
    CONSTRAINT fk_events_user_id FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT fk_events_event_type_id FOREIGN KEY (event_type_id) REFERENCES dbo.event_types(event_type_id),
    CONSTRAINT ck_events_venue_mode CHECK (venue_mode IN ('PLATFORM', 'OWN')),
    CONSTRAINT ck_events_status CHECK (status IN ('DRAFT', 'PLANNING', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT ck_events_time CHECK (end_time > start_time),
    CONSTRAINT ck_events_guest CHECK (guest_count > 0),
    CONSTRAINT ck_events_budget CHECK (total_budget > 0),
    CONSTRAINT ck_events_venue CHECK (venue_mode = 'PLATFORM' OR venue_address IS NOT NULL)
);
GO

-- Event Planning: Bảng tỷ lệ ngân sách mặc định theo loại sự kiện và danh mục (cũng là dự phòng khi AI lỗi).
CREATE TABLE dbo.event_type_budget_defaults (
    default_id int IDENTITY(1,1) NOT NULL,
    event_type_id int NOT NULL,
    category_id int NOT NULL,
    [percent] decimal(5,2) NOT NULL,
    CONSTRAINT pk_event_type_budget_defaults PRIMARY KEY (default_id),
    CONSTRAINT fk_event_type_budget_defaults_event_type_id FOREIGN KEY (event_type_id) REFERENCES dbo.event_types(event_type_id),
    CONSTRAINT fk_event_type_budget_defaults_category_id FOREIGN KEY (category_id) REFERENCES dbo.service_categories(category_id),
    CONSTRAINT ck_event_type_budget_defaults_pct CHECK ([percent] > 0 AND [percent] <= 100)
);
GO

-- Event Planning: Hạng mục ngân sách của sự kiện: theo danh mục, hạng mục tùy chỉnh hoặc quỹ dự phòng.
CREATE TABLE dbo.event_budget_items (
    budget_item_id bigint IDENTITY(1,1) NOT NULL,
    event_id bigint NOT NULL,
    category_id int NULL,
    item_name nvarchar(100) NOT NULL,
    planned_amount bigint NOT NULL,
    source varchar(10) NOT NULL CONSTRAINT df_event_budget_items_source DEFAULT ('DEFAULT'),
    is_custom bit NOT NULL CONSTRAINT df_event_budget_items_is_custom DEFAULT (0),
    is_reserve bit NOT NULL CONSTRAINT df_event_budget_items_is_reserve DEFAULT (0),
    CONSTRAINT pk_event_budget_items PRIMARY KEY (budget_item_id),
    CONSTRAINT fk_event_budget_items_event_id FOREIGN KEY (event_id) REFERENCES dbo.events(event_id),
    CONSTRAINT fk_event_budget_items_category_id FOREIGN KEY (category_id) REFERENCES dbo.service_categories(category_id),
    CONSTRAINT ck_event_budget_items_source CHECK (source IN ('DEFAULT', 'AI', 'USER', 'BUNDLE')),
    CONSTRAINT ck_event_budget_items_amount CHECK (planned_amount >= 0),
    CONSTRAINT ck_event_budget_items_reserve CHECK (is_reserve = 0 OR category_id IS NULL)
);
GO

-- Event Planning: Mẫu checklist theo loại sự kiện; offset_days là số ngày lùi từ ngày sự kiện.
CREATE TABLE dbo.checklist_template_items (
    template_item_id int IDENTITY(1,1) NOT NULL,
    event_type_id int NOT NULL,
    title nvarchar(200) NOT NULL,
    offset_days int NOT NULL,
    category_id int NULL,
    CONSTRAINT pk_checklist_template_items PRIMARY KEY (template_item_id),
    CONSTRAINT fk_checklist_template_items_event_type_id FOREIGN KEY (event_type_id) REFERENCES dbo.event_types(event_type_id),
    CONSTRAINT fk_checklist_template_items_category_id FOREIGN KEY (category_id) REFERENCES dbo.service_categories(category_id),
    CONSTRAINT ck_checklist_template_items_offset CHECK (offset_days >= 0)
);
GO

-- Event Planning: Đầu việc của một sự kiện, sinh từ mẫu hoặc Host tự thêm.
CREATE TABLE dbo.event_checklist_items (
    checklist_id bigint IDENTITY(1,1) NOT NULL,
    event_id bigint NOT NULL,
    title nvarchar(200) NOT NULL,
    due_date date NOT NULL,
    category_id int NULL,
    is_done bit NOT NULL CONSTRAINT df_event_checklist_items_is_done DEFAULT (0),
    done_at datetime2 NULL,
    auto_completed bit NOT NULL CONSTRAINT df_event_checklist_items_auto_completed DEFAULT (0),
    overdue_notified bit NOT NULL CONSTRAINT df_event_checklist_items_overdue_notified DEFAULT (0),
    CONSTRAINT pk_event_checklist_items PRIMARY KEY (checklist_id),
    CONSTRAINT fk_event_checklist_items_event_id FOREIGN KEY (event_id) REFERENCES dbo.events(event_id),
    CONSTRAINT fk_event_checklist_items_category_id FOREIGN KEY (category_id) REFERENCES dbo.service_categories(category_id)
);
GO

-- Event Planning: Lịch sử mỗi lần gọi AI (hoặc dùng bảng mặc định) để ước tính ngân sách.
CREATE TABLE dbo.budget_estimates (
    estimate_id bigint IDENTITY(1,1) NOT NULL,
    event_id bigint NOT NULL,
    requested_by bigint NOT NULL,
    input_note nvarchar(500) NULL,
    source varchar(10) NOT NULL,
    status varchar(10) NOT NULL CONSTRAINT df_budget_estimates_status DEFAULT ('SUCCESS'),
    applied bit NOT NULL CONSTRAINT df_budget_estimates_applied DEFAULT (0),
    created_at datetime2 NOT NULL CONSTRAINT df_budget_estimates_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_budget_estimates PRIMARY KEY (estimate_id),
    CONSTRAINT fk_budget_estimates_event_id FOREIGN KEY (event_id) REFERENCES dbo.events(event_id),
    CONSTRAINT fk_budget_estimates_requested_by FOREIGN KEY (requested_by) REFERENCES dbo.users(user_id),
    CONSTRAINT ck_budget_estimates_source CHECK (source IN ('AI', 'DEFAULT')),
    CONSTRAINT ck_budget_estimates_status CHECK (status IN ('SUCCESS', 'FALLBACK'))
);
GO

-- Event Planning: Chi tiết số tiền và phần trăm theo danh mục của một lần ước tính.
CREATE TABLE dbo.budget_estimate_items (
    estimate_item_id bigint IDENTITY(1,1) NOT NULL,
    estimate_id bigint NOT NULL,
    category_id int NOT NULL,
    [percent] decimal(5,2) NOT NULL,
    amount bigint NOT NULL,
    CONSTRAINT pk_budget_estimate_items PRIMARY KEY (estimate_item_id),
    CONSTRAINT fk_budget_estimate_items_estimate_id FOREIGN KEY (estimate_id) REFERENCES dbo.budget_estimates(estimate_id) ON DELETE CASCADE,
    CONSTRAINT fk_budget_estimate_items_category_id FOREIGN KEY (category_id) REFERENCES dbo.service_categories(category_id),
    CONSTRAINT ck_budget_estimate_items_pct CHECK ([percent] BETWEEN 0 AND 100),
    CONSTRAINT ck_budget_estimate_items_amount CHECK (amount >= 0)
);
GO

-- Event Planning: Các phương án tổ hợp vendor đã gợi ý (Knapsack) cho một sự kiện.
CREATE TABLE dbo.plan_recommendations (
    recommendation_id bigint IDENTITY(1,1) NOT NULL,
    event_id bigint NOT NULL,
    mode varchar(10) NOT NULL,
    rank_no int NOT NULL,
    total_price bigint NOT NULL,
    total_score decimal(8,4) NOT NULL,
    shortfall bigint NULL,
    reason nvarchar(1000) NULL,
    created_at datetime2 NOT NULL CONSTRAINT df_plan_recommendations_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_plan_recommendations PRIMARY KEY (recommendation_id),
    CONSTRAINT fk_plan_recommendations_event_id FOREIGN KEY (event_id) REFERENCES dbo.events(event_id),
    CONSTRAINT ck_plan_recommendations_mode CHECK (mode IN ('SAVING', 'BALANCED', 'QUALITY')),
    CONSTRAINT ck_plan_recommendations_rank CHECK (rank_no BETWEEN 1 AND 3),
    CONSTRAINT ck_plan_recommendations_price CHECK (total_price >= 0)
);
GO

-- Event Planning: Dịch vụ thuộc một phương án gợi ý, gắn với hạng mục ngân sách.
CREATE TABLE dbo.plan_recommendation_items (
    rec_item_id bigint IDENTITY(1,1) NOT NULL,
    recommendation_id bigint NOT NULL,
    service_id bigint NOT NULL,
    budget_item_id bigint NOT NULL,
    price bigint NOT NULL,
    score decimal(8,4) NOT NULL,
    is_locked bit NOT NULL CONSTRAINT df_plan_recommendation_items_is_locked DEFAULT (0),
    CONSTRAINT pk_plan_recommendation_items PRIMARY KEY (rec_item_id),
    CONSTRAINT fk_plan_recommendation_items_recommendation_id FOREIGN KEY (recommendation_id) REFERENCES dbo.plan_recommendations(recommendation_id) ON DELETE CASCADE,
    CONSTRAINT fk_plan_recommendation_items_service_id FOREIGN KEY (service_id) REFERENCES dbo.services(service_id),
    CONSTRAINT fk_plan_recommendation_items_budget_item_id FOREIGN KEY (budget_item_id) REFERENCES dbo.event_budget_items(budget_item_id)
);
GO

-- Event Planning: Kịch bản sự kiện theo giờ; mỗi dòng gắn một vendor phụ trách.
CREATE TABLE dbo.runsheet_items (
    runsheet_id bigint IDENTITY(1,1) NOT NULL,
    event_id bigint NOT NULL,
    vendor_id bigint NOT NULL,
    start_time time NOT NULL,
    end_time time NOT NULL,
    title nvarchar(200) NOT NULL,
    description nvarchar(500) NULL,
    status varchar(10) NOT NULL CONSTRAINT df_runsheet_items_status DEFAULT ('PLANNED'),
    confirmed_at datetime2 NULL,
    CONSTRAINT pk_runsheet_items PRIMARY KEY (runsheet_id),
    CONSTRAINT fk_runsheet_items_event_id FOREIGN KEY (event_id) REFERENCES dbo.events(event_id),
    CONSTRAINT fk_runsheet_items_vendor_id FOREIGN KEY (vendor_id) REFERENCES dbo.vendors(vendor_id),
    CONSTRAINT ck_runsheet_items_status CHECK (status IN ('PLANNED', 'CONFIRMED', 'DONE')),
    CONSTRAINT ck_runsheet_items_time CHECK (end_time > start_time)
);
GO

-- Booking & Contract: Giỏ hàng, mỗi sự kiện một giỏ riêng.
CREATE TABLE dbo.carts (
    cart_id bigint IDENTITY(1,1) NOT NULL,
    event_id bigint NOT NULL,
    CONSTRAINT pk_carts PRIMARY KEY (cart_id),
    CONSTRAINT uq_carts_event_id UNIQUE (event_id),
    CONSTRAINT fk_carts_event_id FOREIGN KEY (event_id) REFERENCES dbo.events(event_id)
);
GO

-- Booking & Contract: Dịch vụ trong giỏ (chưa giữ chỗ).
CREATE TABLE dbo.cart_items (
    cart_item_id bigint IDENTITY(1,1) NOT NULL,
    cart_id bigint NOT NULL,
    service_id bigint NOT NULL,
    budget_item_id bigint NULL,
    start_at datetime2 NOT NULL,
    end_at datetime2 NOT NULL,
    quantity int NOT NULL,
    CONSTRAINT pk_cart_items PRIMARY KEY (cart_item_id),
    CONSTRAINT fk_cart_items_cart_id FOREIGN KEY (cart_id) REFERENCES dbo.carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_cart_items_service_id FOREIGN KEY (service_id) REFERENCES dbo.services(service_id),
    CONSTRAINT fk_cart_items_budget_item_id FOREIGN KEY (budget_item_id) REFERENCES dbo.event_budget_items(budget_item_id),
    CONSTRAINT ck_cart_items_time CHECK (end_at > start_at),
    CONSTRAINT ck_cart_items_qty CHECK (quantity > 0)
);
GO

-- Booking & Contract: Đơn đặt: mỗi lần Host gửi yêu cầu là một đơn. Trạng thái được suy ra từ các booking_items và lưu để truy vấn nhanh.
CREATE TABLE dbo.bookings (
    booking_id bigint IDENTITY(1,1) NOT NULL,
    event_id bigint NOT NULL,
    status varchar(20) NOT NULL CONSTRAINT df_bookings_status DEFAULT ('PENDING_VENDOR'),
    pay_deadline datetime2 NULL,
    created_at datetime2 NOT NULL CONSTRAINT df_bookings_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_bookings PRIMARY KEY (booking_id),
    CONSTRAINT fk_bookings_event_id FOREIGN KEY (event_id) REFERENCES dbo.events(event_id),
    CONSTRAINT ck_bookings_status CHECK (status IN ('PENDING_VENDOR', 'AWAITING_DEPOSIT', 'ACTIVE', 'COMPLETED', 'CANCELLED'))
);
GO

-- Booking & Contract: Dịch vụ trong đơn; mang trạng thái riêng (PENDING_VENDOR, AWAITING_DEPOSIT, CONFIRMED, FULLY_PAID, IN_PROGRESS, COMPLETED, REJECTED, EXPIRED, CANCELLED, DISPUTED) và giá chốt.
CREATE TABLE dbo.booking_items (
    booking_item_id bigint IDENTITY(1,1) NOT NULL,
    booking_id bigint NOT NULL,
    service_id bigint NOT NULL,
    vendor_id bigint NOT NULL,
    start_at datetime2 NOT NULL,
    end_at datetime2 NOT NULL,
    quantity int NOT NULL,
    unit_price bigint NOT NULL,
    total_amount bigint NOT NULL,
    deposit_amount bigint NOT NULL,
    remaining_amount bigint NOT NULL,
    status varchar(20) NOT NULL CONSTRAINT df_booking_items_status DEFAULT ('PENDING_VENDOR'),
    respond_deadline datetime2 NULL,
    created_at datetime2 NOT NULL CONSTRAINT df_booking_items_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_booking_items PRIMARY KEY (booking_item_id),
    CONSTRAINT fk_booking_items_booking_id FOREIGN KEY (booking_id) REFERENCES dbo.bookings(booking_id),
    CONSTRAINT fk_booking_items_service_id FOREIGN KEY (service_id) REFERENCES dbo.services(service_id),
    CONSTRAINT fk_booking_items_vendor_id FOREIGN KEY (vendor_id) REFERENCES dbo.vendors(vendor_id),
    CONSTRAINT ck_booking_items_status CHECK (status IN ('PENDING_VENDOR', 'AWAITING_DEPOSIT', 'CONFIRMED', 'FULLY_PAID', 'IN_PROGRESS', 'COMPLETED', 'REJECTED', 'EXPIRED', 'CANCELLED', 'DISPUTED')),
    CONSTRAINT ck_booking_items_time CHECK (end_at > start_at),
    CONSTRAINT ck_booking_items_qty CHECK (quantity > 0),
    CONSTRAINT ck_booking_items_amounts CHECK (unit_price >= 0 AND total_amount >= 0 AND deposit_amount >= 0 AND remaining_amount >= 0),
    CONSTRAINT ck_booking_items_split CHECK (deposit_amount + remaining_amount = total_amount)
);
GO

-- Booking & Contract: Chia tiền của một dịch vụ vào các hạng mục ngân sách (gói trọn gói chia nhiều hạng mục). Tổng amount bằng total_amount.
CREATE TABLE dbo.booking_item_allocations (
    allocation_id bigint IDENTITY(1,1) NOT NULL,
    booking_item_id bigint NOT NULL,
    budget_item_id bigint NOT NULL,
    quote_id bigint NULL,
    amount bigint NOT NULL,
    CONSTRAINT pk_booking_item_allocations PRIMARY KEY (allocation_id),
    CONSTRAINT fk_booking_item_allocations_booking_item_id FOREIGN KEY (booking_item_id) REFERENCES dbo.booking_items(booking_item_id),
    CONSTRAINT fk_booking_item_allocations_budget_item_id FOREIGN KEY (budget_item_id) REFERENCES dbo.event_budget_items(budget_item_id),
    CONSTRAINT ck_booking_item_allocations_amount CHECK (amount >= 0)
);
GO

-- Booking & Contract: Chỗ giữ cho Host bắt đầu từ lúc vendor duyệt đến hết hạn trả cọc.
CREATE TABLE dbo.slot_locks (
    lock_id bigint IDENTITY(1,1) NOT NULL,
    booking_item_id bigint NOT NULL,
    vendor_id bigint NOT NULL,
    start_at datetime2 NOT NULL,
    end_at datetime2 NOT NULL,
    expires_at datetime2 NOT NULL,
    status varchar(10) NOT NULL CONSTRAINT df_slot_locks_status DEFAULT ('ACTIVE'),
    CONSTRAINT pk_slot_locks PRIMARY KEY (lock_id),
    CONSTRAINT uq_slot_locks_booking_item_id UNIQUE (booking_item_id),
    CONSTRAINT fk_slot_locks_booking_item_id FOREIGN KEY (booking_item_id) REFERENCES dbo.booking_items(booking_item_id),
    CONSTRAINT fk_slot_locks_vendor_id FOREIGN KEY (vendor_id) REFERENCES dbo.vendors(vendor_id),
    CONSTRAINT ck_slot_locks_status CHECK (status IN ('ACTIVE', 'CONSUMED', 'RELEASED', 'EXPIRED')),
    CONSTRAINT ck_slot_locks_time CHECK (end_at > start_at)
);
GO

-- Booking & Contract: Hợp đồng khung của một đơn, lưu bản sao nội dung tại thời điểm Host đồng ý.
CREATE TABLE dbo.contracts (
    contract_id bigint IDENTITY(1,1) NOT NULL,
    booking_id bigint NOT NULL,
    template_version varchar(10) NOT NULL,
    content_snapshot nvarchar(max) NOT NULL,
    status varchar(15) NOT NULL CONSTRAINT df_contracts_status DEFAULT ('DRAFT'),
    signed_at datetime2 NULL,
    signed_ip varchar(45) NULL,
    created_at datetime2 NOT NULL CONSTRAINT df_contracts_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_contracts PRIMARY KEY (contract_id),
    CONSTRAINT uq_contracts_booking_id UNIQUE (booking_id),
    CONSTRAINT fk_contracts_booking_id FOREIGN KEY (booking_id) REFERENCES dbo.bookings(booking_id),
    CONSTRAINT ck_contracts_status CHECK (status IN ('DRAFT', 'ACTIVE', 'COMPLETED', 'TERMINATED', 'EXPIRED'))
);
GO

-- Booking & Contract: Phụ lục riêng của từng vendor (phạm vi, điều khoản, giá chốt).
CREATE TABLE dbo.contract_appendices (
    appendix_id bigint IDENTITY(1,1) NOT NULL,
    contract_id bigint NOT NULL,
    booking_item_id bigint NOT NULL,
    scope nvarchar(max) NOT NULL,
    terms nvarchar(max) NULL,
    price_snapshot bigint NOT NULL,
    status varchar(10) NOT NULL CONSTRAINT df_contract_appendices_status DEFAULT ('ISSUED'),
    issued_at datetime2 NOT NULL CONSTRAINT df_contract_appendices_issued_at DEFAULT (SYSUTCDATETIME()),
    signed_at datetime2 NULL,
    CONSTRAINT pk_contract_appendices PRIMARY KEY (appendix_id),
    CONSTRAINT uq_contract_appendices_booking_item_id UNIQUE (booking_item_id),
    CONSTRAINT fk_contract_appendices_contract_id FOREIGN KEY (contract_id) REFERENCES dbo.contracts(contract_id),
    CONSTRAINT fk_contract_appendices_booking_item_id FOREIGN KEY (booking_item_id) REFERENCES dbo.booking_items(booking_item_id),
    CONSTRAINT ck_contract_appendices_status CHECK (status IN ('ISSUED', 'SIGNED', 'VOID')),
    CONSTRAINT ck_contract_appendices_price CHECK (price_snapshot >= 0)
);
GO

-- Booking & Contract: Báo giá phát sinh của vendor; replaces_quote_id trỏ tới báo giá bị thay thế.
CREATE TABLE dbo.addendum_quotes (
    quote_id bigint IDENTITY(1,1) NOT NULL,
    booking_item_id bigint NOT NULL,
    vendor_id bigint NOT NULL,
    target_category_id int NOT NULL,
    title nvarchar(150) NOT NULL,
    description nvarchar(1000) NULL,
    amount bigint NOT NULL,
    status varchar(10) NOT NULL CONSTRAINT df_addendum_quotes_status DEFAULT ('SENT'),
    expires_at datetime2 NOT NULL,
    replaces_quote_id bigint NULL,
    created_at datetime2 NOT NULL CONSTRAINT df_addendum_quotes_created_at DEFAULT (SYSUTCDATETIME()),
    decided_at datetime2 NULL,
    CONSTRAINT pk_addendum_quotes PRIMARY KEY (quote_id),
    CONSTRAINT fk_addendum_quotes_booking_item_id FOREIGN KEY (booking_item_id) REFERENCES dbo.booking_items(booking_item_id),
    CONSTRAINT fk_addendum_quotes_vendor_id FOREIGN KEY (vendor_id) REFERENCES dbo.vendors(vendor_id),
    CONSTRAINT fk_addendum_quotes_target_category_id FOREIGN KEY (target_category_id) REFERENCES dbo.service_categories(category_id),
    CONSTRAINT fk_addendum_quotes_replaces_quote_id FOREIGN KEY (replaces_quote_id) REFERENCES dbo.addendum_quotes(quote_id),
    CONSTRAINT ck_addendum_quotes_status CHECK (status IN ('SENT', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'WITHDRAWN')),
    CONSTRAINT ck_addendum_quotes_amount CHECK (amount > 0)
);
GO

ALTER TABLE dbo.booking_item_allocations
ADD CONSTRAINT fk_booking_item_allocations_quote_id FOREIGN KEY (quote_id) REFERENCES dbo.addendum_quotes(quote_id);
GO

-- Payment & Escrow: Ví: USER (Host, Vendor), ESCROW_POOL, PLATFORM, EXTERNAL (ngoài hệ thống: VNPay, ngân hàng).
CREATE TABLE dbo.wallets (
    wallet_id bigint IDENTITY(1,1) NOT NULL,
    user_id bigint NULL,
    wallet_type varchar(15) NOT NULL,
    balance bigint NOT NULL CONSTRAINT df_wallets_balance DEFAULT (0),
    CONSTRAINT pk_wallets PRIMARY KEY (wallet_id),
    CONSTRAINT fk_wallets_user_id FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT ck_wallets_wallet_type CHECK (wallet_type IN ('USER', 'ESCROW_POOL', 'PLATFORM', 'EXTERNAL')),
    CONSTRAINT ck_wallets_balance CHECK (wallet_type = 'EXTERNAL' OR balance >= 0),
    CONSTRAINT ck_wallets_owner CHECK ((wallet_type = 'USER' AND user_id IS NOT NULL) OR (wallet_type <> 'USER' AND user_id IS NULL))
);
GO

-- Payment & Escrow: Giao dịch thanh toán của Host: DEPOSIT, REMAINING hoặc ADDENDUM; qua VNPay hoặc ví. vnp_txn_ref và idempotency_key chống xử lý trùng.
CREATE TABLE dbo.payments (
    payment_id bigint IDENTITY(1,1) NOT NULL,
    booking_id bigint NOT NULL,
    user_id bigint NOT NULL,
    payment_kind varchar(10) NOT NULL,
    method varchar(10) NOT NULL,
    amount bigint NOT NULL,
    status varchar(10) NOT NULL CONSTRAINT df_payments_status DEFAULT ('INITIATED'),
    vnp_txn_ref varchar(40) NULL,
    vnp_transaction_no varchar(40) NULL,
    idempotency_key varchar(64) NULL,
    expires_at datetime2 NOT NULL,
    paid_at datetime2 NULL,
    CONSTRAINT pk_payments PRIMARY KEY (payment_id),
    CONSTRAINT fk_payments_booking_id FOREIGN KEY (booking_id) REFERENCES dbo.bookings(booking_id),
    CONSTRAINT fk_payments_user_id FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT ck_payments_payment_kind CHECK (payment_kind IN ('DEPOSIT', 'REMAINING', 'ADDENDUM')),
    CONSTRAINT ck_payments_method CHECK (method IN ('VNPAY', 'WALLET')),
    CONSTRAINT ck_payments_status CHECK (status IN ('INITIATED', 'SUCCESS', 'FAILED', 'EXPIRED')),
    CONSTRAINT ck_payments_amount CHECK (amount > 0),
    CONSTRAINT ck_payments_method_ref CHECK ((method = 'VNPAY' AND vnp_txn_ref IS NOT NULL) OR (method = 'WALLET' AND idempotency_key IS NOT NULL))
);
GO

-- Payment & Escrow: Phần của một giao dịch thanh toán thuộc về từng dịch vụ (hoặc báo giá phát sinh).
CREATE TABLE dbo.payment_items (
    payment_item_id bigint IDENTITY(1,1) NOT NULL,
    payment_id bigint NOT NULL,
    booking_item_id bigint NOT NULL,
    quote_id bigint NULL,
    amount bigint NOT NULL,
    CONSTRAINT pk_payment_items PRIMARY KEY (payment_item_id),
    CONSTRAINT fk_payment_items_payment_id FOREIGN KEY (payment_id) REFERENCES dbo.payments(payment_id),
    CONSTRAINT fk_payment_items_booking_item_id FOREIGN KEY (booking_item_id) REFERENCES dbo.booking_items(booking_item_id),
    CONSTRAINT fk_payment_items_quote_id FOREIGN KEY (quote_id) REFERENCES dbo.addendum_quotes(quote_id),
    CONSTRAINT ck_payment_items_amount CHECK (amount > 0)
);
GO

-- Payment & Escrow: Khoản ký quỹ riêng của từng dịch vụ (HELD, RELEASED, REFUNDED, PARTIALLY_REFUNDED, FROZEN).
CREATE TABLE dbo.escrow_holdings (
    escrow_id bigint IDENTITY(1,1) NOT NULL,
    booking_item_id bigint NOT NULL,
    amount_held bigint NOT NULL,
    released_amount bigint NOT NULL CONSTRAINT df_escrow_holdings_released_amount DEFAULT (0),
    refunded_amount bigint NOT NULL CONSTRAINT df_escrow_holdings_refunded_amount DEFAULT (0),
    fee_amount bigint NOT NULL CONSTRAINT df_escrow_holdings_fee_amount DEFAULT (0),
    status varchar(20) NOT NULL CONSTRAINT df_escrow_holdings_status DEFAULT ('HELD'),
    reason nvarchar(200) NULL,
    updated_at datetime2 NOT NULL CONSTRAINT df_escrow_holdings_updated_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_escrow_holdings PRIMARY KEY (escrow_id),
    CONSTRAINT uq_escrow_holdings_booking_item_id UNIQUE (booking_item_id),
    CONSTRAINT fk_escrow_holdings_booking_item_id FOREIGN KEY (booking_item_id) REFERENCES dbo.booking_items(booking_item_id),
    CONSTRAINT ck_escrow_holdings_status CHECK (status IN ('HELD', 'RELEASED', 'REFUNDED', 'PARTIALLY_REFUNDED', 'FROZEN')),
    CONSTRAINT ck_escrow_holdings_amounts CHECK (amount_held >= 0 AND released_amount >= 0 AND refunded_amount >= 0 AND fee_amount >= 0)
);
GO

-- Payment & Escrow: Sổ cái kép: mỗi biến động tiền ghi hai dòng (ví nguồn ghi nợ, ví đích ghi có) cùng journal_id.
CREATE TABLE dbo.wallet_transactions (
    txn_id bigint IDENTITY(1,1) NOT NULL,
    journal_id varchar(36) NOT NULL,
    wallet_id bigint NOT NULL,
    direction varchar(6) NOT NULL,
    amount bigint NOT NULL,
    txn_type varchar(20) NOT NULL,
    ref_type varchar(20) NULL,
    ref_id bigint NULL,
    created_at datetime2 NOT NULL CONSTRAINT df_wallet_transactions_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_wallet_transactions PRIMARY KEY (txn_id),
    CONSTRAINT fk_wallet_transactions_wallet_id FOREIGN KEY (wallet_id) REFERENCES dbo.wallets(wallet_id),
    CONSTRAINT ck_wallet_transactions_direction CHECK (direction IN ('DEBIT', 'CREDIT')),
    CONSTRAINT ck_wallet_transactions_txn_type CHECK (txn_type IN ('PAYMENT', 'ESCROW_RELEASE', 'FEE', 'REFUND', 'WITHDRAWAL', 'PENALTY_TRANSFER')),
    CONSTRAINT ck_wallet_transactions_amount CHECK (amount > 0)
);
GO

-- Payment & Escrow: Yêu cầu rút tiền (giả lập, hoàn tất ngay, không cần Admin duyệt).
CREATE TABLE dbo.withdrawal_requests (
    withdrawal_id bigint IDENTITY(1,1) NOT NULL,
    user_id bigint NOT NULL,
    bank_account_id bigint NOT NULL,
    amount bigint NOT NULL,
    status varchar(10) NOT NULL CONSTRAINT df_withdrawal_requests_status DEFAULT ('COMPLETED'),
    created_at datetime2 NOT NULL CONSTRAINT df_withdrawal_requests_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_withdrawal_requests PRIMARY KEY (withdrawal_id),
    CONSTRAINT fk_withdrawal_requests_user_id FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT fk_withdrawal_requests_bank_account_id FOREIGN KEY (bank_account_id) REFERENCES dbo.bank_accounts(bank_account_id),
    CONSTRAINT ck_withdrawal_requests_status CHECK (status IN ('COMPLETED')),
    CONSTRAINT ck_withdrawal_requests_amount CHECK (amount > 0)
);
GO

-- Payment & Escrow: Cấu hình hệ thống: phí sàn, các mốc thời gian, clock_offset cho chế độ demo.
CREATE TABLE dbo.system_settings (
    setting_key varchar(50) NOT NULL,
    setting_value nvarchar(200) NOT NULL,
    description nvarchar(200) NULL,
    updated_at datetime2 NOT NULL CONSTRAINT df_system_settings_updated_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_system_settings PRIMARY KEY (setting_key)
);
GO

-- Communication & Quality: Cuộc trò chuyện: DIRECT (1-1, mỗi cặp một cuộc, direct_key duy nhất) và EVENT_GROUP (gắn sự kiện, event_id duy nhất).
CREATE TABLE dbo.conversations (
    conversation_id bigint IDENTITY(1,1) NOT NULL,
    type varchar(12) NOT NULL,
    event_id bigint NULL,
    direct_key varchar(40) NULL,
    title nvarchar(150) NULL,
    status varchar(10) NOT NULL CONSTRAINT df_conversations_status DEFAULT ('ACTIVE'),
    created_at datetime2 NOT NULL CONSTRAINT df_conversations_created_at DEFAULT (SYSUTCDATETIME()),
    read_only_at datetime2 NULL,
    CONSTRAINT pk_conversations PRIMARY KEY (conversation_id),
    CONSTRAINT fk_conversations_event_id FOREIGN KEY (event_id) REFERENCES dbo.events(event_id),
    CONSTRAINT ck_conversations_type CHECK (type IN ('DIRECT', 'EVENT_GROUP')),
    CONSTRAINT ck_conversations_status CHECK (status IN ('ACTIVE', 'READ_ONLY')),
    CONSTRAINT ck_conversations_type_ref CHECK ((type = 'DIRECT' AND direct_key IS NOT NULL AND event_id IS NULL) OR (type = 'EVENT_GROUP' AND event_id IS NOT NULL AND direct_key IS NULL))
);
GO

-- Communication & Quality: Thành viên cuộc trò chuyện; left_at và access_mode quản lý việc vào muộn, rời nhóm và Admin chỉ đọc.
CREATE TABLE dbo.conversation_participants (
    conversation_id bigint NOT NULL,
    user_id bigint NOT NULL,
    access_mode varchar(10) NOT NULL CONSTRAINT df_conversation_participants_access_mode DEFAULT ('FULL'),
    joined_at datetime2 NOT NULL CONSTRAINT df_conversation_participants_joined_at DEFAULT (SYSUTCDATETIME()),
    left_at datetime2 NULL,
    last_read_at datetime2 NULL,
    CONSTRAINT pk_conversation_participants PRIMARY KEY (conversation_id, user_id),
    CONSTRAINT fk_conversation_participants_conversation_id FOREIGN KEY (conversation_id) REFERENCES dbo.conversations(conversation_id),
    CONSTRAINT fk_conversation_participants_user_id FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT ck_conversation_participants_access_mode CHECK (access_mode IN ('FULL', 'READ_ONLY'))
);
GO

-- Communication & Quality: Tin nhắn (TEXT, IMAGE, SYSTEM); không sửa, không xóa.
CREATE TABLE dbo.messages (
    message_id bigint IDENTITY(1,1) NOT NULL,
    conversation_id bigint NOT NULL,
    sender_id bigint NULL,
    message_type varchar(10) NOT NULL CONSTRAINT df_messages_message_type DEFAULT ('TEXT'),
    content nvarchar(2000) NULL,
    image_url nvarchar(500) NULL,
    created_at datetime2 NOT NULL CONSTRAINT df_messages_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_messages PRIMARY KEY (message_id),
    CONSTRAINT fk_messages_conversation_id FOREIGN KEY (conversation_id) REFERENCES dbo.conversations(conversation_id),
    CONSTRAINT fk_messages_sender_id FOREIGN KEY (sender_id) REFERENCES dbo.users(user_id),
    CONSTRAINT ck_messages_message_type CHECK (message_type IN ('TEXT', 'IMAGE', 'SYSTEM')),
    CONSTRAINT ck_messages_body CHECK (content IS NOT NULL OR image_url IS NOT NULL)
);
GO

-- Communication & Quality: Thông báo trong ứng dụng.
CREATE TABLE dbo.notifications (
    notification_id bigint IDENTITY(1,1) NOT NULL,
    user_id bigint NOT NULL,
    type varchar(30) NOT NULL,
    title nvarchar(150) NOT NULL,
    body nvarchar(500) NULL,
    ref_type varchar(20) NULL,
    ref_id bigint NULL,
    is_read bit NOT NULL CONSTRAINT df_notifications_is_read DEFAULT (0),
    created_at datetime2 NOT NULL CONSTRAINT df_notifications_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_notifications PRIMARY KEY (notification_id),
    CONSTRAINT fk_notifications_user_id FOREIGN KEY (user_id) REFERENCES dbo.users(user_id)
);
GO

-- Communication & Quality: Đánh giá dịch vụ sau khi COMPLETED, mỗi dịch vụ trong đơn một đánh giá; Admin có thể ẩn.
CREATE TABLE dbo.reviews (
    review_id bigint IDENTITY(1,1) NOT NULL,
    booking_item_id bigint NOT NULL,
    host_id bigint NOT NULL,
    vendor_id bigint NOT NULL,
    service_id bigint NOT NULL,
    rating tinyint NOT NULL,
    comment nvarchar(1000) NULL,
    is_hidden bit NOT NULL CONSTRAINT df_reviews_is_hidden DEFAULT (0),
    created_at datetime2 NOT NULL CONSTRAINT df_reviews_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_reviews PRIMARY KEY (review_id),
    CONSTRAINT uq_reviews_booking_item_id UNIQUE (booking_item_id),
    CONSTRAINT fk_reviews_booking_item_id FOREIGN KEY (booking_item_id) REFERENCES dbo.booking_items(booking_item_id),
    CONSTRAINT fk_reviews_host_id FOREIGN KEY (host_id) REFERENCES dbo.users(user_id),
    CONSTRAINT fk_reviews_vendor_id FOREIGN KEY (vendor_id) REFERENCES dbo.vendors(vendor_id),
    CONSTRAINT fk_reviews_service_id FOREIGN KEY (service_id) REFERENCES dbo.services(service_id),
    CONSTRAINT ck_reviews_rating CHECK (rating BETWEEN 1 AND 5)
);
GO

-- Communication & Quality: Khiếu nại của Host; lưu phản hồi vendor và quyết định phân xử của Admin (host_percent, vendor_percent).
CREATE TABLE dbo.disputes (
    dispute_id bigint IDENTITY(1,1) NOT NULL,
    booking_item_id bigint NOT NULL,
    opened_by bigint NOT NULL,
    reason nvarchar(1000) NOT NULL,
    status varchar(20) NOT NULL CONSTRAINT df_disputes_status DEFAULT ('OPEN'),
    vendor_response nvarchar(1000) NULL,
    vendor_deadline datetime2 NOT NULL,
    vendor_responded_at datetime2 NULL,
    resolved_by bigint NULL,
    host_percent decimal(5,2) NULL,
    vendor_percent decimal(5,2) NULL,
    resolution_note nvarchar(500) NULL,
    created_at datetime2 NOT NULL CONSTRAINT df_disputes_created_at DEFAULT (SYSUTCDATETIME()),
    resolved_at datetime2 NULL,
    CONSTRAINT pk_disputes PRIMARY KEY (dispute_id),
    CONSTRAINT fk_disputes_booking_item_id FOREIGN KEY (booking_item_id) REFERENCES dbo.booking_items(booking_item_id),
    CONSTRAINT fk_disputes_opened_by FOREIGN KEY (opened_by) REFERENCES dbo.users(user_id),
    CONSTRAINT fk_disputes_resolved_by FOREIGN KEY (resolved_by) REFERENCES dbo.users(user_id),
    CONSTRAINT ck_disputes_status CHECK (status IN ('OPEN', 'VENDOR_RESPONDED', 'UNDER_REVIEW', 'RESOLVED')),
    CONSTRAINT ck_disputes_split CHECK ((host_percent IS NULL AND vendor_percent IS NULL) OR (host_percent BETWEEN 0 AND 100 AND vendor_percent BETWEEN 0 AND 100 AND host_percent + vendor_percent = 100))
);
GO

-- Communication & Quality: Tệp bằng chứng đính kèm khiếu nại hoặc phản hồi.
CREATE TABLE dbo.dispute_attachments (
    attachment_id bigint IDENTITY(1,1) NOT NULL,
    dispute_id bigint NOT NULL,
    uploaded_by bigint NOT NULL,
    file_url nvarchar(500) NOT NULL,
    file_type varchar(20) NOT NULL,
    created_at datetime2 NOT NULL CONSTRAINT df_dispute_attachments_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_dispute_attachments PRIMARY KEY (attachment_id),
    CONSTRAINT fk_dispute_attachments_dispute_id FOREIGN KEY (dispute_id) REFERENCES dbo.disputes(dispute_id),
    CONSTRAINT fk_dispute_attachments_uploaded_by FOREIGN KEY (uploaded_by) REFERENCES dbo.users(user_id),
    CONSTRAINT ck_dispute_attachments_file_type CHECK (file_type IN ('IMAGE', 'DOCUMENT', 'OTHER'))
);
GO

-- Communication & Quality: Lịch sử chuyển trạng thái chung cho các đối tượng chính (booking_item, vendor, dispute, contract...).
CREATE TABLE dbo.status_history (
    history_id bigint IDENTITY(1,1) NOT NULL,
    entity_type varchar(30) NOT NULL,
    entity_id bigint NOT NULL,
    from_status varchar(20) NULL,
    to_status varchar(20) NOT NULL,
    changed_by bigint NULL,
    reason nvarchar(300) NULL,
    changed_at datetime2 NOT NULL CONSTRAINT df_status_history_changed_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_status_history PRIMARY KEY (history_id),
    CONSTRAINT fk_status_history_changed_by FOREIGN KEY (changed_by) REFERENCES dbo.users(user_id)
);
GO

-- ============================================================================
-- 2. INDEXES
-- ============================================================================
-- 2.1 Chỉ mục duy nhất có điều kiện (cột cho phép NULL)
CREATE UNIQUE INDEX ux_payments_vnp_txn_ref ON dbo.payments(vnp_txn_ref) WHERE vnp_txn_ref IS NOT NULL;
CREATE UNIQUE INDEX ux_payments_idempotency_key ON dbo.payments(idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE UNIQUE INDEX ux_conversations_event_id ON dbo.conversations(event_id) WHERE event_id IS NOT NULL;
CREATE UNIQUE INDEX ux_conversations_direct_key ON dbo.conversations(direct_key) WHERE direct_key IS NOT NULL;
CREATE UNIQUE INDEX ux_user_identities_provider ON dbo.user_identities(provider, provider_user_id);
CREATE UNIQUE INDEX ux_event_type_budget_defaults ON dbo.event_type_budget_defaults(event_type_id, category_id);
CREATE UNIQUE INDEX ux_service_bundle_categories ON dbo.service_bundle_categories(service_id, category_id);
CREATE UNIQUE INDEX ux_wallets_user ON dbo.wallets(user_id) WHERE user_id IS NOT NULL;
CREATE UNIQUE INDEX ux_wallets_system_type ON dbo.wallets(wallet_type) WHERE wallet_type <> 'USER';
GO

-- 2.2 Chỉ mục cho khóa ngoại (SQL Server không tự tạo)
CREATE INDEX ix_users_role_id ON dbo.users(role_id);
CREATE INDEX ix_user_identities_user_id ON dbo.user_identities(user_id);
CREATE INDEX ix_email_verifications_user_id ON dbo.email_verifications(user_id);
CREATE INDEX ix_kyc_submissions_vendor_id ON dbo.kyc_submissions(vendor_id);
CREATE INDEX ix_kyc_submissions_reviewed_by ON dbo.kyc_submissions(reviewed_by);
CREATE INDEX ix_availability_blocks_vendor_id ON dbo.availability_blocks(vendor_id);
CREATE INDEX ix_services_vendor_id ON dbo.services(vendor_id);
CREATE INDEX ix_services_category_id ON dbo.services(category_id);
CREATE INDEX ix_service_tags_tag_id ON dbo.service_tags(tag_id);
CREATE INDEX ix_service_bundle_categories_service_id ON dbo.service_bundle_categories(service_id);
CREATE INDEX ix_service_bundle_categories_category_id ON dbo.service_bundle_categories(category_id);
CREATE INDEX ix_service_images_service_id ON dbo.service_images(service_id);
CREATE INDEX ix_events_user_id ON dbo.events(user_id);
CREATE INDEX ix_events_event_type_id ON dbo.events(event_type_id);
CREATE INDEX ix_event_type_budget_defaults_event_type_id ON dbo.event_type_budget_defaults(event_type_id);
CREATE INDEX ix_event_type_budget_defaults_category_id ON dbo.event_type_budget_defaults(category_id);
CREATE INDEX ix_event_budget_items_event_id ON dbo.event_budget_items(event_id);
CREATE INDEX ix_event_budget_items_category_id ON dbo.event_budget_items(category_id);
CREATE INDEX ix_checklist_template_items_event_type_id ON dbo.checklist_template_items(event_type_id);
CREATE INDEX ix_checklist_template_items_category_id ON dbo.checklist_template_items(category_id);
CREATE INDEX ix_event_checklist_items_event_id ON dbo.event_checklist_items(event_id);
CREATE INDEX ix_event_checklist_items_category_id ON dbo.event_checklist_items(category_id);
CREATE INDEX ix_budget_estimates_event_id ON dbo.budget_estimates(event_id);
CREATE INDEX ix_budget_estimates_requested_by ON dbo.budget_estimates(requested_by);
CREATE INDEX ix_budget_estimate_items_estimate_id ON dbo.budget_estimate_items(estimate_id);
CREATE INDEX ix_budget_estimate_items_category_id ON dbo.budget_estimate_items(category_id);
CREATE INDEX ix_plan_recommendations_event_id ON dbo.plan_recommendations(event_id);
CREATE INDEX ix_plan_recommendation_items_recommendation_id ON dbo.plan_recommendation_items(recommendation_id);
CREATE INDEX ix_plan_recommendation_items_service_id ON dbo.plan_recommendation_items(service_id);
CREATE INDEX ix_plan_recommendation_items_budget_item_id ON dbo.plan_recommendation_items(budget_item_id);
CREATE INDEX ix_runsheet_items_event_id ON dbo.runsheet_items(event_id);
CREATE INDEX ix_runsheet_items_vendor_id ON dbo.runsheet_items(vendor_id);
CREATE INDEX ix_cart_items_cart_id ON dbo.cart_items(cart_id);
CREATE INDEX ix_cart_items_service_id ON dbo.cart_items(service_id);
CREATE INDEX ix_cart_items_budget_item_id ON dbo.cart_items(budget_item_id);
CREATE INDEX ix_bookings_event_id ON dbo.bookings(event_id);
CREATE INDEX ix_booking_items_booking_id ON dbo.booking_items(booking_id);
CREATE INDEX ix_booking_items_service_id ON dbo.booking_items(service_id);
CREATE INDEX ix_booking_items_vendor_id ON dbo.booking_items(vendor_id);
CREATE INDEX ix_booking_item_allocations_booking_item_id ON dbo.booking_item_allocations(booking_item_id);
CREATE INDEX ix_booking_item_allocations_budget_item_id ON dbo.booking_item_allocations(budget_item_id);
CREATE INDEX ix_booking_item_allocations_quote_id ON dbo.booking_item_allocations(quote_id);
CREATE INDEX ix_slot_locks_vendor_id ON dbo.slot_locks(vendor_id);
CREATE INDEX ix_contract_appendices_contract_id ON dbo.contract_appendices(contract_id);
CREATE INDEX ix_addendum_quotes_booking_item_id ON dbo.addendum_quotes(booking_item_id);
CREATE INDEX ix_addendum_quotes_vendor_id ON dbo.addendum_quotes(vendor_id);
CREATE INDEX ix_addendum_quotes_target_category_id ON dbo.addendum_quotes(target_category_id);
CREATE INDEX ix_addendum_quotes_replaces_quote_id ON dbo.addendum_quotes(replaces_quote_id);
CREATE INDEX ix_wallets_user_id ON dbo.wallets(user_id);
CREATE INDEX ix_payments_booking_id ON dbo.payments(booking_id);
CREATE INDEX ix_payments_user_id ON dbo.payments(user_id);
CREATE INDEX ix_payment_items_payment_id ON dbo.payment_items(payment_id);
CREATE INDEX ix_payment_items_booking_item_id ON dbo.payment_items(booking_item_id);
CREATE INDEX ix_payment_items_quote_id ON dbo.payment_items(quote_id);
CREATE INDEX ix_wallet_transactions_wallet_id ON dbo.wallet_transactions(wallet_id);
CREATE INDEX ix_withdrawal_requests_user_id ON dbo.withdrawal_requests(user_id);
CREATE INDEX ix_withdrawal_requests_bank_account_id ON dbo.withdrawal_requests(bank_account_id);
CREATE INDEX ix_conversation_participants_user_id ON dbo.conversation_participants(user_id);
CREATE INDEX ix_messages_conversation_id ON dbo.messages(conversation_id);
CREATE INDEX ix_messages_sender_id ON dbo.messages(sender_id);
CREATE INDEX ix_notifications_user_id ON dbo.notifications(user_id);
CREATE INDEX ix_reviews_host_id ON dbo.reviews(host_id);
CREATE INDEX ix_reviews_vendor_id ON dbo.reviews(vendor_id);
CREATE INDEX ix_reviews_service_id ON dbo.reviews(service_id);
CREATE INDEX ix_disputes_booking_item_id ON dbo.disputes(booking_item_id);
CREATE INDEX ix_disputes_opened_by ON dbo.disputes(opened_by);
CREATE INDEX ix_disputes_resolved_by ON dbo.disputes(resolved_by);
CREATE INDEX ix_dispute_attachments_dispute_id ON dbo.dispute_attachments(dispute_id);
CREATE INDEX ix_dispute_attachments_uploaded_by ON dbo.dispute_attachments(uploaded_by);
CREATE INDEX ix_status_history_changed_by ON dbo.status_history(changed_by);
GO

-- 2.3 Chỉ mục phục vụ truy vấn nghiệp vụ và job nền
-- Tìm kiếm dịch vụ (S02)
CREATE INDEX ix_services_search ON dbo.services(category_id, city, status, is_deleted) INCLUDE (unit_price, rating_avg);
-- Dịch vụ của vendor
CREATE INDEX ix_services_vendor_status ON dbo.services(vendor_id, status, is_deleted);
-- Lọc vendor APPROVED theo thành phố
CREATE INDEX ix_vendors_status_city ON dbo.vendors(status, city);
-- Kiểm tra sức chứa (BR-12)
CREATE INDEX ix_booking_items_capacity ON dbo.booking_items(vendor_id, status, start_at, end_at);
-- Suy ra trạng thái đơn
CREATE INDEX ix_booking_items_booking_status ON dbo.booking_items(booking_id, status);
-- Job hết hạn phản hồi
CREATE INDEX ix_booking_items_vendor_deadline ON dbo.booking_items(status, respond_deadline);
-- Job hết hạn cọc
CREATE INDEX ix_bookings_pay_deadline ON dbo.bookings(pay_deadline) WHERE pay_deadline IS NOT NULL;
-- Job nhả chỗ giữ
CREATE INDEX ix_slot_locks_expiry ON dbo.slot_locks(status, expires_at);
-- Khoảng chặn lịch
CREATE INDEX ix_availability_blocks_range ON dbo.availability_blocks(vendor_id, start_at, end_at);
-- Danh sách sự kiện của Host
CREATE INDEX ix_events_owner_status ON dbo.events(user_id, status);
-- Job bắt đầu sự kiện
CREATE INDEX ix_events_date ON dbo.events(event_date);
-- Job nhắc checklist quá hạn
CREATE INDEX ix_event_checklist_due ON dbo.event_checklist_items(due_date) WHERE is_done = 0 AND overdue_notified = 0;
-- Job hết hạn phiên thanh toán
CREATE INDEX ix_payments_status_expiry ON dbo.payments(status, expires_at);
-- Kiểm tra sổ cái kép
CREATE INDEX ix_wallet_transactions_journal ON dbo.wallet_transactions(journal_id);
-- Lịch sử ví
CREATE INDEX ix_wallet_transactions_wallet_time ON dbo.wallet_transactions(wallet_id, created_at DESC);
-- Job hết hạn báo giá
CREATE INDEX ix_addendum_quotes_expiry ON dbo.addendum_quotes(status, expires_at);
-- Job leo thang khiếu nại
CREATE INDEX ix_disputes_status_deadline ON dbo.disputes(status, vendor_deadline);
-- Danh sách KYC chờ duyệt
CREATE INDEX ix_kyc_status ON dbo.kyc_submissions(status, submitted_at);
-- Đọc tin nhắn
CREATE INDEX ix_messages_conversation_time ON dbo.messages(conversation_id, created_at);
-- Chuông thông báo
CREATE INDEX ix_notifications_user_unread ON dbo.notifications(user_id, is_read, created_at DESC);
-- Lịch sử trạng thái
CREATE INDEX ix_status_history_entity ON dbo.status_history(entity_type, entity_id, changed_at);
-- Tính điểm trung bình
CREATE INDEX ix_reviews_service ON dbo.reviews(service_id, is_hidden);
GO

-- ============================================================================
-- 3. TRIGGERS
-- ============================================================================
-- 3.1 Mỗi Host và Vendor có sẵn một ví USER khi tạo tài khoản
CREATE OR ALTER TRIGGER dbo.trg_users_create_wallet ON dbo.users AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.wallets (user_id, wallet_type, balance)
    SELECT i.user_id, 'USER', 0
    FROM inserted i JOIN dbo.roles r ON r.role_id = i.role_id
    WHERE r.role_name IN ('HOST', 'VENDOR')
      AND NOT EXISTS (SELECT 1 FROM dbo.wallets w WHERE w.user_id = i.user_id);
END;
GO

-- 3.2 Bảng chỉ thêm, không sửa, không xóa (sổ cái, lịch sử trạng thái, tin nhắn)
CREATE OR ALTER TRIGGER dbo.trg_wallet_transactions_append_only ON dbo.wallet_transactions INSTEAD OF UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50001, N'Sổ cái chỉ được thêm bút toán mới, không sửa hoặc xóa (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_status_history_append_only ON dbo.status_history INSTEAD OF UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50001, N'Lịch sử trạng thái chỉ được thêm, không sửa hoặc xóa (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_messages_append_only ON dbo.messages INSTEAD OF UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50001, N'Tin nhắn không được sửa hoặc xóa (BR-29).', 1;
END;
GO

-- 3.3 Không xóa vật lý dữ liệu quan trọng (chỉ đổi trạng thái)
CREATE OR ALTER TRIGGER dbo.trg_payments_no_delete ON dbo.payments INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng payments; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_payment_items_no_delete ON dbo.payment_items INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng payment_items; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_wallets_no_delete ON dbo.wallets INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng wallets; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_escrow_holdings_no_delete ON dbo.escrow_holdings INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng escrow_holdings; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_withdrawal_requests_no_delete ON dbo.withdrawal_requests INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng withdrawal_requests; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_contracts_no_delete ON dbo.contracts INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng contracts; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_contract_appendices_no_delete ON dbo.contract_appendices INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng contract_appendices; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_addendum_quotes_no_delete ON dbo.addendum_quotes INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng addendum_quotes; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_disputes_no_delete ON dbo.disputes INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng disputes; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_dispute_attachments_no_delete ON dbo.dispute_attachments INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng dispute_attachments; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_reviews_no_delete ON dbo.reviews INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng reviews; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_kyc_submissions_no_delete ON dbo.kyc_submissions INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng kyc_submissions; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_bookings_no_delete ON dbo.bookings INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng bookings; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_booking_items_no_delete ON dbo.booking_items INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng booking_items; hãy đổi trạng thái (BR-30).', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_booking_item_allocations_no_delete ON dbo.booking_item_allocations INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'Không xóa vật lý bảng booking_item_allocations; hãy đổi trạng thái (BR-30).', 1;
END;
GO

-- ============================================================================
-- 4. VIEWS (báo cáo và kiểm tra tính toàn vẹn)
-- ============================================================================
-- Ngân sách theo hạng mục: dự kiến, đã cam kết, còn lại (dùng cho Event Dashboard S11)
CREATE OR ALTER VIEW dbo.vw_event_budget_summary AS
SELECT bi.event_id, bi.budget_item_id, bi.item_name, bi.category_id, bi.planned_amount,
       ISNULL(c.committed, 0) AS committed_amount,
       bi.planned_amount - ISNULL(c.committed, 0) AS remaining_amount
FROM dbo.event_budget_items bi
OUTER APPLY (
    SELECT SUM(a.amount) AS committed
    FROM dbo.booking_item_allocations a
    JOIN dbo.booking_items i ON i.booking_item_id = a.booking_item_id
    WHERE a.budget_item_id = bi.budget_item_id
      AND i.status IN ('AWAITING_DEPOSIT','CONFIRMED','FULLY_PAID','IN_PROGRESS','DISPUTED','COMPLETED')
) c;
GO

-- Kiểm tra sổ cái kép: view phải trả về 0 dòng (mỗi journal có tổng nợ bằng tổng có)
CREATE OR ALTER VIEW dbo.vw_check_ledger_unbalanced AS
SELECT journal_id,
       SUM(CASE WHEN direction = 'DEBIT'  THEN amount ELSE 0 END) AS debit_total,
       SUM(CASE WHEN direction = 'CREDIT' THEN amount ELSE 0 END) AS credit_total
FROM dbo.wallet_transactions
GROUP BY journal_id
HAVING SUM(CASE WHEN direction = 'DEBIT' THEN amount ELSE 0 END)
    <> SUM(CASE WHEN direction = 'CREDIT' THEN amount ELSE 0 END);
GO

-- Kiểm tra escrow: tổng các khoản đang giữ phải bằng số dư ví ESCROW_POOL (diff = 0)
CREATE OR ALTER VIEW dbo.vw_check_escrow_pool AS
SELECT (SELECT ISNULL(SUM(amount_held), 0) FROM dbo.escrow_holdings WHERE status IN ('HELD','FROZEN')) AS held_total,
       (SELECT balance FROM dbo.wallets WHERE wallet_type = 'ESCROW_POOL') AS pool_balance,
       (SELECT ISNULL(SUM(amount_held), 0) FROM dbo.escrow_holdings WHERE status IN ('HELD','FROZEN'))
         - (SELECT balance FROM dbo.wallets WHERE wallet_type = 'ESCROW_POOL') AS diff;
GO

-- ============================================================================
-- 5. SEED DATA (dữ liệu danh mục và cấu hình)
-- ============================================================================
INSERT INTO dbo.roles (role_name) VALUES ('HOST'), ('VENDOR'), ('ADMIN');

INSERT INTO dbo.event_types (code, name) VALUES
 ('WEDDING', N'Tiệc cưới'), ('BIRTHDAY', N'Sinh nhật'), ('CONFERENCE', N'Hội thảo'), ('CORPORATE_PARTY', N'Tiệc công ty');

INSERT INTO dbo.service_categories (code, name) VALUES
 ('VENUE', N'Địa điểm'), ('CATERING', N'Tiệc / Catering'), ('DECORATION', N'Trang trí'),
 ('SOUND_LIGHT', N'Âm thanh & ánh sáng'), ('MC', N'MC & nghệ sĩ'), ('PHOTO_VIDEO', N'Quay chụp');

INSERT INTO dbo.tags (name, tag_group) VALUES
 (N'Hiện đại','STYLE'), (N'Truyền thống','STYLE'), (N'Sang trọng','STYLE'), (N'Ngoài trời','STYLE'),
 (N'Món Việt','CUISINE'), (N'Món Âu','CUISINE'), (N'Buffet','CUISINE'), (N'Chay','CUISINE'),
 (N'Hải Châu','AREA'), (N'Thanh Khê','AREA'), (N'Sơn Trà','AREA'), (N'Ngũ Hành Sơn','AREA'), (N'Liên Chiểu','AREA'), (N'Cẩm Lệ','AREA');

-- Tỷ lệ ngân sách mặc định (cộng lại 100 cho mỗi loại sự kiện; áp dụng cho 90% sau khi trừ quỹ dự phòng)
INSERT INTO dbo.event_type_budget_defaults (event_type_id, category_id, [percent])
SELECT et.event_type_id, c.category_id, v.pct
FROM (VALUES
 ('WEDDING','VENUE',25),('WEDDING','CATERING',40),('WEDDING','DECORATION',15),('WEDDING','SOUND_LIGHT',7),('WEDDING','MC',5),('WEDDING','PHOTO_VIDEO',8),
 ('BIRTHDAY','VENUE',20),('BIRTHDAY','CATERING',40),('BIRTHDAY','DECORATION',20),('BIRTHDAY','SOUND_LIGHT',8),('BIRTHDAY','MC',7),('BIRTHDAY','PHOTO_VIDEO',5),
 ('CONFERENCE','VENUE',30),('CONFERENCE','CATERING',25),('CONFERENCE','DECORATION',8),('CONFERENCE','SOUND_LIGHT',22),('CONFERENCE','MC',8),('CONFERENCE','PHOTO_VIDEO',7),
 ('CORPORATE_PARTY','VENUE',25),('CORPORATE_PARTY','CATERING',35),('CORPORATE_PARTY','DECORATION',12),('CORPORATE_PARTY','SOUND_LIGHT',13),('CORPORATE_PARTY','MC',10),('CORPORATE_PARTY','PHOTO_VIDEO',5)
) v(et, cat, pct)
JOIN dbo.event_types et ON et.code = v.et
JOIN dbo.service_categories c ON c.code = v.cat;

-- Mẫu checklist theo loại sự kiện (offset_days = số ngày lùi từ ngày sự kiện)
INSERT INTO dbo.checklist_template_items (event_type_id, title, offset_days, category_id)
SELECT et.event_type_id, v.title, v.offset_days, c.category_id
FROM (VALUES
 ('WEDDING', N'Chốt ngân sách và danh sách khách', 90, NULL),
 ('WEDDING', N'Chọn và đặt địa điểm', 80, 'VENUE'),
 ('WEDDING', N'Chọn thực đơn và nhà cung cấp tiệc', 60, 'CATERING'),
 ('WEDDING', N'Chọn MC', 45, 'MC'),
 ('WEDDING', N'Chọn đơn vị quay chụp', 45, 'PHOTO_VIDEO'),
 ('WEDDING', N'Chốt phong cách trang trí', 40, 'DECORATION'),
 ('WEDDING', N'Chốt âm thanh ánh sáng', 30, 'SOUND_LIGHT'),
 ('WEDDING', N'Gửi thiệp mời', 30, NULL),
 ('WEDDING', N'Chốt số lượng khách xác nhận', 14, NULL),
 ('WEDDING', N'Trả phần thanh toán còn lại', 7, NULL),
 ('WEDDING', N'Hoàn thiện kịch bản sự kiện (run-sheet)', 5, NULL),
 ('WEDDING', N'Họp phối hợp với các nhà cung cấp', 2, NULL),
 ('BIRTHDAY', N'Chốt ngân sách và số khách', 45, NULL),
 ('BIRTHDAY', N'Chọn địa điểm', 35, 'VENUE'),
 ('BIRTHDAY', N'Chọn thực đơn', 28, 'CATERING'),
 ('BIRTHDAY', N'Chọn trang trí theo chủ đề', 25, 'DECORATION'),
 ('BIRTHDAY', N'Chọn MC hoặc nghệ sĩ', 21, 'MC'),
 ('BIRTHDAY', N'Chọn quay chụp', 21, 'PHOTO_VIDEO'),
 ('BIRTHDAY', N'Gửi lời mời', 21, NULL),
 ('BIRTHDAY', N'Chốt âm thanh', 14, 'SOUND_LIGHT'),
 ('BIRTHDAY', N'Chốt số khách xác nhận', 10, NULL),
 ('BIRTHDAY', N'Trả phần thanh toán còn lại', 7, NULL),
 ('BIRTHDAY', N'Hoàn thiện kịch bản sự kiện (run-sheet)', 4, NULL),
 ('BIRTHDAY', N'Họp phối hợp với các nhà cung cấp', 2, NULL),
 ('CONFERENCE', N'Chốt mục tiêu và ngân sách', 60, NULL),
 ('CONFERENCE', N'Chọn địa điểm hội trường', 50, 'VENUE'),
 ('CONFERENCE', N'Gửi thư mời diễn giả', 35, NULL),
 ('CONFERENCE', N'Chốt âm thanh, ánh sáng, màn hình', 40, 'SOUND_LIGHT'),
 ('CONFERENCE', N'Chọn MC điều phối', 30, 'MC'),
 ('CONFERENCE', N'Chọn tiệc trà hoặc catering', 30, 'CATERING'),
 ('CONFERENCE', N'Chốt trang trí backdrop', 25, 'DECORATION'),
 ('CONFERENCE', N'Chọn quay chụp', 25, 'PHOTO_VIDEO'),
 ('CONFERENCE', N'Mở đăng ký tham dự', 21, NULL),
 ('CONFERENCE', N'Chốt số lượng tham dự', 10, NULL),
 ('CONFERENCE', N'Trả phần thanh toán còn lại', 7, NULL),
 ('CONFERENCE', N'Hoàn thiện kịch bản sự kiện (run-sheet)', 5, NULL),
 ('CONFERENCE', N'Tổng duyệt', 2, NULL),
 ('CORPORATE_PARTY', N'Chốt ngân sách và mục tiêu', 45, NULL),
 ('CORPORATE_PARTY', N'Chọn địa điểm', 35, 'VENUE'),
 ('CORPORATE_PARTY', N'Chọn tiệc', 28, 'CATERING'),
 ('CORPORATE_PARTY', N'Chọn MC hoặc nghệ sĩ', 25, 'MC'),
 ('CORPORATE_PARTY', N'Chọn trang trí', 21, 'DECORATION'),
 ('CORPORATE_PARTY', N'Chốt âm thanh ánh sáng', 21, 'SOUND_LIGHT'),
 ('CORPORATE_PARTY', N'Chọn quay chụp', 18, 'PHOTO_VIDEO'),
 ('CORPORATE_PARTY', N'Chốt chương trình', 14, NULL),
 ('CORPORATE_PARTY', N'Chốt số lượng tham dự', 10, NULL),
 ('CORPORATE_PARTY', N'Trả phần thanh toán còn lại', 7, NULL),
 ('CORPORATE_PARTY', N'Hoàn thiện kịch bản sự kiện (run-sheet)', 4, NULL),
 ('CORPORATE_PARTY', N'Họp phối hợp với các nhà cung cấp', 2, NULL)
) v(et, title, offset_days, cat)
JOIN dbo.event_types et ON et.code = v.et
LEFT JOIN dbo.service_categories c ON c.code = v.cat;

INSERT INTO dbo.system_settings (setting_key, setting_value, description, updated_at) VALUES
 ('min_days_first_booking', '14', N'Số ngày tối thiểu từ hôm nay đến ngày sự kiện với đơn đầu tiên', SYSUTCDATETIME()),
 ('min_days_followup', '9', N'Số ngày tối thiểu với yêu cầu sau đó (thay thế, thêm dịch vụ)', SYSUTCDATETIME()),
 ('vendor_response_hours', '24', N'Thời hạn vendor phản hồi yêu cầu (giờ)', SYSUTCDATETIME()),
 ('deposit_deadline_hours', '24', N'Hạn trả cọc chung sau khi mọi dịch vụ có phản hồi (giờ)', SYSUTCDATETIME()),
 ('deposit_percent', '30', N'Tỷ lệ cọc (%)', SYSUTCDATETIME()),
 ('remaining_due_days_before', '7', N'Hạn trả phần còn lại, tính trước ngày sự kiện (ngày)', SYSUTCDATETIME()),
 ('platform_fee_percent', '5', N'Phí sàn trừ từ vendor (%)', SYSUTCDATETIME()),
 ('auto_accept_hours', '72', N'Tự nghiệm thu và hạn khiếu nại sau khi sự kiện kết thúc (giờ)', SYSUTCDATETIME()),
 ('dispute_vendor_hours', '48', N'Thời hạn vendor phản hồi khiếu nại (giờ)', SYSUTCDATETIME()),
 ('quote_valid_hours', '48', N'Hiệu lực báo giá phát sinh (giờ)', SYSUTCDATETIME()),
 ('payment_session_minutes', '15', N'Thời hạn một phiên thanh toán (phút)', SYSUTCDATETIME()),
 ('otp_minutes', '5', N'Hiệu lực OTP (phút)', SYSUTCDATETIME()),
 ('max_login_fail', '5', N'Số lần đăng nhập sai tối đa', SYSUTCDATETIME()),
 ('lock_minutes', '15', N'Thời gian khóa đăng nhập (phút)', SYSUTCDATETIME()),
 ('ai_daily_limit', '5', N'Số lần gọi AI tối đa mỗi sự kiện mỗi ngày', SYSUTCDATETIME()),
 ('ai_timeout_seconds', '10', N'Thời gian chờ AI (giây)', SYSUTCDATETIME()),
 ('reserve_percent', '10', N'Quỹ dự phòng mặc định (%)', SYSUTCDATETIME()),
 ('group_chat_readonly_days', '30', N'Số ngày sau khi kết thúc thì nhóm chat chỉ đọc', SYSUTCDATETIME()),
 ('demo_mode', 'false', N'Bật chế độ demo (đồng hồ ảo)', SYSUTCDATETIME()),
 ('clock_offset_minutes', '0', N'Độ lệch đồng hồ ảo (phút)', SYSUTCDATETIME());

-- Ví hệ thống: ESCROW_POOL (giữ tiền ký quỹ), PLATFORM (phí sàn), EXTERNAL (VNPay, ngân hàng ngoài hệ thống)
INSERT INTO dbo.wallets (user_id, wallet_type, balance) VALUES (NULL, 'ESCROW_POOL', 0), (NULL, 'PLATFORM', 0), (NULL, 'EXTERNAL', 0);

-- Tài khoản Admin. QUAN TRỌNG: thay password_hash bằng mã BCrypt thật trước khi dùng
-- (tạo bằng BCryptPasswordEncoder của Spring Security hoặc công cụ BCrypt trực tuyến).
INSERT INTO dbo.users (role_id, email, password_hash, full_name, status)
SELECT role_id, 'admin@eventcraft.local', '$2a$12$ct1iERgKfqE5EWO7ug77EOgjlB.vCrEFcDoYkgfLhTo9IR252eQzS', N'Quản trị viên', 'ACTIVE'
FROM dbo.roles WHERE role_name = 'ADMIN';
GO
