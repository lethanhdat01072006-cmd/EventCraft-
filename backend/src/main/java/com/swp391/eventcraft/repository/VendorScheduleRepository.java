package com.swp391.eventcraft.repository;

import com.swp391.eventcraft.entity.VendorSchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Optional;

@Repository
public interface VendorScheduleRepository extends JpaRepository<VendorSchedule, Long> {

    Optional<VendorSchedule> findByVendorIdAndWorkDate(Long vendorId, LocalDate workDate);

    /**
     * Thuật toán Khóa slot 15 phút nguyên tử (Pessimistic Slot Lock - UC-C08).
     * Chỉ gia hạn thành công nếu:
     * 1. Đối tác không đặt ngày nghỉ (is_blackout = 0)
     * 2. Chưa có ai khóa hoặc khóa cũ đã hết hạn (lock_expires_at IS NULL OR lock_expires_at < GETDATE())
     *
     * @return Số dòng được cập nhật (1 = Khóa thành công; 0 = Trùng lịch/Đang bị người khác giữ chỗ)
     */
    @Modifying
    @Query(value = "UPDATE vendor_schedules " +
                   "SET lock_expires_at = DATEADD(minute, 15, GETDATE()) " +
                   "WHERE vendor_id = :vendorId AND work_date = :workDate " +
                   " AND is_blackout = 0 " +
                   " AND (lock_expires_at IS NULL OR lock_expires_at < GETDATE())",
           nativeQuery = true)
    int lockSlotAtomic(@Param("vendorId") Long vendorId, @Param("workDate") LocalDate workDate);

    /**
     * Giải phóng slot khóa khi đơn tiệc bị hủy hoặc khách từ chối thanh toán.
     */
    @Modifying
    @Query(value = "UPDATE vendor_schedules " +
                   "SET lock_expires_at = NULL " +
                   "WHERE vendor_id = :vendorId AND work_date = :workDate",
           nativeQuery = true)
    int unlockSlotAtomic(@Param("vendorId") Long vendorId, @Param("workDate") LocalDate workDate);
}
