package com.swp391.eventcraft.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class GoogleLoginRequest {
    private String email;
    private String fullName;
    private String avatarUrl;
    private String idToken;
}