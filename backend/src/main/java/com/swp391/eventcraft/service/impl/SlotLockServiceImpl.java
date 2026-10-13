package com.swp391.eventcraft.service.impl;

import com.swp391.eventcraft.dto.HoldSlotRequest;
import com.swp391.eventcraft.dto.HoldSlotResponse;
import com.swp391.eventcraft.entity.VendorSchedule;
import com.swp391.eventcraft.exception.SlotAlreadyLockedException;
import com.swp391.eventcraft.repository.VendorScheduleRepository;
import com.swp391.eventcraft.service.SlotLockService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class SlotLockServiceImpl implements SlotLockService {

    private final VendorScheduleRepository scheduleRepository;

    @Override
    @Transactional
    public HoldSlotResponse holdSlot(HoldSlotRequest request) {
        if (request.getEventDate() == null) {
            throw new IllegalArgumentException("Ngày tổ chức sự kiện không được để trống!");
        }

        if (request.getEventDate().isBefore(LocalDate.now())) {
            throw new IllegalArgumentException("Ngày tổ chức sự kiện không thể là ngày trong quá khứ!");
        }

        // Gom danh sách vendor cần khóa (từ vendorIds hoặc serviceIds)
        List<Long> targetVendorIds = new ArrayList<>();
        if (request.getVendorIds() != null && !request.getVendorIds().isEmpty()) {
            targetVendorIds.addAll(request.getVendorIds());
        } else if (request.getServiceIds() != null && !request.getServiceIds().isEmpty()) {
            // Mặc định mapping 1-1 serviceId sang vendorId nếu chưa truyền vendorId trực tiếp
            targetVendorIds.addAll(request.getServiceIds());
        } else {
            throw new IllegalArgumentException("Vui lòng chọn ít nhất một dịch vụ hoặc nhà cung cấp để giữ chỗ!");
        }

        LocalDateTime lockExpiration = LocalDateTime.now().plusMinutes(15);
        List<Long> successfullyLocked = new ArrayList<>();

        // Khóa nguyên tử từng Vendor trong đơn tiệc
        for (Long vendorId : targetVendorIds) {
            Optional<VendorSchedule> scheduleOpt = scheduleRepository.findByVendorIdAndWorkDate(vendorId, request.getEventDate());

            if (scheduleOpt.isEmpty()) {
                // Trường hợp 1: Vendor chưa có lịch cho ngày này -> Tạo mới và khóa ngay 15 phút
                VendorSchedule newSchedule = VendorSchedule.builder()
                        .vendorId(vendorId)
                        .workDate(request.getEventDate())
                        .isBlackout(false)
                        .lockExpiresAt(lockExpiration)
                        .reason("Khách hàng đang giữ chỗ 15 phút để hoàn tất ký hợp đồng")
                        .createdAt(LocalDateTime.now())
                        .build();
                scheduleRepository.save(newSchedule);
                successfullyLocked.add(vendorId);
            } else {
                VendorSchedule schedule = scheduleOpt.get();

                // Trường hợp 2: Vendor đã đánh dấu ngày nghỉ (Blackout)
                if (Boolean.TRUE.equals(schedule.getIsBlackout())) {
                    throw new SlotAlreadyLockedException("Nhà cung cấp #" + vendorId + " đã đánh dấu ngày nghỉ vào ngày " + request.getEventDate() + "!");
                }

                // Trường hợp 3: Thực hiện câu lệnh SQL nguyên tử (Pessimistic Slot Lock)
                int rowsUpdated = scheduleRepository.lockSlotAtomic(vendorId, request.getEventDate());
                if (rowsUpdated == 0) {
                    // Trùng lịch hoặc đang có người khác giữ chỗ trong 15 phút
                    log.warn("[SLOT LOCK] Thất bại khi khóa slot Vendor #{} ngày {}", vendorId, request.getEventDate());
                    throw new SlotAlreadyLockedException(vendorId, request.getEventDate().toString());
                }

                successfullyLocked.add(vendorId);
            }
        }

        log.info("[SLOT LOCK] Khóa thành công {} nhà cung cấp đến {}", successfullyLocked.size(), lockExpiration);

        return HoldSlotResponse.builder()
                .success(true)
                .message("Giữ chỗ thành công! Bạn có 15 phút để hoàn tất ký hợp đồng và thanh toán cọc.")
                .holdExpiresAt(lockExpiration)
                .remainingSeconds(15L * 60L) // 900 giây
                .lockedVendorIds(successfullyLocked)
                .build();
    }

    @Override
    @Transactional
    public void releaseSlot(Long vendorId, LocalDate eventDate) {
        scheduleRepository.unlockSlotAtomic(vendorId, eventDate);
        log.info("[SLOT UNLOCK] Đã giải phóng slot Vendor #{} ngày {}", vendorId, eventDate);
    }
}
