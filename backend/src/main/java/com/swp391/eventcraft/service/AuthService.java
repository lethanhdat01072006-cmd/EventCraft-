package com.swp391.eventcraft.service;

import com.swp391.eventcraft.config.JwtUtils;
import com.swp391.eventcraft.dto.*;
import com.swp391.eventcraft.entity.EmailVerification;
import com.swp391.eventcraft.entity.Role;
import com.swp391.eventcraft.entity.User;
import com.swp391.eventcraft.repository.EmailVerificationRepository;
import com.swp391.eventcraft.repository.RoleRepository;
import com.swp391.eventcraft.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.Optional;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtils jwtUtils;
    private final EmailVerificationRepository emailVerificationRepository;

    // =========================================================================
    // Cấu trúc theo dõi đăng nhập sai để khóa tài khoản (Account Lockout Policy)
    // (Vẫn giữ in-memory vì không cần persistence sau restart)
    // =========================================================================
    private static class LoginAttemptInfo {
        int count;
        long lockoutUntil;

        LoginAttemptInfo(int count, long lockoutUntil) {
            this.count = count;
            this.lockoutUntil = lockoutUntil;
        }
    }

    // Bộ nhớ đệm quản lý OTP quên mật khẩu (vẫn dùng Map vì chỉ cần tồn tại trong phiên)
    private final Map<String, OtpInfo> passwordResetOtpCache = new ConcurrentHashMap<>();

    // Bộ nhớ đệm theo dõi số lần đăng nhập sai (5 lần sai -> khóa 30 phút)
    private final Map<String, LoginAttemptInfo> loginAttemptCache = new ConcurrentHashMap<>();

    // Cấu trúc nội bộ dùng cho OTP quên mật khẩu (vẫn dùng Map)
    private static class OtpInfo {
        String otp;
        long expiryTime;
        int failedAttempts;
        long lastSentTime;

        OtpInfo(String otp, long expiryTime) {
            this.otp = otp;
            this.expiryTime = expiryTime;
            this.failedAttempts = 0;
            this.lastSentTime = System.currentTimeMillis();
        }
    }

    // =========================================================================
    // 1. ĐĂNG KÝ TÀI KHOẢN (REGISTER)
    //    - Kiểm tra email tồn tại trong CSDL
    //    - Mã hoá mật khẩu BCrypt strength=12
    //    - Sinh OTP 6 số, lưu vào CSDL, hiệu lực 5 phút
    //    - In OTP nổi bật ra Console
    // =========================================================================
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String email = request.getEmail().toLowerCase().trim();
        Optional<User> existingUserOpt = userRepository.findByEmail(email);

        if (existingUserOpt.isPresent()) {
            User existingUser = existingUserOpt.get();
            if (Boolean.TRUE.equals(existingUser.getEmailVerified())) {
                throw new RuntimeException("Email đã tồn tại và đã được kích hoạt trong hệ thống!");
            } else {
                // Tài khoản đã tạo nhưng chưa xác thực email -> cập nhật thông tin và sinh OTP mới
                existingUser.setFullName(request.getFullName());
                existingUser.setPasswordHash(passwordEncoder.encode(request.getPassword()));
                existingUser.setPhoneNumber(request.getPhoneNumber());
                existingUser.setUpdatedAt(LocalDateTime.now());
                userRepository.save(existingUser);

                sendAndSaveEmailVerificationOtp(email);
                return buildAuthResponse(null, existingUser);
            }
        }

        // Xác định vai trò từ request (ROLE_CUSTOMER hoặc ROLE_VENDOR)
        String roleToAssign = request.resolveRoleName();
        Role role = roleRepository.findByRoleName(roleToAssign)
                .orElseGet(() -> roleRepository.findByRoleName("ROLE_CUSTOMER")
                        .orElseThrow(() -> new RuntimeException("Không tìm thấy vai trò mặc định: ROLE_CUSTOMER")));

        // Mã hoá mật khẩu bằng BCrypt (strength 12 - cấu hình trong SecurityConfig)
        User user = User.builder()
                .email(email)
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .fullName(request.getFullName())
                .phoneNumber(request.getPhoneNumber())
                .avatarUrl("https://ui-avatars.com/api/?name=" + request.getFullName().replace(" ", "+"))
                .role(role)
                .isActive(false)           // Chưa kích hoạt, chờ xác thực OTP
                .emailVerified(false)      // Chưa xác thực email
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        user = userRepository.save(user);

        // Sinh OTP 6 số, lưu vào CSDL, in nổi bật ra Console
        sendAndSaveEmailVerificationOtp(email);

        // Trả về response với token=null (bắt buộc xác thực OTP trước khi cấp JWT)
        return buildAuthResponse(null, user);
    }

    // =========================================================================
    // 2. XÁC THỰC EMAIL KÍCH HOẠT TÀI KHOẢN (VERIFY-EMAIL)
    //    - Nhận email + mã OTP 6 số
    //    - Kiểm tra OTP khớp trong CSDL và còn trong thời hạn 5 phút
    //    - Cập nhật email_verified=true, is_active=true
    //    - Xóa OTP khỏi CSDL sau khi xác thực thành công
    // =========================================================================
    @Transactional
    public AuthResponse verifyEmail(VerifyOtpRequest request) {
        String email = request.getEmail().toLowerCase().trim();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("Email không tồn tại trong hệ thống!"));

        // Nếu đã xác thực rồi -> cấp token luôn
        if (Boolean.TRUE.equals(user.getEmailVerified())) {
            String token = jwtUtils.generateToken(user.getEmail(), user.getRole().getRoleName());
            return buildAuthResponse(token, user);
        }

        // Tìm bản ghi OTP trong CSDL
        EmailVerification verification = emailVerificationRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException(
                        "Mã OTP không tồn tại hoặc đã hết hạn. Vui lòng yêu cầu gửi lại mã mới!"));

        // Kiểm tra thời hạn OTP (5 phút)
        if (LocalDateTime.now().isAfter(verification.getExpiresAt())) {
            emailVerificationRepository.deleteByEmail(email);
            throw new RuntimeException("Mã OTP đã hết hạn (quá 5 phút). Vui lòng yêu cầu gửi lại mã mới!");
        }

        // Kiểm tra mã OTP có khớp không
        if (!verification.getOtpCode().equals(request.getOtp().trim())) {
            throw new RuntimeException("Mã OTP không chính xác. Vui lòng kiểm tra lại!");
        }

        // ✅ OTP hợp lệ -> Kích hoạt tài khoản
        user.setEmailVerified(true);
        user.setIsActive(true);
        user.setUpdatedAt(LocalDateTime.now());
        userRepository.save(user);

        // Xóa OTP khỏi CSDL để đảm bảo tính bảo mật (không dùng lại được)
        emailVerificationRepository.deleteByEmail(email);

        System.out.println("==========================================================================");
        System.out.println("[EVENTCRAFT AUTH] ✅ XÁC THỰC EMAIL THÀNH CÔNG CHO: " + email);
        System.out.println("[EVENTCRAFT AUTH] Tài khoản đã được kích hoạt (email_verified=1, is_active=1)");
        System.out.println("==========================================================================");

        // Cấp JWT token để người dùng đăng nhập ngay
        String token = jwtUtils.generateToken(user.getEmail(), user.getRole().getRoleName());
        return buildAuthResponse(token, user);
    }

    // =========================================================================
    // 3. GỬI LẠI MÃ OTP KÍCH HOẠT EMAIL (RESEND-OTP)
    //    - Xóa OTP cũ trong CSDL
    //    - Sinh OTP mới 6 số, lưu vào CSDL, hiệu lực 5 phút
    //    - In OTP ra Console
    // =========================================================================
    @Transactional
    public void resendOtp(ResendOtpRequest request) {
        String email = request.getEmail().toLowerCase().trim();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("Email không tồn tại trong hệ thống!"));

        if (Boolean.TRUE.equals(user.getEmailVerified())) {
            throw new RuntimeException("Tài khoản này đã được xác thực email trước đó. Vui lòng đăng nhập!");
        }

        // Xóa OTP cũ (nếu có) và sinh OTP mới
        sendAndSaveEmailVerificationOtp(email);
    }

    // =========================================================================
    // PRIVATE HELPER: Sinh OTP 6 số, lưu vào CSDL, in ra Console
    // =========================================================================
    @Transactional
    private void sendAndSaveEmailVerificationOtp(String email) {
        // Xóa OTP cũ trước khi tạo mới (đảm bảo chỉ có 1 OTP hợp lệ tại một thời điểm)
        emailVerificationRepository.deleteByEmail(email);

        // Sinh mã OTP 6 chữ số ngẫu nhiên
        String otp = String.valueOf(100000 + new Random().nextInt(900000));

        // Thiết lập thời hạn hiệu lực 5 phút
        LocalDateTime expiresAt = LocalDateTime.now().plusMinutes(5);

        // Lưu OTP vào CSDL
        EmailVerification verification = EmailVerification.builder()
                .email(email)
                .otpCode(otp)
                .expiresAt(expiresAt)
                .createdAt(LocalDateTime.now())
                .build();
        emailVerificationRepository.save(verification);

        // In OTP nổi bật ra Console (phục vụ Live Demo cho giảng viên)
        System.out.println("==========================================================================");
        System.out.println("[EVENTCRAFT OTP] 📧 MÃ XÁC THỰC EMAIL CHO: " + email);
        System.out.println(">>> MÃ OTP KÍCH HOẠT CỦA BẠN: [ " + otp + " ] <<<");
        System.out.println("(Hiệu lực: 5 phút | Đã lưu vào CSDL bảng email_verifications)");
        System.out.println("==========================================================================");
    }

    // =========================================================================
    // 4. ĐĂNG NHẬP TRUYỀN THỐNG (LOGIN) - Kiểm soát khóa tài khoản sau 5 lần sai
    // =========================================================================
    public AuthResponse login(LoginRequest request) {
        String email = request.getEmail().toLowerCase().trim();

        // Kiểm tra chính sách khóa tài khoản (Account Lockout Policy)
        LoginAttemptInfo attemptInfo = loginAttemptCache.get(email);
        if (attemptInfo != null && attemptInfo.lockoutUntil > System.currentTimeMillis()) {
            long remainingMinutes = (attemptInfo.lockoutUntil - System.currentTimeMillis()) / 60000 + 1;
            throw new RuntimeException("Tài khoản tạm thời bị khóa do nhập sai mật khẩu 5 lần. Vui lòng thử lại sau " + remainingMinutes + " phút!");
        }

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("Thông tin đăng nhập không chính xác!"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            LoginAttemptInfo current = loginAttemptCache.compute(email, (k, v) -> {
                if (v == null || (v.lockoutUntil > 0 && v.lockoutUntil <= System.currentTimeMillis())) {
                    return new LoginAttemptInfo(1, 0);
                }
                v.count++;
                if (v.count >= 5) {
                    v.lockoutUntil = System.currentTimeMillis() + 30 * 60 * 1000; // Khóa 30 phút
                }
                return v;
            });

            if (current.lockoutUntil > System.currentTimeMillis()) {
                throw new RuntimeException("Bạn đã nhập sai mật khẩu 5 lần liên tiếp. Tài khoản đã bị tạm khóa 30 phút!");
            } else {
                int remaining = 5 - current.count;
                throw new RuntimeException("Mật khẩu không chính xác! Bạn còn " + remaining + " lần thử trước khi tài khoản bị khóa.");
            }
        }

        // Đăng nhập thành công -> Reset bộ đếm số lần sai
        loginAttemptCache.remove(email);

        if (!Boolean.TRUE.equals(user.getIsActive())) {
            throw new RuntimeException("Tài khoản đã bị quản trị viên khóa!");
        }

        if (!Boolean.TRUE.equals(user.getEmailVerified())) {
            // Tự động sinh lại OTP kích hoạt nếu chưa có trong DB
            if (!emailVerificationRepository.existsByEmail(email)) {
                sendAndSaveEmailVerificationOtp(email);
            }
            throw new RuntimeException("Tài khoản chưa được xác thực email! Vui lòng nhập mã OTP để kích hoạt tài khoản trước khi đăng nhập.");
        }

        String token = jwtUtils.generateToken(user.getEmail(), user.getRole().getRoleName());
        return buildAuthResponse(token, user);
    }

    // =========================================================================
    // 5. ĐĂNG NHẬP GOOGLE OAUTH2
    // =========================================================================
    public AuthResponse loginWithGoogle(GoogleLoginRequest request) {
        if (request.getEmail() == null || request.getEmail().isBlank()) {
            throw new RuntimeException("Không tìm thấy thông tin email từ tài khoản Google!");
        }
        String email = request.getEmail().toLowerCase().trim();
        User user = userRepository.findByEmail(email).orElseGet(() -> {
            Role customerRole = roleRepository.findByRoleName("ROLE_CUSTOMER")
                    .orElseThrow(() -> new RuntimeException("Không tìm thấy vai trò ROLE_CUSTOMER"));

            String fullName = (request.getFullName() != null && !request.getFullName().isBlank())
                    ? request.getFullName() : "Người dùng Google";

            User newUser = User.builder()
                    .email(email)
                    .fullName(fullName)
                    .passwordHash(passwordEncoder.encode(UUID.randomUUID().toString()))
                    .avatarUrl(request.getAvatarUrl())
                    .role(customerRole)
                    .isActive(true)
                    .emailVerified(true) // Tài khoản Google đã được xác thực email từ Google
                    .createdAt(LocalDateTime.now())
                    .updatedAt(LocalDateTime.now())
                    .build();

            return userRepository.save(newUser);
        });

        String token = jwtUtils.generateToken(user.getEmail(), user.getRole().getRoleName());
        return buildAuthResponse(token, user);
    }

    // =========================================================================
    // 6. QUÊN MẬT KHẨU (FORGOT PASSWORD) - Sinh OTP 6 số, Cooldown 60s
    // =========================================================================
    public void sendForgotPasswordOtp(ForgotPasswordRequest request) {
        String email = request.getEmail().toLowerCase().trim();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("Email không tồn tại trong hệ thống!"));

        if (!Boolean.TRUE.equals(user.getIsActive())) {
            throw new RuntimeException("Tài khoản đã bị tạm khóa!");
        }

        OtpInfo existing = passwordResetOtpCache.get(email);
        if (existing != null && (System.currentTimeMillis() - existing.lastSentTime) < 60000) {
            long remainingSeconds = 60 - (System.currentTimeMillis() - existing.lastSentTime) / 1000;
            throw new RuntimeException("Vui lòng đợi " + remainingSeconds + " giây trước khi yêu cầu cấp lại mã OTP mới!");
        }

        String otp = String.valueOf(100000 + new Random().nextInt(900000));
        long expiryTime = System.currentTimeMillis() + 5 * 60 * 1000; // 5 phút

        passwordResetOtpCache.put(email, new OtpInfo(otp, expiryTime));

        System.out.println("==========================================================================");
        System.out.println("[EVENTCRAFT OTP DEMO] MÃ OTP ĐẶT LẠI MẬT KHẨU CHO EMAIL: " + email);
        System.out.println(">>> MÃ XÁC THỰC CỦA BẠN LÀ: [ " + otp + " ] <<<");
        System.out.println("(Hiệu lực: 5 phút | Cho phép nhập sai tối đa: 3 lần)");
        System.out.println("==========================================================================");
    }

    // =========================================================================
    // 7. ĐẶT LẠI MẬT KHẨU MỚI BẰNG MÃ OTP (RESET PASSWORD)
    // =========================================================================
    public void resetPasswordWithOtp(ResetPasswordRequest request) {
        String email = request.getEmail().toLowerCase().trim();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("Email không tồn tại trong hệ thống!"));

        OtpInfo otpInfo = passwordResetOtpCache.get(email);
        if (otpInfo == null) {
            throw new RuntimeException("Mã OTP không tồn tại hoặc chưa được khởi tạo!");
        }

        if (System.currentTimeMillis() > otpInfo.expiryTime) {
            passwordResetOtpCache.remove(email);
            throw new RuntimeException("Mã OTP đã hết hạn (quá 5 phút). Vui lòng yêu cầu cấp mã mới!");
        }

        if (!otpInfo.otp.equals(request.getOtp().trim())) {
            otpInfo.failedAttempts++;
            if (otpInfo.failedAttempts >= 3) {
                passwordResetOtpCache.remove(email);
                throw new RuntimeException("Bạn đã nhập sai OTP quá 3 lần. Mã OTP đã bị hủy để bảo mật, vui lòng yêu cầu cấp mã mới!");
            }
            int remaining = 3 - otpInfo.failedAttempts;
            throw new RuntimeException("Mã OTP không chính xác. Bạn còn " + remaining + " lần thử!");
        }

        if (request.getNewPassword() == null || request.getNewPassword().length() < 6) {
            throw new RuntimeException("Mật khẩu mới phải có tối thiểu 6 ký tự!");
        }

        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        user.setUpdatedAt(LocalDateTime.now());
        userRepository.save(user);

        // Hủy mã OTP sau khi sử dụng thành công
        passwordResetOtpCache.remove(email);

        System.out.println("[EVENTCRAFT AUTH] Đặt lại mật khẩu thành công cho tài khoản: " + email);
    }

    // =========================================================================
    // HELPER: Chuẩn hóa dữ liệu trả về cho Frontend
    // =========================================================================
    private AuthResponse buildAuthResponse(String token, User user) {
        String roleName = user.getRole() != null ? user.getRole().getRoleName() : "ROLE_CUSTOMER";
        String cleanRole = roleName.replaceFirst("^ROLE_", "");

        return AuthResponse.builder()
                .token(token)
                .userId(user.getUserId())
                .email(user.getEmail())
                .fullName(user.getFullName())
                .roleName(roleName)
                .role(cleanRole)
                .avatarUrl(user.getAvatarUrl())
                .build();
    }
}
