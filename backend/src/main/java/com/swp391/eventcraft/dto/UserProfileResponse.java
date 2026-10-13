package com.swp391.eventcraft.dto;

import lombok.*;
import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserProfileResponse {
    private Integer userId;
    private String email;
    private String fullName;
    private String phoneNumber;
    private String avatarUrl;
    private String roleName;
    private Boolean emailVerified;
    private LocalDateTime createdAt;
}
