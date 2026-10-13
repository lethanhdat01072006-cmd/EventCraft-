package com.swp391.eventcraft.controller;

import com.swp391.eventcraft.dto.*;
import com.swp391.eventcraft.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.security.Principal;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    // API 1: Xem thông tin hồ sơ cá nhân
    @GetMapping("/profile")
    public ResponseEntity<?> getProfile(Principal principal) {
        try {
            if (principal == null) {
                return ResponseEntity.status(401).body(new ApiResponse(false, "Vui lòng đăng nhập để thực hiện thao tác này!", null));
            }
            UserProfileResponse response = userService.getProfile(principal.getName());
            return ResponseEntity.ok(new ApiResponse(true, "Lấy thông tin hồ sơ thành công!", response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), null));
        }
    }

    // API 2: Cập nhật thông tin hồ sơ cá nhân
    @PutMapping("/profile")
    public ResponseEntity<?> updateProfile(Principal principal, @RequestBody UpdateProfileRequest request) {
        try {
            if (principal == null) {
                return ResponseEntity.status(401).body(new ApiResponse(false, "Vui lòng đăng nhập để thực hiện thao tác này!", null));
            }
            UserProfileResponse response = userService.updateProfile(principal.getName(), request);
            return ResponseEntity.ok(new ApiResponse(true, "Cập nhật hồ sơ thành công!", response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), null));
        }
    }

    // API 3: Đổi mật khẩu tài khoản
    @PostMapping("/change-password")
    public ResponseEntity<?> changePassword(Principal principal, @RequestBody ChangePasswordRequest request) {
        try {
            if (principal == null) {
                return ResponseEntity.status(401).body(new ApiResponse(false, "Vui lòng đăng nhập để thực hiện thao tác này!", null));
            }
            userService.changePassword(principal.getName(), request);
            return ResponseEntity.ok(new ApiResponse(true, "Đổi mật khẩu thành công!", null));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), null));
        }
    }

    // API 4: Tải lên và thay đổi ảnh đại diện (Avatar)
    @PostMapping(value = "/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> uploadAvatar(Principal principal, @RequestParam("file") MultipartFile file) {
        try {
            if (principal == null) {
                return ResponseEntity.status(401).body(new ApiResponse(false, "Vui lòng đăng nhập để thực hiện thao tác này!", null));
            }
            String avatarUrl = userService.uploadAvatar(principal.getName(), file);
            return ResponseEntity.ok(new ApiResponse(true, "Cập nhật ảnh đại diện thành công!", avatarUrl));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), null));
        }
    }
}
