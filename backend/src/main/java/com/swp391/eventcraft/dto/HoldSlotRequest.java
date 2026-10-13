package com.swp391.eventcraft.dto;

import lombok.*;
import java.time.LocalDate;
import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HoldSlotRequest {
    // Danh sách mã gói dịch vụ hoặc mã nhà cung cấp cần giữ chỗ
    private List<Long> serviceIds;
    private List<Long> vendorIds;
    
    // Ngày tổ chức tiệc
    private LocalDate eventDate;
    
    // Khung giờ tổ chức (ví dụ: '17:30 - 21:00')
    private String eventTime;
}
