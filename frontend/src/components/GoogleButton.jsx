import { useState } from 'react'
import { GoogleLogin } from '@react-oauth/google'
import * as authApi from '../api/auth'
import { useAuth } from '../context/AuthContext'
import { GoogleIcon, SpinnerIcon } from './icons'

const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID

// Đăng nhập nhanh bằng Google.
// - Có VITE_GOOGLE_CLIENT_ID: hiện nút Google thật, lấy credential rồi gửi cho Backend.
// - Không có Client ID: nút demo (chỉ hoạt động khi VITE_USE_MOCK=true).
export default function GoogleButton({ onSuccess, onError }) {
  const { login } = useAuth()
  const [loading, setLoading] = useState(false)

  const finish = async (getData) => {
    setLoading(true)
    try {
      login(await getData())
      onSuccess?.()
    } catch (err) {
      onError?.(err.message)
    } finally {
      setLoading(false)
    }
  }

  if (clientId) {
    return (
      <div className="flex justify-center">
        <GoogleLogin
          onSuccess={(res) => finish(() => authApi.googleLogin(res.credential))}
          onError={() => onError?.('Đăng nhập Google không thành công. Vui lòng thử lại.')}
          text="signin_with"
          shape="pill"
          width="320"
        />
      </div>
    )
  }

  const handleDemoClick = () => {
    if (authApi.USE_MOCK) {
      finish(() => authApi.googleLogin('mock-credential'))
    } else {
      onError?.('Chưa cấu hình VITE_GOOGLE_CLIENT_ID trong file .env nên chưa dùng được Google.')
    }
  }

  return (
    <button
      type="button"
      onClick={handleDemoClick}
      disabled={loading}
      className="flex w-full items-center justify-center gap-2.5 rounded-xl border border-line bg-white px-4 py-3 text-[15px] font-medium transition hover:bg-lilac disabled:opacity-60"
    >
      {loading ? <SpinnerIcon /> : <GoogleIcon />}
      Đăng nhập nhanh bằng Google
    </button>
  )
}
