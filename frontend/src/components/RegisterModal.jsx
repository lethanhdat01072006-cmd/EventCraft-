import { useState } from 'react'
import * as authApi from '../api/auth'
import Modal from './Modal'
import { Field, Notice, PasswordInput, PrimaryButton, inputClass } from './ui'

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

const ROLES = [
  { value: 'CUSTOMER', title: 'Khách hàng', desc: 'Lập kế hoạch và thuê dịch vụ cho sự kiện của bạn.' },
  { value: 'VENDOR', title: 'Nhà cung cấp', desc: 'Đăng gói dịch vụ và nhận đơn từ khách hàng.' },
]

export default function RegisterModal({ onClose, onRegistered, onSwitchToLogin }) {
  const [form, setForm] = useState({ fullName: '', email: '', password: '', confirmPassword: '', role: 'CUSTOMER' })
  const [errors, setErrors] = useState({})
  const [serverError, setServerError] = useState('')
  const [loading, setLoading] = useState(false)

  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: e.target.value }))

  const validate = () => {
    const next = {}
    if (form.fullName.trim().length < 2) next.fullName = 'Nhập họ và tên của bạn.'
    if (!EMAIL_RE.test(form.email.trim())) next.email = 'Nhập email hợp lệ, ví dụ ten@gmail.com.'
    if (form.password.length < 8) next.password = 'Mật khẩu cần ít nhất 8 ký tự.'
    if (form.confirmPassword !== form.password) next.confirmPassword = 'Mật khẩu nhập lại chưa khớp.'
    setErrors(next)
    return Object.keys(next).length === 0
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setServerError('')
    if (!validate()) return
    setLoading(true)
    try {
      const payload = {
        fullName: form.fullName.trim(),
        email: form.email.trim(),
        password: form.password,
        role: form.role,
      }
      await authApi.register(payload)
      onRegistered(payload.email) // chuyển sang bước nhập OTP
    } catch (err) {
      setServerError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <Modal
      title="Tạo tài khoản"
      subtitle="Chúng tôi sẽ gửi mã xác thực 6 số về email của bạn."
      onClose={onClose}
    >
      <form onSubmit={handleSubmit} noValidate className="space-y-4">
        <Notice>{serverError}</Notice>

        <fieldset>
          <legend className="mb-1.5 text-sm font-medium">Bạn tham gia với vai trò</legend>
          <div className="grid gap-2.5 sm:grid-cols-2">
            {ROLES.map((r) => (
              <label
                key={r.value}
                className="flex cursor-pointer flex-col gap-1 rounded-xl border border-line p-3 transition has-[:checked]:border-berry has-[:checked]:bg-berry/5 has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-berry/40"
              >
                <input
                  type="radio"
                  name="role"
                  value={r.value}
                  checked={form.role === r.value}
                  onChange={set('role')}
                  className="sr-only"
                />
                <span className="text-[15px] font-semibold">{r.title}</span>
                <span className="text-[13px] leading-snug text-muted">{r.desc}</span>
              </label>
            ))}
          </div>
        </fieldset>

        <Field id="reg-name" label="Họ và tên" error={errors.fullName}>
          <input
            id="reg-name"
            autoComplete="name"
            placeholder="Nguyễn Văn A"
            value={form.fullName}
            onChange={set('fullName')}
            aria-invalid={Boolean(errors.fullName) || undefined}
            aria-describedby={errors.fullName ? 'reg-name-error' : undefined}
            className={inputClass(errors.fullName)}
          />
        </Field>

        <Field id="reg-email" label="Email" error={errors.email}>
          <input
            id="reg-email"
            type="email"
            autoComplete="email"
            placeholder="ten@gmail.com"
            value={form.email}
            onChange={set('email')}
            aria-invalid={Boolean(errors.email) || undefined}
            aria-describedby={errors.email ? 'reg-email-error' : undefined}
            className={inputClass(errors.email)}
          />
        </Field>

        <Field id="reg-password" label="Mật khẩu" error={errors.password}>
          <PasswordInput
            id="reg-password"
            autoComplete="new-password"
            placeholder="Ít nhất 8 ký tự"
            value={form.password}
            onChange={set('password')}
            invalid={Boolean(errors.password)}
          />
        </Field>

        <Field id="reg-confirm" label="Nhập lại mật khẩu" error={errors.confirmPassword}>
          <PasswordInput
            id="reg-confirm"
            autoComplete="new-password"
            placeholder="Nhập lại mật khẩu"
            value={form.confirmPassword}
            onChange={set('confirmPassword')}
            invalid={Boolean(errors.confirmPassword)}
          />
        </Field>

        <PrimaryButton type="submit" loading={loading}>
          Tạo tài khoản
        </PrimaryButton>
      </form>

      <p className="mt-6 text-center text-sm text-muted">
        Đã có tài khoản?{' '}
        <button type="button" onClick={onSwitchToLogin} className="font-semibold text-berry hover:underline">
          Đăng nhập
        </button>
      </p>
    </Modal>
  )
}
