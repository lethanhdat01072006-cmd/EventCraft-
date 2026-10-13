package com.swp391.eventcraft.dto;

import lombok.*;
import java.time.LocalDateTime;
import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HoldSlotResponse {
    private Boolean success;
    private String message;
    
    // Mốc thời gian hết hạn giữ chỗ (đồng hồ đếm ngược 15 phút cho client)
    private LocalDateTime holdExpiresAt;
    
    // Số giây còn lại cho đồng hồ đếm ngược client (900 giây)
    private Long remainingSeconds;
    
    // Danh sách các Vendor ID đã được khóa thành công
    private List<Long> lockedVendorIds;
}
