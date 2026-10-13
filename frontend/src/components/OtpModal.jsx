import { useEffect, useRef, useState } from 'react'
import * as authApi from '../api/auth'
import Modal from './Modal'
import { Notice, PrimaryButton } from './ui'

const LENGTH = 6
const EXPIRE_SECONDS = 5 * 60 // mã có hiệu lực 5 phút
const RESEND_COOLDOWN = 60 // chờ 60 giây mới được gửi lại

const formatTime = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`

export default function OtpModal({ email, onClose, onVerified, onBack }) {
  const [digits, setDigits] = useState(Array(LENGTH).fill(''))
  const [secondsLeft, setSecondsLeft] = useState(EXPIRE_SECONDS)
  const [cooldown, setCooldown] = useState(RESEND_COOLDOWN)
  const [loading, setLoading] = useState(false)
  const [resending, setResending] = useState(false)
  const [status, setStatus] = useState(null) // { type: 'error' | 'success', text }
  const inputs = useRef([])

  // đồng hồ đếm ngược, mỗi giây giảm 1
  useEffect(() => {
    const timer = setInterval(() => {
      setSecondsLeft((s) => Math.max(0, s - 1))
      setCooldown((c) => Math.max(0, c - 1))
    }, 1000)
    return () => clearInterval(timer)
  }, [])

  const code = digits.join('')
  const expired = secondsLeft === 0
  const canSubmit = code.length === LENGTH && !expired && !loading

  const focusBox = (i) => inputs.current[Math.min(Math.max(i, 0), LENGTH - 1)]?.focus()

  // điền nhiều số cùng lúc (dán mã hoặc trình duyệt tự điền) bắt đầu từ ô start
  const fillFrom = (start, text) => {
    const chars = text.replace(/\D/g, '').slice(0, LENGTH - start).split('')
    if (chars.length === 0) return
    setDigits((prev) => {
      const next = [...prev]
      chars.forEach((c, k) => (next[start + k] = c))
      return next
    })
    focusBox(start + chars.length)
  }

  const handleChange = (i, value) => {
    setStatus(null)
    const clean = value.replace(/\D/g, '')
    if (clean.length > 1) return fillFrom(i, clean)
    setDigits((prev) => prev.map((d, idx) => (idx === i ? clean : d)))
    if (clean) focusBox(i + 1)
  }

  const handleKeyDown = (i, e) => {
    if (e.key === 'Backspace' && !digits[i]) {
      e.preventDefault()
      setDigits((prev) => prev.map((d, idx) => (idx === i - 1 ? '' : d)))
      focusBox(i - 1)
    } else if (e.key === 'ArrowLeft') {
      focusBox(i - 1)
    } else if (e.key === 'ArrowRight') {
      focusBox(i + 1)
    }
  }

  const handlePaste = (e) => {
    e.preventDefault()
    setStatus(null)
    fillFrom(0, e.clipboardData.getData('text'))
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!canSubmit) return
    setLoading(true)
    setStatus(null)
    try {
      const auth = await authApi.verifyOtp({ email, otp: code })
      onVerified(auth)
    } catch (err) {
      setStatus({ type: 'error', text: err.message })
      setDigits(Array(LENGTH).fill(''))
      focusBox(0)
    } finally {
      setLoading(false)
    }
  }

  const handleResend = async () => {
    setResending(true)
    setStatus(null)
    try {
      await authApi.resendOtp({ email })
      setSecondsLeft(EXPIRE_SECONDS)
      setCooldown(RESEND_COOLDOWN)
      setDigits(Array(LENGTH).fill(''))
      setStatus({ type: 'success', text: 'Đã gửi mã mới. Hãy kiểm tra hộp thư của bạn.' })
      focusBox(0)
    } catch (err) {
      setStatus({ type: 'error', text: err.message })
    } finally {
      setResending(false)
    }
  }

  return (
    <Modal
      title="Nhập mã xác thực"
      subtitle={
        <>
          Mã 6 số đã được gửi tới <b className="break-all text-ink">{email}</b>.
        </>
      }
      onClose={onClose}
    >
      <form onSubmit={handleSubmit} className="space-y-5">
        <div className="flex justify-between gap-2" onPaste={handlePaste} role="group" aria-label="Mã OTP 6 số">
          {digits.map((d, i) => (
            <input
              key={i}
              ref={(el) => (inputs.current[i] = el)}
              value={d}
              onChange={(e) => handleChange(i, e.target.value)}
              onKeyDown={(e) => handleKeyDown(i, e)}
              onFocus={(e) => e.target.select()}
              inputMode="numeric"
              autoComplete={i === 0 ? 'one-time-code' : 'off'}
              aria-label={`Số thứ ${i + 1}`}
              disabled={expired}
              className="h-14 w-full min-w-0 rounded-xl border border-line bg-white text-center font-display text-2xl font-bold outline-none transition focus:border-berry focus:ring-2 focus:ring-berry/25 disabled:bg-lilac disabled:text-muted"
            />
          ))}
        </div>

        <p
          className={`text-center text-sm ${expired ? 'font-medium text-red-600' : secondsLeft <= 60 ? 'text-berry' : 'text-muted'}`}
          aria-live="polite"
        >
          {expired ? (
            'Mã đã hết hạn. Bấm "Gửi lại mã" để nhận mã mới.'
          ) : (
            <>
              Mã hết hạn sau <b className="tabular-nums">{formatTime(secondsLeft)}</b>
            </>
          )}
        </p>

        {status && <Notice type={status.type}>{status.text}</Notice>}

        <PrimaryButton type="submit" loading={loading} disabled={!canSubmit}>
          Xác thực
        </PrimaryButton>
      </form>

      {authApi.USE_MOCK && (
        <p className="mt-4 rounded-xl bg-lilac px-3.5 py-2.5 text-sm text-muted">
          Chế độ demo: mã OTP là <b className="text-ink">{authApi.MOCK_OTP}</b>.
        </p>
      )}

      <div className="mt-5 flex items-center justify-between text-sm">
        <button type="button" onClick={onBack} className="text-muted hover:text-ink hover:underline">
          Đổi email
        </button>
        <button
          type="button"
          onClick={handleResend}
          disabled={cooldown > 0 || resending}
          className="font-semibold text-berry hover:underline disabled:cursor-not-allowed disabled:text-muted disabled:no-underline"
        >
          {resending ? 'Đang gửi…' : cooldown > 0 ? `Gửi lại mã sau ${cooldown}s` : 'Gửi lại mã'}
        </button>
      </div>
    </Modal>
  )
}
