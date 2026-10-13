package com.swp391.eventcraft.service;

import com.swp391.eventcraft.dto.HoldSlotRequest;
import com.swp391.eventcraft.dto.HoldSlotResponse;
import java.time.LocalDate;

public interface SlotLockService {

    /**
     * Khóa slot giữ chỗ 15 phút cho danh sách nhà cung cấp trong đơn tiệc.
     * Áp dụng thuật toán Pessimistic Slot Lock để chống overbooking.
     */
    HoldSlotResponse holdSlot(HoldSlotRequest request);

    /**
     * Giải phóng slot khi đơn tiệc bị hủy hoặc hết hạn thanh toán.
     */
    void releaseSlot(Long vendorId, LocalDate eventDate);
}
