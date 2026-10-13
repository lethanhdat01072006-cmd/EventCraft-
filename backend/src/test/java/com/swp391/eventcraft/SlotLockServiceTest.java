package com.swp391.eventcraft;

import com.swp391.eventcraft.dto.HoldSlotRequest;
import com.swp391.eventcraft.dto.HoldSlotResponse;
import com.swp391.eventcraft.entity.VendorSchedule;
import com.swp391.eventcraft.exception.SlotAlreadyLockedException;
import com.swp391.eventcraft.repository.VendorScheduleRepository;
import com.swp391.eventcraft.service.impl.SlotLockServiceImpl;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class SlotLockServiceTest {

    @Mock
    private VendorScheduleRepository scheduleRepository;

    @InjectMocks
    private SlotLockServiceImpl slotLockService;

    @Test
    @DisplayName("TC-LOCK-01: Khóa slot thành công khi Vendor chưa có lịch cho ngày đó (Tạo mới bản ghi khóa 15p)")
    void testHoldSlot_Success_NewSchedule() {
        LocalDate eventDate = LocalDate.now().plusDays(10);
        HoldSlotRequest request = HoldSlotRequest.builder()
                .vendorIds(List.of(1L))
                .eventDate(eventDate)
                .eventTime("17:30 - 21:00")
                .build();

        when(scheduleRepository.findByVendorIdAndWorkDate(1L, eventDate)).thenReturn(Optional.empty());

        HoldSlotResponse response = slotLockService.holdSlot(request);

        assertNotNull(response);
        assertTrue(response.getSuccess());
        assertEquals(900L, response.getRemainingSeconds(), "Phải cấp 900 giây (15 phút) đếm ngược");
        assertNotNull(response.getHoldExpiresAt());
        verify(scheduleRepository).save(any(VendorSchedule.class));
    }

    @Test
    @DisplayName("TC-LOCK-02: Khóa slot thành công khi Vendor đã có lịch và đang rảnh (Atomic SQL Update trả về 1)")
    void testHoldSlot_Success_AtomicLock() {
        LocalDate eventDate = LocalDate.now().plusDays(5);
        HoldSlotRequest request = HoldSlotRequest.builder()
                .vendorIds(List.of(2L))
                .eventDate(eventDate)
                .build();

        VendorSchedule schedule = VendorSchedule.builder()
                .vendorId(2L)
                .workDate(eventDate)
                .isBlackout(false)
                .lockExpiresAt(null) // đang rảnh
                .build();

        when(scheduleRepository.findByVendorIdAndWorkDate(2L, eventDate)).thenReturn(Optional.of(schedule));
        when(scheduleRepository.lockSlotAtomic(2L, eventDate)).thenReturn(1); // update thành công 1 row

        HoldSlotResponse response = slotLockService.holdSlot(request);

        assertNotNull(response);
        assertTrue(response.getSuccess());
        verify(scheduleRepository).lockSlotAtomic(2L, eventDate);
    }

    @Test
    @DisplayName("TC-LOCK-03: Khóa slot thất bại khi đối tác đang bị người khác giữ chỗ (Atomic SQL Update trả về 0)")
    void testHoldSlot_Failed_AlreadyLocked_ThrowsException() {
        LocalDate eventDate = LocalDate.now().plusDays(7);
        HoldSlotRequest request = HoldSlotRequest.builder()
                .vendorIds(List.of(3L))
                .eventDate(eventDate)
                .build();

        VendorSchedule lockedSchedule = VendorSchedule.builder()
                .vendorId(3L)
                .workDate(eventDate)
                .isBlackout(false)
                .lockExpiresAt(LocalDateTime.now().plusMinutes(10)) // đang bị người khác giữ chỗ
                .build();

        when(scheduleRepository.findByVendorIdAndWorkDate(3L, eventDate)).thenReturn(Optional.of(lockedSchedule));
        when(scheduleRepository.lockSlotAtomic(3L, eventDate)).thenReturn(0); // 0 row updated -> bị tranh chấp slot

        SlotAlreadyLockedException exception = assertThrows(SlotAlreadyLockedException.class,
                () -> slotLockService.holdSlot(request));

        assertTrue(exception.getMessage().contains("đã có người đặt hoặc đang trong 15 phút giữ chỗ"));
    }

    @Test
    @DisplayName("TC-LOCK-04: Khóa slot thất bại khi Vendor đã đánh dấu ngày nghỉ (Blackout = true)")
    void testHoldSlot_Failed_Blackout_ThrowsException() {
        LocalDate eventDate = LocalDate.now().plusDays(3);
        HoldSlotRequest request = HoldSlotRequest.builder()
                .vendorIds(List.of(4L))
                .eventDate(eventDate)
                .build();

        VendorSchedule blackoutSchedule = VendorSchedule.builder()
                .vendorId(4L)
                .workDate(eventDate)
                .isBlackout(true) // đối tác nghỉ
                .build();

        when(scheduleRepository.findByVendorIdAndWorkDate(4L, eventDate)).thenReturn(Optional.of(blackoutSchedule));

        SlotAlreadyLockedException exception = assertThrows(SlotAlreadyLockedException.class,
                () -> slotLockService.holdSlot(request));

        assertTrue(exception.getMessage().contains("đã đánh dấu ngày nghỉ"));
    }

    @Test
    @DisplayName("TC-LOCK-05: Khóa slot thất bại khi chọn ngày trong quá khứ")
    void testHoldSlot_InvalidDate_PastDate_ThrowsException() {
        HoldSlotRequest request = HoldSlotRequest.builder()
                .vendorIds(List.of(1L))
                .eventDate(LocalDate.now().minusDays(1)) // ngày hôm qua
                .build();

        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> slotLockService.holdSlot(request));

        assertTrue(exception.getMessage().contains("không thể là ngày trong quá khứ"));
    }
}
