import { useEffect, useRef } from 'react'
import { CloseIcon } from './icons'

export default function Modal({ title, subtitle, onClose, children }) {
  const panelRef = useRef(null)
  const onCloseRef = useRef(onClose)
  onCloseRef.current = onClose

  useEffect(() => {
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'

    const onKeyDown = (e) => {
      if (e.key === 'Escape') onCloseRef.current?.()
    }
    window.addEventListener('keydown', onKeyDown)

    // đưa con trỏ vào ô nhập đầu tiên
    panelRef.current?.querySelector('input')?.focus()

    return () => {
      document.body.style.overflow = previousOverflow
      window.removeEventListener('keydown', onKeyDown)
    }
  }, [])

  return (
    <div
      className="modal-overlay fixed inset-0 z-50 grid place-items-center overflow-y-auto bg-ink/50 p-4 backdrop-blur-sm"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose?.()
      }}
    >
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-title"
        className="modal-panel relative my-auto w-full max-w-md rounded-3xl bg-white p-6 shadow-2xl shadow-ink/20 sm:p-8"
      >
        <button
          type="button"
          onClick={onClose}
          aria-label="Đóng"
          className="absolute right-4 top-4 grid h-9 w-9 place-items-center rounded-full text-muted transition hover:bg-lilac hover:text-ink"
        >
          <CloseIcon />
        </button>

        <h2 id="modal-title" className="pr-8 font-display text-2xl font-bold tracking-tight">
          {title}
        </h2>
        {subtitle && <p className="mt-1.5 text-[15px] leading-relaxed text-muted">{subtitle}</p>}

        <div className="mt-6">{children}</div>
      </div>
    </div>
  )
}
