export const TOKEN_KEY = 'ec_token'
export const USER_KEY = 'ec_user'

const BASE = import.meta.env.VITE_API_BASE || '/api'

export const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

// Hàm gọi API dùng chung: tự gắn JWT vào header Authorization và ném lỗi có thông báo tiếng Việt.
export async function request(path, { method = 'GET', body, auth = true } = {}) {
  const headers = { 'Content-Type': 'application/json' }
  if (auth) {
    const token = localStorage.getItem(TOKEN_KEY)
    if (token) headers.Authorization = `Bearer ${token}`
  }

  let res
  try {
    res = await fetch(`${BASE}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    })
  } catch {
    throw new Error('Không kết nối được máy chủ. Hãy kiểm tra Backend đã chạy chưa.')
  }

  let data = null
  try {
    data = await res.json()
  } catch {
    // phản hồi không có nội dung JSON
  }

  if (!res.ok || data?.success === false) {
    throw new Error(data?.message || data?.error || `Yêu cầu thất bại (mã ${res.status}).`)
  }
  return data
}
