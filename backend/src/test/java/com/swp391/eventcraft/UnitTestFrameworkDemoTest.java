package com.swp391.eventcraft;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * =========================================================================================
 * BÀI TẬP LAB (EXERCISE 3) - BÁO CÁO THUYẾT TRÌNH NHÓM: DEMO KHÁI NIỆM UNIT TEST FRAMEWORK
 * Môn học: SWP391 / SWT301 - Đại học FPT
 * Đề tài: EventCraft - Intelligent Event Planning & Multi-Vendor Marketplace Platform
 * Framework: JUnit 5 (Jupiter) + Mockito 5 + AssertJ
 * =========================================================================================
 * Lớp này được thiết kế như một tài liệu sống (Living Documentation) phục vụ thuyết trình,
 * minh họa trực quan và đầy đủ 8 nhóm khái niệm nền tảng của Unit Testing trong Java.
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("DEMO TỔNG HỢP CÁC KHÁI NIỆM UNIT TEST FRAMEWORK (JUNIT 5 & MOCKITO)")
@Tag("presentation-demo")
public class UnitTestFrameworkDemoTest {

    // --- MOCK OBJECTS FOR DEMONSTRATION ---
    interface NotificationSender {
        boolean sendEmail(String toEmail, String subject, String body);
        int calculatePlatformFee(int amount, double feeRate);
    }

    interface AuditLogger {
        void logAction(String action, String user);
    }

    static class EventBookingServiceDemo {
        private final NotificationSender notificationSender;
        private final AuditLogger auditLogger;

        public EventBookingServiceDemo(NotificationSender notificationSender, AuditLogger auditLogger) {
            this.notificationSender = notificationSender;
            this.auditLogger = auditLogger;
        }

        public boolean confirmBooking(String userEmail, int totalAmount) {
            if (userEmail == null || userEmail.isBlank()) {
                throw new IllegalArgumentException("Email người dùng không được để trống!");
            }
            if (totalAmount <= 0) {
                throw new IllegalArgumentException("Giá trị đơn đặt phải lớn hơn 0!");
            }

            // Tính phí sàn 5%
            int fee = notificationSender.calculatePlatformFee(totalAmount, 0.05);

            // Ghi nhật ký kiểm toán
            auditLogger.logAction("BOOKING_CONFIRMED", userEmail);

            // Gửi email xác nhận
            return notificationSender.sendEmail(userEmail, "Xác nhận đặt tiệc", "Đơn trị giá: " + totalAmount + ", Phí sàn: " + fee);
        }
    }

    @Mock
    private NotificationSender mockNotificationSender;

    @Mock
    private AuditLogger mockAuditLogger;

    @Captor
    private ArgumentCaptor<String> emailCaptor;

    private EventBookingServiceDemo bookingService;

    // =========================================================================================
    // 1. LIFECYCLE ANNOTATIONS (@BeforeAll, @BeforeEach, @AfterEach, @AfterAll)
    // =========================================================================================
    @BeforeAll
    static void initAll() {
        System.out.println("[LIFECYCLE] @BeforeAll: Khởi tạo môi trường kiểm thử chung (Chạy 1 lần duy nhất trước mọi test)");
    }

    @BeforeEach
    void initEach(TestInfo testInfo) {
        System.out.println("[LIFECYCLE] @BeforeEach: Chuẩn bị dữ liệu cho test case -> " + testInfo.getDisplayName());
        bookingService = new EventBookingServiceDemo(mockNotificationSender, mockAuditLogger);
    }

    @AfterEach
    void tearDownEach() {
        System.out.println("[LIFECYCLE] @AfterEach: Dọn dẹp tài nguyên sau khi kết thúc test case");
    }

    @AfterAll
    static void tearDownAll() {
        System.out.println("[LIFECYCLE] @AfterAll: Kết thúc toàn bộ Test Suite (Chạy 1 lần duy nhất)");
    }

    // =========================================================================================
    // 2. CƠ CHẾ ASSERTIONS CƠ BẢN CỦA JUNIT 5 (@Test, assertEquals, assertAll, assertThrows)
    // =========================================================================================
    @Nested
    @DisplayName("Khái niệm 1: JUnit 5 Assertions & AAA Pattern")
    class JUnit5AssertionsConceptTests {

        @Test
        @DisplayName("1.1. Minh họa mô hình AAA (Arrange - Act - Assert) & assertAll")
        void demoAaaPatternAndAssertAll() {
            // [ARRANGE - Chuẩn bị]
            String customerEmail = "khachhang@eventcraft.com";
            int bookingTotal = 20_000_000; // 20 triệu VNĐ
            when(mockNotificationSender.calculatePlatformFee(bookingTotal, 0.05)).thenReturn(1_000_000);
            when(mockNotificationSender.sendEmail(anyString(), anyString(), anyString())).thenReturn(true);

            // [ACT - Thực thi]
            boolean result = bookingService.confirmBooking(customerEmail, bookingTotal);

            // [ASSERT - Khẳng định]
            // assertAll giúp gom nhiều assertion lại: dù assertion đầu fail, các assertion sau vẫn được kiểm tra
            assertAll("Kiểm tra toàn diện kết quả xác nhận đơn tiệc",
                    () -> assertTrue(result, "Xác nhận đơn tiệc phải thành công"),
                    () -> assertEquals(1_000_000, mockNotificationSender.calculatePlatformFee(bookingTotal, 0.05)),
                    () -> assertNotNull(customerEmail, "Email không được null")
            );
        }

        @Test
        @DisplayName("1.2. Minh họa kiểm thử Exception với assertThrows")
        void demoAssertThrows() {
            // [ARRANGE]
            String invalidEmail = "";
            int validAmount = 10_000_000;

            // [ACT & ASSERT]
            IllegalArgumentException exception = assertThrows(
                    IllegalArgumentException.class,
                    () -> bookingService.confirmBooking(invalidEmail, validAmount),
                    "Phải ném IllegalArgumentException khi email bị rỗng"
            );

            assertEquals("Email người dùng không được để trống!", exception.getMessage());
        }

        @Test
        @DisplayName("1.3. Minh họa kiểm thử hiệu năng & Timeout với assertTimeout")
        void demoAssertTimeout() {
            // Khẳng định thao tác logic phải hoàn thành trong vòng 50 miligiây
            assertTimeout(Duration.ofMillis(50), () -> {
                int sum = 0;
                for (int i = 0; i < 1000; i++) sum += i;
                assertTrue(sum > 0);
            });
        }
    }

    // =========================================================================================
    // 3. CƠ CHẾ THƯ VIỆN ASSERTJ FLUENT ASSERTIONS (assertThat)
    // =========================================================================================
    @Nested
    @DisplayName("Khái niệm 2: AssertJ Fluent Assertions (Dễ đọc & Giàu ngữ nghĩa)")
    class AssertJConceptTests {

        @Test
        @DisplayName("2.1. Minh họa chuỗi Assertion liên hoàn (Chaining Assertions)")
        void demoAssertJFluentChaining() {
            String roleName = "ROLE_VENDOR";
            List<String> eventCategories = List.of("Âm thanh ánh sáng", "Tiệc cưới", "Trang trí sân khấu", "Quay phim chụp ảnh");

            // AssertJ cho phép viết câu kiểm tra tự nhiên như ngôn ngữ nói
            assertThat(roleName)
                    .isNotNull()
                    .startsWith("ROLE_")
                    .endsWith("VENDOR")
                    .hasSize(11);

            assertThat(eventCategories)
                    .isNotEmpty()
                    .hasSize(4)
                    .contains("Tiệc cưới", "Quay phim chụp ảnh")
                    .doesNotContain("Bắn pháo hoa trái phép");
        }

        @Test
        @DisplayName("2.2. Minh họa assertThatThrownBy trong AssertJ")
        void demoAssertJThrownBy() {
            assertThatThrownBy(() -> bookingService.confirmBooking("valid@eventcraft.com", -500_000))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("lớn hơn 0");
        }
    }

    // =========================================================================================
    // 4. KIỂM THỬ THAM SỐ HÓA (PARAMETERIZED TESTS: @ValueSource, @CsvSource, @NullAndEmptySource)
    // =========================================================================================
    @Nested
    @DisplayName("Khái niệm 3: Parameterized Tests (Tái sử dụng Test Case với nhiều bộ dữ liệu)")
    class ParameterizedTestsConceptTests {

        @ParameterizedTest(name = "Kiểm tra email rỗng/null: [{0}]")
        @NullAndEmptySource
        @ValueSource(strings = {"   ", "\t", "\n"})
        @DisplayName("3.1. Parameterized Test bắt lỗi dữ liệu email không hợp lệ")
        void demoParameterizedNullAndEmptyEmails(String badEmail) {
            assertThrows(IllegalArgumentException.class, () ->
                    bookingService.confirmBooking(badEmail, 15_000_000));
        }

        @ParameterizedTest(name = "Đơn {0} đ -> Hoa hồng sàn 5% dự kiến là {1} đ")
        @CsvSource({
                "10000000, 500000",
                "20000000, 1000000",
                "50000000, 2500000",
                "100000000, 5000000"
        })
        @DisplayName("3.2. CsvSource kiểm thử ma trận tính phí hoa hồng nền tảng")
        void demoParameterizedCsvSource(int totalAmount, int expectedFee) {
            when(mockNotificationSender.calculatePlatformFee(totalAmount, 0.05)).thenReturn(expectedFee);

            int actualFee = mockNotificationSender.calculatePlatformFee(totalAmount, 0.05);

            assertEquals(expectedFee, actualFee, "Phí hoa hồng 5% tính toán phải khớp chính xác");
        }
    }

    // =========================================================================================
    // 5. CÁC KHÁI NIỆM CỐT LÕI CỦA MOCKITO (STUBBING, VERIFICATION, ARGUMENT CAPTURE)
    // =========================================================================================
    @Nested
    @DisplayName("Khái niệm 4: Mockito Framework (Stubbing, Verify, Captor, InOrder)")
    class MockitoConceptsTests {

        @Test
        @DisplayName("4.1. Mockito Stubbing & Argument Matchers (when...thenReturn)")
        void demoMockitoStubbing() {
            // Stubbing với Argument Matcher linh hoạt (anyString(), anyInt())
            when(mockNotificationSender.sendEmail(eq("vip@eventcraft.com"), anyString(), anyString())).thenReturn(true);
            when(mockNotificationSender.calculatePlatformFee(anyInt(), anyDouble())).thenReturn(250_000);

            boolean status = bookingService.confirmBooking("vip@eventcraft.com", 5_000_000);

            assertTrue(status);
        }

        @Test
        @DisplayName("4.2. Mockito Behavior Verification (verify, times, never, verifyNoMoreInteractions)")
        void demoMockitoVerification() {
            when(mockNotificationSender.calculatePlatformFee(10_000_000, 0.05)).thenReturn(500_000);
            when(mockNotificationSender.sendEmail(anyString(), anyString(), anyString())).thenReturn(true);

            bookingService.confirmBooking("test@eventcraft.com", 10_000_000);

            // 1. Kiểm tra method được gọi đúng 1 lần
            verify(mockAuditLogger, times(1)).logAction("BOOKING_CONFIRMED", "test@eventcraft.com");
            verify(mockNotificationSender, times(1)).calculatePlatformFee(10_000_000, 0.05);
            verify(mockNotificationSender, times(1)).sendEmail(eq("test@eventcraft.com"), anyString(), anyString());

            // 2. Khẳng định method KHÔNG BAO GIỜ bị gọi
            verify(mockAuditLogger, never()).logAction(eq("BOOKING_CANCELLED"), anyString());

            // 3. Khẳng định không còn lời gọi hàm nào phát sinh ngoài ý muốn
            verifyNoMoreInteractions(mockAuditLogger);
        }

        @Test
        @DisplayName("4.3. Mockito InOrder Verification (Kiểm tra thứ tự thực thi chuẩn)")
        void demoMockitoInOrderVerification() {
            when(mockNotificationSender.calculatePlatformFee(8_000_000, 0.05)).thenReturn(400_000);
            when(mockNotificationSender.sendEmail(anyString(), anyString(), anyString())).thenReturn(true);

            bookingService.confirmBooking("ordered@eventcraft.com", 8_000_000);

            // Đảm bảo thứ tự nghiệp vụ: Tính phí -> Ghi Audit Log -> Gửi Email
            InOrder inOrder = inOrder(mockNotificationSender, mockAuditLogger);
            inOrder.verify(mockNotificationSender).calculatePlatformFee(8_000_000, 0.05);
            inOrder.verify(mockAuditLogger).logAction("BOOKING_CONFIRMED", "ordered@eventcraft.com");
            inOrder.verify(mockNotificationSender).sendEmail(eq("ordered@eventcraft.com"), anyString(), anyString());
        }

        @Test
        @DisplayName("4.4. Mockito ArgumentCaptor (Bắt và kiểm tra tham số ngầm)")
        void demoArgumentCaptor() {
            when(mockNotificationSender.calculatePlatformFee(12_000_000, 0.05)).thenReturn(600_000);
            when(mockNotificationSender.sendEmail(anyString(), anyString(), anyString())).thenReturn(true);

            bookingService.confirmBooking("captor.test@eventcraft.com", 12_000_000);

            // Bắt giá trị được truyền vào tham số toEmail của method sendEmail
            verify(mockNotificationSender).sendEmail(emailCaptor.capture(), anyString(), anyString());

            assertEquals("captor.test@eventcraft.com", emailCaptor.getValue(),
                    "Giá trị email được hàm xử lý phải khớp chính xác với captor bắt được");
        }
    }
}
