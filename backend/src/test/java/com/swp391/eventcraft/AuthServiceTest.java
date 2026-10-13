package com.swp391.eventcraft;

import com.swp391.eventcraft.config.JwtUtils;
import com.swp391.eventcraft.dto.AuthResponse;
import com.swp391.eventcraft.dto.RegisterRequest;
import com.swp391.eventcraft.dto.VerifyOtpRequest;
import com.swp391.eventcraft.entity.EmailVerification;
import com.swp391.eventcraft.entity.Role;
import com.swp391.eventcraft.entity.User;
import com.swp391.eventcraft.repository.EmailVerificationRepository;
import com.swp391.eventcraft.repository.RoleRepository;
import com.swp391.eventcraft.repository.UserRepository;
import com.swp391.eventcraft.service.AuthService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class AuthServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private RoleRepository roleRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtUtils jwtUtils;

    @Mock
    private EmailVerificationRepository emailVerificationRepository;

    @InjectMocks
    private AuthService authService;

    private Role customerRole;

    @BeforeEach
    void setUp() {
        customerRole = new Role(2, "ROLE_CUSTOMER", "Khách hàng");
    }

    @Test
    @DisplayName("TC-AUTH-01: Đăng ký thành công tài khoản mới - Tạo OTP và trạng thái chưa kích hoạt")
    void testRegister_Success_NewUser() {
        RegisterRequest request = new RegisterRequest();
        request.setEmail("test@eventcraft.com");
        request.setPassword("123456");
        request.setFullName("Nguyen Van Test");
        request.setPhoneNumber("0905123456");
        request.setRoleName("ROLE_CUSTOMER");

        when(userRepository.findByEmail("test@eventcraft.com")).thenReturn(Optional.empty());
        when(roleRepository.findByRoleName("ROLE_CUSTOMER")).thenReturn(Optional.of(customerRole));
        when(passwordEncoder.encode(anyString())).thenReturn("hashed_password");
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> {
            User u = invocation.getArgument(0);
            u.setUserId(100);
            return u;
        });

        AuthResponse response = authService.register(request);

        assertNotNull(response);
        assertEquals("test@eventcraft.com", response.getEmail());
        assertNull(response.getToken(), "Tài khoản mới chưa kích hoạt không được cấp JWT Token");
        verify(emailVerificationRepository, atLeastOnce()).save(any(EmailVerification.class));
    }

    @Test
    @DisplayName("TC-AUTH-02: Đăng ký thất bại khi email đã tồn tại và đã kích hoạt")
    void testRegister_DuplicateActiveEmail_ThrowsException() {
        RegisterRequest request = new RegisterRequest();
        request.setEmail("existing@eventcraft.com");
        request.setPassword("123456");

        User existingUser = User.builder()
                .email("existing@eventcraft.com")
                .emailVerified(true)
                .build();

        when(userRepository.findByEmail("existing@eventcraft.com")).thenReturn(Optional.of(existingUser));

        RuntimeException exception = assertThrows(RuntimeException.class, () -> authService.register(request));
        assertTrue(exception.getMessage().contains("Email đã tồn tại và đã được kích hoạt"));
    }

    @Test
    @DisplayName("TC-AUTH-03: Kích hoạt email thành công bằng mã OTP hợp lệ - Cấp JWT Token")
    void testVerifyEmail_Success() {
        VerifyOtpRequest request = new VerifyOtpRequest("test@eventcraft.com", "123456");

        User user = User.builder()
                .userId(1)
                .email("test@eventcraft.com")
                .role(customerRole)
                .emailVerified(false)
                .isActive(false)
                .build();

        EmailVerification verification = EmailVerification.builder()
                .email("test@eventcraft.com")
                .otpCode("123456")
                .expiresAt(LocalDateTime.now().plusMinutes(3)) // còn hạn
                .build();

        when(userRepository.findByEmail("test@eventcraft.com")).thenReturn(Optional.of(user));
        when(emailVerificationRepository.findByEmail("test@eventcraft.com")).thenReturn(Optional.of(verification));
        when(jwtUtils.generateToken(anyString(), anyString())).thenReturn("mocked_jwt_token");

        AuthResponse response = authService.verifyEmail(request);

        assertNotNull(response);
        assertEquals("mocked_jwt_token", response.getToken());
        assertTrue(user.getEmailVerified());
        assertTrue(user.getIsActive());
        verify(emailVerificationRepository).deleteByEmail("test@eventcraft.com");
    }

    @Test
    @DisplayName("TC-AUTH-04: Kích hoạt thất bại khi mã OTP đã hết hạn (> 5 phút)")
    void testVerifyEmail_ExpiredOtp_ThrowsException() {
        VerifyOtpRequest request = new VerifyOtpRequest("test@eventcraft.com", "123456");

        User user = User.builder()
                .email("test@eventcraft.com")
                .emailVerified(false)
                .build();

        EmailVerification expiredVerification = EmailVerification.builder()
                .email("test@eventcraft.com")
                .otpCode("123456")
                .expiresAt(LocalDateTime.now().minusMinutes(1)) // đã hết hạn
                .build();

        when(userRepository.findByEmail("test@eventcraft.com")).thenReturn(Optional.of(user));
        when(emailVerificationRepository.findByEmail("test@eventcraft.com")).thenReturn(Optional.of(expiredVerification));

        RuntimeException exception = assertThrows(RuntimeException.class, () -> authService.verifyEmail(request));
        assertTrue(exception.getMessage().contains("Mã OTP đã hết hạn"));
        verify(emailVerificationRepository).deleteByEmail("test@eventcraft.com");
    }

    @Test
    @DisplayName("TC-AUTH-05: Kích hoạt thất bại khi nhập sai mã OTP")
    void testVerifyEmail_WrongOtp_ThrowsException() {
        VerifyOtpRequest request = new VerifyOtpRequest("test@eventcraft.com", "999999"); // mã sai

        User user = User.builder()
                .email("test@eventcraft.com")
                .emailVerified(false)
                .build();

        EmailVerification verification = EmailVerification.builder()
                .email("test@eventcraft.com")
                .otpCode("123456") // mã đúng
                .expiresAt(LocalDateTime.now().plusMinutes(4))
                .build();

        when(userRepository.findByEmail("test@eventcraft.com")).thenReturn(Optional.of(user));
        when(emailVerificationRepository.findByEmail("test@eventcraft.com")).thenReturn(Optional.of(verification));

        RuntimeException exception = assertThrows(RuntimeException.class, () -> authService.verifyEmail(request));
        assertTrue(exception.getMessage().contains("Mã OTP không chính xác"));
    }
}
