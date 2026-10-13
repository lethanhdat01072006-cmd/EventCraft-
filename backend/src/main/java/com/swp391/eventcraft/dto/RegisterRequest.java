package com.swp391.eventcraft.dto;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class RegisterRequest {
    private String email;
    private String password;
    private String fullName;
    private String phoneNumber;
    private String roleName; // ROLE_CUSTOMER hoặc ROLE_VENDOR
    private String role;     // Hỗ trợ cả trường "role" từ Frontend (CUSTOMER hoặc VENDOR)

    public String resolveRoleName() {
        if (roleName != null && !roleName.isBlank()) {
            return roleName.startsWith("ROLE_") ? roleName.toUpperCase() : "ROLE_" + roleName.toUpperCase();
        }
        if (role != null && !role.isBlank()) {
            return role.startsWith("ROLE_") ? role.toUpperCase() : "ROLE_" + role.toUpperCase();
        }
        return "ROLE_CUSTOMER";
    }
}
