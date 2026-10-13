package com.swp391.eventcraft.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class UpdateProfileRequest {
    private String fullName;
    @JsonAlias("phone")
    private String phoneNumber;
    private String phone;

    public String getEffectivePhone() {
        if (phoneNumber != null && !phoneNumber.isBlank()) return phoneNumber.trim();
        if (phone != null && !phone.isBlank()) return phone.trim();
        return null;
    }
}
