import { useState } from 'react'
import * as userApi from '../api/user'
import Modal from './Modal'
import { Field, Notice, PasswordInput, PrimaryButton, inputClass } from './ui'

export default function ForgotPasswordModal({ onClose, onSwitchToLogin }) {
  const [step, setStep] = useState(1)
  const [email, setEmail] = useState('')
  const [otp, setOtp] = useState('')
  const [newPassword, setNewPassword] = useState('')
  
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [successMsg, setSuccessMsg] = useState('')

  const handleSendOtp = async (e) => {
    e.preventDefault()
    if (!email) return setError('Vui lòng nhập email')
    setError('')
    setLoading(true)
    try {
      await userApi.forgotPassword({ email })
      setStep(2)
      setSuccessMsg('Mã OTP đã được gửi! Hãy kiểm tra email của bạn.')
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const handleResetPassword = async (e) => {
    e.preventDefault()
    if (!otp || !newPassword) return setError('Vui lòng nhập đầy đủ thông tin')
    if (newPassword.length < 8) return setError('Mật khẩu phải từ 8 ký tự')
    
    setError('')
    setSuccessMsg('')
    setLoading(true)
    try {
      await userApi.resetPassword({ email, otp, newPassword })
      alert('Đổi mật khẩu thành công! Vui lòng đăng nhập lại.')
      onSwitchToLogin(email)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <Modal title="Quên mật khẩu" subtitle="Khôi phục tài khoản của bạn" onClose={onClose}>
      <Notice>{error}</Notice>
      {successMsg && <Notice type="success">{successMsg}</Notice>}

      {step === 1 ? (
        <form onSubmit={handleSendOtp} className="space-y-4 mt-4">
          <Field id="forgot-email" label="Email đăng ký">
            <input
              id="forgot-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className={inputClass()}
              placeholder="ten@gmail.com"
            />
          </Field>
          <PrimaryButton type="submit" loading={loading}>
            Nhận mã OTP
          </PrimaryButton>
        </form>
      ) : (
        <form onSubmit={handleResetPassword} className="space-y-4 mt-4">
          <Field id="forgot-otp" label="Mã OTP (6 số)">
            <input
              id="forgot-otp"
              type="text"
              value={otp}
              onChange={(e) => setOtp(e.target.value)}
              className={inputClass()}
              placeholder="123456"
              maxLength={6}
            />
          </Field>
          <Field id="forgot-newpass" label="Mật khẩu mới">
            <PasswordInput
              id="forgot-newpass"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              placeholder="Nhập mật khẩu mới"
            />
          </Field>
          <PrimaryButton type="submit" loading={loading}>
            Đặt lại mật khẩu
          </PrimaryButton>
        </form>
      )}

      <p className="mt-6 text-center text-sm text-muted">
        Nhớ mật khẩu rồi?{' '}
        <button type="button" onClick={() => onSwitchToLogin()} className="font-semibold text-berry hover:underline">
          Đăng nhập ngay
        </button>
      </p>
    </Modal>
  )
}