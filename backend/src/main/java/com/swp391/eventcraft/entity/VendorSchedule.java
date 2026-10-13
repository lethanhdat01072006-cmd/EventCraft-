package com.swp391.eventcraft.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "vendor_schedules", uniqueConstraints = {
    @UniqueConstraint(name = "UQ_Vendor_WorkDate", columnNames = {"vendor_id", "work_date"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VendorSchedule {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "schedule_id")
    private Long id;

    @Column(name = "vendor_id", nullable = false)
    private Long vendorId;

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    @Column(name = "is_blackout", nullable = false)
    @Builder.Default
    private Boolean isBlackout = false;

    // Thời điểm hết hạn khóa giữ chỗ 15 phút (Pessimistic Slot Lock)
    @Column(name = "lock_expires_at")
    private LocalDateTime lockExpiresAt;

    @Column(name = "reason")
    private String reason;

    @Column(name = "created_at", nullable = false)
    @Builder.Default
    private LocalDateTime createdAt = LocalDateTime.now();
}
