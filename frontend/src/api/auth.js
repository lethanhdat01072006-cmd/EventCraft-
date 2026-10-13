import { request, sleep } from './client'
import { decodeJwt } from '../utils/jwt'

export const USE_MOCK = import.meta.env.VITE_USE_MOCK === 'true'

/* ------------------------------------------------------------------ *
 *  >>> SỬA Ở ĐÂY cho khớp với AuthController của Backend <<<
 *  Chỉ cần đổi đường dẫn và tên trường trong body ở các hàm bên dưới.
 * ------------------------------------------------------------------ */
const ENDPOINTS = {
  login: '/auth/login',
  googleLogin: '/auth/google',
  register: '/auth/register',
  verifyOtp: '/auth/verify-otp',
  resendOtp: '/auth/resend-otp',
}

/* ---------- Chuẩn hóa dữ liệu Backend trả về ---------- */

function normalizeRole(raw) {
  const value = typeof raw === 'object' && raw !== null ? raw.name : raw
  if (!value) return 'CUSTOMER'
  return String(value).replace(/^ROLE_/i, '').toUpperCase()
}

// Backend có thể trả { token, ... } hoặc { data: { token, user: {...} } }; hàm này chấp nhận cả hai.
export function normalizeAuth(res) {
  const d = res?.data ?? res ?? {}
  const token = d.token ?? d.accessToken ?? d.jwt ?? null
  if (!token) throw new Error('Phản hồi từ máy chủ không có token.')

  const u = d.user ?? d
  const claims = decodeJwt(token) ?? {}
  const email = u.email ?? claims.email ?? claims.sub ?? ''

  return {
    token,
    user: {
      email,
      fullName: u.fullName ?? u.name ?? u.username ?? claims.name ?? email.split('@')[0],
      role: normalizeRole(u.role ?? u.roles?.[0] ?? claims.role ?? claims.roles?.[0]),
      avatar: u.avatar ?? u.avatarUrl ?? u.picture ?? null,
    },
  }
}

/* ---------- Dữ liệu giả (VITE_USE_MOCK=true) ---------- */

export const MOCK_OTP = '123456'

const mockUsers = new Map([
  ['customer@demo.vn', { fullName: 'NamKaka', password: '123456', role: 'CUSTOMER', verified: true }],
  ['vendor@demo.vn', { fullName: 'Datngu', password: '123456', role: 'VENDOR', verified: true }],
])

function makeFakeJwt(payload) {
  const b64 = (obj) => btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const exp = Math.floor(Date.now() / 1000) + 60 * 60 * 24
  return `${b64({ alg: 'none', typ: 'JWT' })}.${b64({ ...payload, exp })}.mock`
}

function mockAuthResponse(email, user) {
  return {
    data: {
      token: makeFakeJwt({ sub: email, role: user.role }),
      user: { email, fullName: user.fullName, role: user.role },
    },
  }
}

/* ---------- Các hàm gọi API ---------- */

export async function login({ email, password }) {
  if (USE_MOCK) {
    await sleep(600)
    const user = mockUsers.get(email.toLowerCase())
    if (!user || user.password !== password) throw new Error('Email hoặc mật khẩu không đúng.')
    if (!user.verified) throw new Error('Tài khoản chưa được xác thực OTP.')
    return normalizeAuth(mockAuthResponse(email.toLowerCase(), user))
  }
  const res = await request(ENDPOINTS.login, { method: 'POST', body: { email, password }, auth: false })
  return normalizeAuth(res)
}

// idToken là chuỗi "credential" do Google trả về sau khi người dùng chọn tài khoản.
export async function googleLogin(idToken) {
  if (USE_MOCK) {
    await sleep(600)
    return normalizeAuth(
      mockAuthResponse('google.user@gmail.com', { fullName: 'Người dùng Google', role: 'CUSTOMER' }),
    )
  }
  const payload = decodeJwt(idToken) || {}
  const body = {
    email: payload.email,
    fullName: payload.name || payload.given_name || 'Người dùng Google',
    avatarUrl: payload.picture || '',
    idToken,
  }
  const res = await request(ENDPOINTS.googleLogin, { method: 'POST', body, auth: false })
  return normalizeAuth(res)
}

// role: 'CUSTOMER' (Khách hàng) hoặc 'VENDOR' (Nhà cung cấp)
export async function register({ fullName, email, password, role }) {
  if (USE_MOCK) {
    await sleep(700)
    if (mockUsers.has(email.toLowerCase())) throw new Error('Email này đã được đăng ký.')
    mockUsers.set(email.toLowerCase(), { fullName, password, role, verified: false })
    return null
  }
  return request(ENDPOINTS.register, { method: 'POST', body: { fullName, email, password, role }, auth: false })
}

// Trả về dữ liệu đăng nhập nếu Backend cấp token ngay sau khi xác thực, ngược lại trả về null.
export async function verifyOtp({ email, otp }) {
  if (USE_MOCK) {
    await sleep(600)
    if (otp !== MOCK_OTP) throw new Error('Mã OTP không đúng. Vui lòng kiểm tra lại.')
    const user = mockUsers.get(email.toLowerCase())
    if (user) user.verified = true
    return null
  }
  const res = await request(ENDPOINTS.verifyOtp, { method: 'POST', body: { email, otp }, auth: false })
  const d = res?.data ?? res ?? {}
  const hasToken = Boolean(d.token ?? d.accessToken ?? d.jwt)
  return hasToken ? normalizeAuth(res) : null
}

export async function resendOtp({ email }) {
  if (USE_MOCK) {
    await sleep(500)
    return null
  }
  return request(ENDPOINTS.resendOtp, { method: 'POST', body: { email }, auth: false })
}
