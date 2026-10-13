import { useState } from 'react'
import * as authApi from '../api/auth'
import { useAuth } from '../context/AuthContext'
import GoogleButton from './GoogleButton'
import Modal from './Modal'
import { Divider, Field, Notice, PasswordInput, PrimaryButton, inputClass } from './ui'

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

// Thêm prop onOpenForgot
export default function LoginModal({ notice, defaultEmail = '', onClose, onSwitchToRegister, onOpenForgot }) {
  const { login } = useAuth()
  const [email, setEmail] = useState(defaultEmail)
  const [password, setPassword] = useState('')
  const [errors, setErrors] = useState({})
  const [serverError, setServerError] = useState('')
  const [loading, setLoading] = useState(false)

  const validate = () => {
    const next = {}
    if (!EMAIL_RE.test(email.trim())) next.email = 'Nhập email hợp lệ, ví dụ ten@gmail.com.'
    if (!password) next.password = 'Nhập mật khẩu của bạn.'
    setErrors(next)
    return Object.keys(next).length === 0
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setServerError('')
    if (!validate()) return
    setLoading(true)
    try {
      const data = await authApi.login({ email: email.trim(), password })
      login(data) 
      onClose()
    } catch (err) {
      setServerError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <Modal title="Đăng nhập" subtitle="Chào mừng bạn quay lại EventCraft." onClose={onClose}>
      <form onSubmit={handleSubmit} noValidate className="space-y-4">
        {notice && <Notice type="success">{notice}</Notice>}
        <Notice>{serverError}</Notice>

        <Field id="login-email" label="Email" error={errors.email}>
          <input
            id="login-email"
            type="email"
            autoComplete="email"
            placeholder="ten@gmail.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            aria-invalid={Boolean(errors.email) || undefined}
            aria-describedby={errors.email ? 'login-email-error' : undefined}
            className={inputClass(errors.email)}
          />
        </Field>

        <Field id="login-password" label="Mật khẩu" error={errors.password}>
          <PasswordInput
            id="login-password"
            autoComplete="current-password"
            placeholder="Nhập mật khẩu"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            invalid={Boolean(errors.password)}
          />
        </Field>

        {/* Nút bấm để gọi hàm Quên mật khẩu */}
        <div className="flex justify-end">
          <button type="button" onClick={onOpenForgot} className="text-sm font-semibold text-berry hover:underline">
            Quên mật khẩu?
          </button>
        </div>

        <PrimaryButton type="submit" loading={loading}>
          Đăng nhập
        </PrimaryButton>
      </form>

      <div className="mt-5 space-y-4">
        <Divider>hoặc</Divider>
        <GoogleButton onSuccess={onClose} onError={setServerError} />
      </div>

      {authApi.USE_MOCK && (
        <p className="mt-5 rounded-xl bg-lilac px-3.5 py-2.5 text-sm text-muted">
          Chế độ demo: đăng nhập bằng <b className="text-ink">customer@demo.vn</b> hoặc{' '}
          <b className="text-ink">vendor@demo.vn</b>, mật khẩu <b className="text-ink">123456</b>.
        </p>
      )}

      <p className="mt-6 text-center text-sm text-muted">
        Chưa có tài khoản?{' '}
        <button type="button" onClick={onSwitchToRegister} className="font-semibold text-berry hover:underline">
          Đăng ký
        </button>
      </p>
    </Modal>
  )
}