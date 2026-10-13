package com.swp391.eventcraft.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AuthResponse {
    private String token;
    private Integer userId;
    private String email;
    private String fullName;
    private String roleName;
    private String role;
    private String avatarUrl;
}