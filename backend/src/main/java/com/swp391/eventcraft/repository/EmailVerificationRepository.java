package com.swp391.eventcraft.repository;

import com.swp391.eventcraft.entity.EmailVerification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

/**
 * Repository thao tác với bảng email_verifications trong CSDL.
 * Dùng để lưu, tìm kiếm và xóa mã OTP xác thực email.
 */
public interface EmailVerificationRepository extends JpaRepository<EmailVerification, Integer> {

    /**
     * Tìm bản ghi OTP mới nhất theo email.
     * Dùng để kiểm tra OTP khi người dùng gửi lên.
     */
    Optional<EmailVerification> findByEmail(String email);

    /**
     * Xóa tất cả OTP của một email.
     * Gọi sau khi xác thực thành công hoặc khi cần sinh OTP mới (resend).
     */
    @Modifying
    @Transactional
    void deleteByEmail(String email);

    /**
     * Kiểm tra email có bản ghi OTP nào đang tồn tại không.
     */
    boolean existsByEmail(String email);
}
