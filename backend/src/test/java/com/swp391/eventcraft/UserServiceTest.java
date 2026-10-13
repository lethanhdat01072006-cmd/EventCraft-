package com.swp391.eventcraft;

import com.swp391.eventcraft.dto.ChangePasswordRequest;
import com.swp391.eventcraft.dto.UpdateProfileRequest;
import com.swp391.eventcraft.dto.UserProfileResponse;
import com.swp391.eventcraft.entity.Role;
import com.swp391.eventcraft.entity.User;
import com.swp391.eventcraft.repository.UserRepository;
import com.swp391.eventcraft.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("UserService Unit Tests - Profile & Security Management")
public class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @InjectMocks
    private UserService userService;

    private User sampleUser;
    private Role customerRole;

    @BeforeEach
    void setUp() {
        customerRole = new Role(2, "ROLE_CUSTOMER", "Khách hàng");
        sampleUser = User.builder()
                .userId(1)
                .email("test.user@eventcraft.com")
                .fullName("Nguyen Van Test")
                .phoneNumber("0905123456")
                .passwordHash("$2a$12$hashedPasswordExample12345678901234567890123456789012")
                .role(customerRole)
                .avatarUrl("/uploads/avatars/default.png")
                .emailVerified(true)
                .isActive(true)
                .createdAt(LocalDateTime.now().minusDays(10))
                .updatedAt(LocalDateTime.now().minusDays(1))
                .build();
    }

    @Nested
    @DisplayName("1. Get Profile Tests (Xem thông tin cá nhân)")
    class GetProfileTests {

        @Test
        @DisplayName("TC-USER-01: Lấy thông tin hồ sơ thành công khi email tồn tại")
        void testGetProfile_Success() {
            // Arrange
            when(userRepository.findByEmail("test.user@eventcraft.com"))
                    .thenReturn(Optional.of(sampleUser));

            // Act
            UserProfileResponse response = userService.getProfile("test.user@eventcraft.com");

            // Assert
            assertAll("Xác thực thông tin UserProfileResponse",
                    () -> assertNotNull(response),
                    () -> assertEquals("test.user@eventcraft.com", response.getEmail()),
                    () -> assertEquals("Nguyen Van Test", response.getFullName()),
                    () -> assertEquals("0905123456", response.getPhoneNumber()),
                    () -> assertEquals("ROLE_CUSTOMER", response.getRoleName()),
                    () -> assertTrue(response.getEmailVerified())
            );

            // AssertJ Fluent Assertion
            assertThat(response.getAvatarUrl()).startsWith("/uploads/avatars/");
            verify(userRepository, times(1)).findByEmail("test.user@eventcraft.com");
        }

        @Test
        @DisplayName("TC-USER-02: Ném RuntimeException khi email người dùng không tồn tại")
        void testGetProfile_UserNotFound_ThrowsException() {
            // Arrange
            when(userRepository.findByEmail("notfound@eventcraft.com"))
                    .thenReturn(Optional.empty());

            // Act & Assert
            RuntimeException exception = assertThrows(RuntimeException.class, () ->
                    userService.getProfile("notfound@eventcraft.com")
            );

            assertEquals("Không tìm thấy thông tin người dùng!", exception.getMessage());
            verify(userRepository, times(1)).findByEmail("notfound@eventcraft.com");
        }
    }

    @Nested
    @DisplayName("2. Update Profile Tests (Cập nhật hồ sơ)")
    class UpdateProfileTests {

        @Test
        @DisplayName("TC-USER-03: Cập nhật họ tên và số điện thoại thành công")
        void testUpdateProfile_Success() {
            // Arrange
            UpdateProfileRequest request = new UpdateProfileRequest("Le Van Cap Nhat", "0987654321", null);
            when(userRepository.findByEmail("test.user@eventcraft.com"))
                    .thenReturn(Optional.of(sampleUser));
            when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

            // Act
            UserProfileResponse response = userService.updateProfile("test.user@eventcraft.com", request);

            // Assert
            assertNotNull(response);
            assertEquals("Le Van Cap Nhat", response.getFullName());
            assertEquals("0987654321", response.getPhoneNumber());

            // Capture argument to verify saved values
            ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
            verify(userRepository).save(userCaptor.capture());
            User savedUser = userCaptor.getValue();
            assertEquals("Le Van Cap Nhat", savedUser.getFullName());
            assertEquals("0987654321", savedUser.getPhoneNumber());
        }

        @Test
        @DisplayName("TC-USER-04: Cập nhật hồ sơ sử dụng trường alias phone")
        void testUpdateProfile_WithPhoneAlias() {
            // Arrange
            UpdateProfileRequest request = new UpdateProfileRequest(null, null, "0911223344");
            when(userRepository.findByEmail("test.user@eventcraft.com"))
                    .thenReturn(Optional.of(sampleUser));
            when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

            // Act
            UserProfileResponse response = userService.updateProfile("test.user@eventcraft.com", request);

            // Assert
            assertEquals("0911223344", response.getPhoneNumber());
            assertEquals("Nguyen Van Test", response.getFullName(), "Họ tên cũ phải được giữ nguyên khi request rỗng");
        }
    }

    @Nested
    @DisplayName("3. Change Password Tests (Đổi mật khẩu an toàn)")
    class ChangePasswordTests {

        @Test
        @DisplayName("TC-USER-05: Đổi mật khẩu thành công khi thông tin hợp lệ")
        void testChangePassword_Success() {
            // Arrange
            ChangePasswordRequest request = new ChangePasswordRequest("OldPass@123", "NewPass@456", "NewPass@456");
            when(userRepository.findByEmail("test.user@eventcraft.com"))
                    .thenReturn(Optional.of(sampleUser));
            when(passwordEncoder.matches("OldPass@123", sampleUser.getPasswordHash())).thenReturn(true);
            when(passwordEncoder.encode("NewPass@456")).thenReturn("$2a$12$newHashedPasswordEncoded123456");

            // Act
            userService.changePassword("test.user@eventcraft.com", request);

            // Assert
            ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
            verify(userRepository).save(captor.capture());
            assertEquals("$2a$12$newHashedPasswordEncoded123456", captor.getValue().getPasswordHash());
        }

        @Test
        @DisplayName("TC-USER-06: Thất bại khi bỏ trống mật khẩu hiện tại")
        void testChangePassword_OldPasswordBlank_ThrowsException() {
            ChangePasswordRequest request = new ChangePasswordRequest("", "NewPass@456", "NewPass@456");
            when(userRepository.findByEmail("test.user@eventcraft.com"))
                    .thenReturn(Optional.of(sampleUser));

            RuntimeException ex = assertThrows(RuntimeException.class, () ->
                    userService.changePassword("test.user@eventcraft.com", request));
            assertEquals("Vui lòng nhập mật khẩu hiện tại!", ex.getMessage());
            verify(passwordEncoder, never()).encode(anyString());
        }

        @Test
        @DisplayName("TC-USER-07: Thất bại khi mật khẩu hiện tại không chính xác")
        void testChangePassword_OldPasswordIncorrect_ThrowsException() {
            ChangePasswordRequest request = new ChangePasswordRequest("WrongOldPass", "NewPass@456", "NewPass@456");
            when(userRepository.findByEmail("test.user@eventcraft.com"))
                    .thenReturn(Optional.of(sampleUser));
            when(passwordEncoder.matches("WrongOldPass", sampleUser.getPasswordHash())).thenReturn(false);

            RuntimeException ex = assertThrows(RuntimeException.class, () ->
                    userService.changePassword("test.user@eventcraft.com", request));
            assertEquals("Mật khẩu hiện tại không chính xác!", ex.getMessage());
            verify(userRepository, never()).save(any());
        }

        @ParameterizedTest(name = "Mật khẩu mới quá ngắn: {0}")
        @ValueSource(strings = {"12345", "abc", ""})
        @DisplayName("TC-USER-08: Thất bại khi mật khẩu mới dưới 6 ký tự")
        void testChangePassword_NewPasswordTooShort_ThrowsException(String shortPassword) {
            ChangePasswordRequest request = new ChangePasswordRequest("OldPass@123", shortPassword, shortPassword);
            when(userRepository.findByEmail("test.user@eventcraft.com"))
                    .thenReturn(Optional.of(sampleUser));
            when(passwordEncoder.matches("OldPass@123", sampleUser.getPasswordHash())).thenReturn(true);

            RuntimeException ex = assertThrows(RuntimeException.class, () ->
                    userService.changePassword("test.user@eventcraft.com", request));
            assertEquals("Mật khẩu mới phải có tối thiểu 6 ký tự!", ex.getMessage());
        }

        @Test
        @DisplayName("TC-USER-09: Thất bại khi mật khẩu mới trùng mật khẩu cũ")
        void testChangePassword_NewPasswordSameAsOld_ThrowsException() {
            ChangePasswordRequest request = new ChangePasswordRequest("SamePassword@123", "SamePassword@123", "SamePassword@123");
            when(userRepository.findByEmail("test.user@eventcraft.com"))
                    .thenReturn(Optional.of(sampleUser));
            when(passwordEncoder.matches("SamePassword@123", sampleUser.getPasswordHash())).thenReturn(true);

            RuntimeException ex = assertThrows(RuntimeException.class, () ->
                    userService.changePassword("test.user@eventcraft.com", request));
            assertEquals("Mật khẩu mới không được trùng với mật khẩu cũ!", ex.getMessage());
        }

        @Test
        @DisplayName("TC-USER-10: Thất bại khi xác nhận mật khẩu không khớp")
        void testChangePassword_ConfirmPasswordMismatch_ThrowsException() {
            ChangePasswordRequest request = new ChangePasswordRequest("OldPass@123", "NewPass@456", "DifferentConfirmPass");
            when(userRepository.findByEmail("test.user@eventcraft.com"))
                    .thenReturn(Optional.of(sampleUser));
            when(passwordEncoder.matches("OldPass@123", sampleUser.getPasswordHash())).thenReturn(true);

            RuntimeException ex = assertThrows(RuntimeException.class, () ->
                    userService.changePassword("test.user@eventcraft.com", request));
            assertEquals("Mật khẩu mới và xác nhận mật khẩu không khớp!", ex.getMessage());
        }
    }

    @Nested
    @DisplayName("4. Avatar Upload Validation Tests (Xác thực tải ảnh đại diện)")
    class AvatarUploadValidationTests {

        @Test
        @DisplayName("TC-USER-11: Thất bại khi file ảnh rỗng hoặc null")
        void testUploadAvatar_EmptyFile_ThrowsException() {
            when(userRepository.findByEmail("test.user@eventcraft.com"))
                    .thenReturn(Optional.of(sampleUser));

            MultipartFile emptyFile = new MockMultipartFile("file", "empty.png", "image/png", new byte[0]);

            RuntimeException ex = assertThrows(RuntimeException.class, () ->
                    userService.uploadAvatar("test.user@eventcraft.com", emptyFile));
            assertEquals("Vui lòng chọn một tệp ảnh để tải lên!", ex.getMessage());
        }

        @Test
        @DisplayName("TC-USER-12: Thất bại khi dung lượng ảnh vượt quá giới hạn 5MB")
        void testUploadAvatar_FileExceedsLimit_ThrowsException() {
            when(userRepository.findByEmail("test.user@eventcraft.com"))
                    .thenReturn(Optional.of(sampleUser));

            // Tạo mock file kích thước 5MB + 1 byte
            byte[] largeContent = new byte[100];
            MockMultipartFile largeFile = new MockMultipartFile("file", "large.png", "image/png", largeContent) {
                @Override
                public long getSize() {
                    return 5 * 1024 * 1024 + 1; // 5MB + 1 byte
                }
            };

            RuntimeException ex = assertThrows(RuntimeException.class, () ->
                    userService.uploadAvatar("test.user@eventcraft.com", largeFile));
            assertTrue(ex.getMessage().contains("vượt quá giới hạn cho phép (tối đa 5MB)"));
        }

        @ParameterizedTest(name = "Định dạng file cấm: {0}")
        @ValueSource(strings = {"avatar.exe", "script.sh", "document.pdf", "image.gif", "shell.php"})
        @DisplayName("TC-USER-13: Thất bại khi tải file không thuộc định dạng cho phép (.jpg, .jpeg, .png, .webp)")
        void testUploadAvatar_InvalidExtension_ThrowsException(String filename) {
            when(userRepository.findByEmail("test.user@eventcraft.com"))
                    .thenReturn(Optional.of(sampleUser));

            MockMultipartFile invalidFile = new MockMultipartFile("file", filename, "application/octet-stream", "dummy_content".getBytes());

            RuntimeException ex = assertThrows(RuntimeException.class, () ->
                    userService.uploadAvatar("test.user@eventcraft.com", invalidFile));
            assertTrue(ex.getMessage().contains("Định dạng ảnh không hợp lệ!"),
                    "Hệ thống phải từ chối đuôi mở rộng không an toàn: " + filename);
        }
    }
}
