import { request, sleep } from './client'
import { USE_MOCK, MOCK_OTP } from './auth'
import { TOKEN_KEY } from './client'

const ENDPOINTS = {
  getProfile: '/user/profile',
  updateProfile: '/user/profile',
  changePassword: '/user/change-password',
  forgotPassword: '/auth/forgot-password',
  resetPassword: '/auth/reset-password',
  uploadAvatar: '/user/avatar',
}

export async function getProfile() {
  if (USE_MOCK) {
    await sleep(500)
    return {
      success: true,
      data: {
        fullName: 'Nguyễn Văn A',
        email: 'customer@demo.vn',
        phone: '0901234567',
        role: 'CUSTOMER',
        joinedDate: '2023-01-15T00:00:00.000Z',
        avatar: null
      },
    }
  }
  return request(ENDPOINTS.getProfile, { method: 'GET' })
}

export async function updateProfile({ fullName, phone, phoneNumber }) {
  if (USE_MOCK) {
    await sleep(500)
    return { success: true, message: 'Cập nhật thành công' }
  }
  const effectivePhone = phoneNumber || phone || ''
  return request(ENDPOINTS.updateProfile, { 
    method: 'PUT', 
    body: { fullName, phone: effectivePhone, phoneNumber: effectivePhone } 
  })
}

export async function changePassword({ oldPassword, newPassword, confirmPassword }) {
  if (USE_MOCK) {
    await sleep(500)
    if (oldPassword !== '123456') throw new Error('Mật khẩu cũ không chính xác')
    return { success: true, message: 'Đổi mật khẩu thành công' }
  }
  return request(ENDPOINTS.changePassword, { 
    method: 'POST', 
    body: { oldPassword, newPassword, confirmPassword: confirmPassword || newPassword } 
  })
}

export async function forgotPassword({ email }) {
  if (USE_MOCK) {
    await sleep(500)
    return { success: true, message: 'OTP đã được gửi' }
  }
  return request(ENDPOINTS.forgotPassword, { method: 'POST', body: { email }, auth: false })
}

export async function resetPassword({ email, otp, newPassword }) {
  if (USE_MOCK) {
    await sleep(500)
    if (otp !== MOCK_OTP) throw new Error('Mã OTP không đúng')
    return { success: true, message: 'Đặt lại mật khẩu thành công' }
  }
  return request(ENDPOINTS.resetPassword, { method: 'POST', body: { email, otp, newPassword }, auth: false })
}

export async function uploadAvatar(file) {
  if (USE_MOCK) {
    await sleep(800)
    return { success: true, data: { avatarUrl: URL.createObjectURL(file) } }
  }
  
  const token = localStorage.getItem(TOKEN_KEY)
  const formData = new FormData()
  formData.append('file', file) 
  
  const res = await fetch(`${import.meta.env.VITE_API_BASE || '/api'}${ENDPOINTS.uploadAvatar}`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`
    },
    body: formData
  })
  
  const data = await res.json().catch(() => ({}))
  if (!res.ok || data.success === false) {
    throw new Error(data.message || 'Tải ảnh lên thất bại')
  }
  return data
}