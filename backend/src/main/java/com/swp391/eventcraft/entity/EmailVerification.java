package com.swp391.eventcraft.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Entity ánh xạ bảng email_verifications trong CSDL.
 * Lưu mã OTP 6 số dùng để xác thực email khi đăng ký tài khoản.
 * Mỗi lần sinh OTP mới sẽ xóa record cũ và tạo record mới.
 */
@Entity
@Table(name = "email_verifications")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmailVerification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Integer id;

    /** Email của người dùng cần xác thực */
    @Column(name = "email", nullable = false, length = 150)
    private String email;

    /** Mã OTP 6 chữ số ngẫu nhiên */
    @Column(name = "otp_code", nullable = false, length = 6)
    private String otpCode;

    /** Thời điểm hết hạn OTP (created_at + 5 phút) */
    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    /** Thời điểm tạo record */
    @Column(name = "created_at", nullable = false, updatable = false)
    @Builder.Default
    private LocalDateTime createdAt = LocalDateTime.now();
}
