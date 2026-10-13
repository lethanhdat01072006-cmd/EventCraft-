package com.swp391.eventcraft.exception;

public class SlotAlreadyLockedException extends RuntimeException {
    public SlotAlreadyLockedException(String message) {
        super(message);
    }

    public SlotAlreadyLockedException(Long vendorId, String date) {
        super("Nhà cung cấp #" + vendorId + " vào ngày " + date + " đã có người đặt hoặc đang trong 15 phút giữ chỗ. Vui lòng chọn ngày hoặc đối tác khác!");
    }
}
