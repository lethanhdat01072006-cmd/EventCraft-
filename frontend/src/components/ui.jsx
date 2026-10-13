import { useState } from 'react'
import { AlertIcon, CheckIcon, EyeIcon, EyeOffIcon, SpinnerIcon } from './icons'

export const inputClass = (invalid) =>
  [
    'w-full rounded-xl border bg-white px-3.5 py-2.5 text-[15px] text-ink outline-none transition',
    'placeholder:text-muted/60 focus:ring-2',
    invalid
      ? 'border-red-500 focus:border-red-500 focus:ring-red-500/25'
      : 'border-line focus:border-berry focus:ring-berry/25',
  ].join(' ')

export function Field({ id, label, error, children }) {
  return (
    <div>
      <label htmlFor={id} className="mb-1.5 block text-sm font-medium">
        {label}
      </label>
      {children}
      {error && (
        <p id={`${id}-error`} className="mt-1.5 text-sm text-red-600">
          {error}
        </p>
      )}
    </div>
  )
}

export function PasswordInput({ id, value, onChange, invalid, autoComplete, placeholder }) {
  const [show, setShow] = useState(false)
  return (
    <div className="relative">
      <input
        id={id}
        type={show ? 'text' : 'password'}
        value={value}
        onChange={onChange}
        autoComplete={autoComplete}
        placeholder={placeholder}
        aria-invalid={invalid || undefined}
        aria-describedby={invalid ? `${id}-error` : undefined}
        className={`${inputClass(invalid)} pr-11`}
      />
      <button
        type="button"
        onClick={() => setShow((s) => !s)}
        aria-label={show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
        aria-pressed={show}
        className="absolute inset-y-0 right-0 grid w-11 place-items-center rounded-r-xl text-muted hover:text-ink"
      >
        {show ? <EyeOffIcon /> : <EyeIcon />}
      </button>
    </div>
  )
}

export function PrimaryButton({ loading, children, className = '', ...props }) {
  return (
    <button
      {...props}
      disabled={loading || props.disabled}
      className={`flex w-full items-center justify-center gap-2 rounded-xl bg-berry px-4 py-3 text-[15px] font-semibold text-white transition hover:bg-berry-dark disabled:cursor-not-allowed disabled:opacity-60 ${className}`}
    >
      {loading && <SpinnerIcon />}
      {children}
    </button>
  )
}

export function Notice({ type = 'error', children }) {
  if (!children) return null
  const isError = type === 'error'
  return (
    <div
      role={isError ? 'alert' : 'status'}
      className={`flex items-start gap-2 rounded-xl px-3.5 py-2.5 text-sm ${
        isError ? 'bg-red-50 text-red-700' : 'bg-emerald-50 text-emerald-800'
      }`}
    >
      <span className="mt-0.5 shrink-0">{isError ? <AlertIcon width={16} height={16} /> : <CheckIcon width={16} height={16} />}</span>
      <span>{children}</span>
    </div>
  )
}

export function Divider({ children }) {
  return (
    <div className="flex items-center gap-3 text-sm text-muted">
      <span className="h-px flex-1 bg-line" />
      {children}
      <span className="h-px flex-1 bg-line" />
    </div>
  )
}
