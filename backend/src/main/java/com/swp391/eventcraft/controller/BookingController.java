package com.swp391.eventcraft.controller;

import com.swp391.eventcraft.dto.ApiResponse;
import com.swp391.eventcraft.dto.HoldSlotRequest;
import com.swp391.eventcraft.dto.HoldSlotResponse;
import com.swp391.eventcraft.service.SlotLockService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/bookings")
@RequiredArgsConstructor
public class BookingController {

    private final SlotLockService slotLockService;

    /**
     * API Giữ chỗ & Khởi tạo đồng hồ đếm ngược 15 phút (UC-C08).
     * POST /api/bookings/hold-slot
     * Body: { vendorIds: [1, 2], eventDate: "2026-11-20", eventTime: "17:30 - 21:00" }
     */
    @PostMapping("/hold-slot")
    public ResponseEntity<?> holdSlot(@RequestBody HoldSlotRequest request) {
        try {
            HoldSlotResponse response = slotLockService.holdSlot(request);
            return ResponseEntity.ok(new ApiResponse(true, response.getMessage(), response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), null));
        }
    }
}
