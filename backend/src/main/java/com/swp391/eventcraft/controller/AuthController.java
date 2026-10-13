package com.swp391.eventcraft.controller;

import com.swp391.eventcraft.dto.*;
import com.swp391.eventcraft.service.AuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    // =========================================================================
    // API 1: Đăng ký tài khoản
    //   POST /api/auth/register
    //   Body: { fullName, email, password, phoneNumber, roleName }
    //   → Mã hoá BCrypt strength=12, sinh OTP 6 số lưu CSDL, in Console
    // =========================================================================
    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequest request) {
        try {
            AuthResponse response = authService.register(request);
            return ResponseEntity.ok(new ApiResponse(true,
                    "Đăng ký tài khoản thành công! Vui lòng nhập mã OTP được in trên Console Server để kích hoạt email.",
                    response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), null));
        }
    }

    // =========================================================================
    // API 2: Xác thực Email kích hoạt tài khoản
    //   POST /api/auth/verify-email
    //   Body: { email, otp }
    //   → Kiểm tra OTP trong CSDL + thời hạn 5 phút
    //   → Cập nhật email_verified=1, is_active=1 → Xóa OTP khỏi CSDL
    // =========================================================================
    @PostMapping({"/verify-email", "/verify-otp"})
    public ResponseEntity<?> verifyEmail(@RequestBody VerifyOtpRequest request) {
        try {
            AuthResponse response = authService.verifyEmail(request);
            return ResponseEntity.ok(new ApiResponse(true,
                    "Kích hoạt tài khoản thành công! Bạn đã có thể đăng nhập.",
                    response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), null));
        }
    }

    // =========================================================================
    // API 3: Gửi lại mã OTP kích hoạt tài khoản
    //   POST /api/auth/resend-otp
    //   Body: { email }
    //   → Xóa OTP cũ trong CSDL → Sinh OTP mới → Lưu CSDL → In Console
    // =========================================================================
    @PostMapping("/resend-otp")
    public ResponseEntity<?> resendOtp(@RequestBody ResendOtpRequest request) {
        try {
            authService.resendOtp(request);
            return ResponseEntity.ok(new ApiResponse(true,
                    "Mã OTP mới đã được tạo và in ra Console Server. Vui lòng kiểm tra!",
                    null));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), null));
        }
    }

    // =========================================================================
    // API 4: Đăng nhập truyền thống (Email & Mật khẩu)
    //   POST /api/auth/login
    //   → Chặn sai 5 lần khóa 30 phút, chặn chưa kích hoạt email
    // =========================================================================
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest request) {
        try {
            AuthResponse response = authService.login(request);
            return ResponseEntity.ok(new ApiResponse(true, "Đăng nhập thành công!", response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), null));
        }
    }

    // =========================================================================
    // API 5: Đăng nhập nhanh bằng Google OAuth2
    //   POST /api/auth/google
    // =========================================================================
    @PostMapping("/google")
    public ResponseEntity<?> loginWithGoogle(@RequestBody GoogleLoginRequest request) {
        try {
            AuthResponse response = authService.loginWithGoogle(request);
            return ResponseEntity.ok(new ApiResponse(true, "Đăng nhập Google thành công!", response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), null));
        }
    }

    // =========================================================================
    // API 6: Quên mật khẩu - Gửi mã OTP đặt lại mật khẩu
    //   POST /api/auth/forgot-password
    //   → Hiệu lực 5 phút, Cooldown 60 giây
    // =========================================================================
    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@RequestBody ForgotPasswordRequest request) {
        try {
            authService.sendForgotPasswordOtp(request);
            return ResponseEntity.ok(new ApiResponse(true,
                    "Mã OTP đặt lại mật khẩu đã được tạo! Vui lòng kiểm tra Console Server.",
                    null));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), null));
        }
    }

    // =========================================================================
    // API 7: Đặt lại mật khẩu mới bằng mã OTP
    //   POST /api/auth/reset-password
    //   → Hủy OTP nếu sai quá 3 lần
    // =========================================================================
    @PostMapping("/reset-password")
    public ResponseEntity<?> resetPassword(@RequestBody ResetPasswordRequest request) {
        try {
            authService.resetPasswordWithOtp(request);
            return ResponseEntity.ok(new ApiResponse(true,
                    "Đặt lại mật khẩu mới thành công! Bạn có thể đăng nhập ngay bằng mật khẩu mới.",
                    null));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), null));
        }
    }

    // =========================================================================
    // API 8: Đăng xuất (Logout) - Stateless JWT nên chỉ cần phía Frontend xóa token
    //   POST /api/auth/logout
    // =========================================================================
    @PostMapping("/logout")
    public ResponseEntity<?> logout() {
        return ResponseEntity.ok(new ApiResponse(true, "Đăng xuất thành công!", null));
    }
}
