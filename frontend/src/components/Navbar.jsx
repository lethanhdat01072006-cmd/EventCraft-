import { Link, NavLink } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { LogoutIcon, SparkIcon } from './icons'
import RoleBadge from './RoleBadge'

const NAV_LINKS = [
  { to: '/', label: 'Trang chủ', end: true },
  { to: '/services', label: 'Dịch vụ' },
  { to: '/workspace', label: 'Workspace' },
  { to: '/profile', label: 'Hồ sơ' },
]

const navLinkClass = ({ isActive }) =>
  `rounded-xl px-3 py-2 text-sm font-medium transition ${
    isActive ? 'bg-lilac font-semibold text-ink' : 'text-ink/70 hover:bg-lilac hover:text-ink'
  }`

function initials(name = '') {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return '?'
  if (parts.length === 1) return parts[0][0].toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}

function Avatar({ user }) {
  const avatarUrl = user?.avatar
    ? user.avatar.replace(/^http:\/\/localhost:(8080|8081)\/uploads\//, '/uploads/')
    : null
  if (avatarUrl) {
    return <img src={avatarUrl} alt="" referrerPolicy="no-referrer" className="h-9 w-9 rounded-full object-cover" />
  }
  return (
    <span
      aria-hidden="true"
      className="grid h-9 w-9 place-items-center rounded-full bg-ink text-sm font-semibold text-marigold"
    >
      {initials(user.fullName)}
    </span>
  )
}

export default function Navbar({ onLogin, onRegister, onViewProfile, onGoHome }) {
  const { user, logout } = useAuth()

  return (
    <header className="sticky top-0 z-30 border-b border-line bg-paper/85 backdrop-blur">
      <nav className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-4 px-4 sm:px-6" aria-label="Điều hướng chính">
        <div className="flex items-center gap-6">
          <Link to="/" className="flex items-center gap-2.5 font-display text-xl font-bold tracking-tight">
            <span className="grid h-8 w-8 place-items-center rounded-lg bg-ink text-marigold">
              <SparkIcon width={18} height={18} />
            </span>
            EventCraft
          </Link>

          <div className="hidden items-center gap-1 md:flex">
            {NAV_LINKS.map((l) => (
              <NavLink key={l.to} to={l.to} end={l.end} className={navLinkClass}>
                {l.label}
              </NavLink>
            ))}
          </div>
        </div>

        {user ? (
          <div className="flex items-center gap-2.5 sm:gap-3">
            {/* Gói Avatar và Tên vào một nút bấm để mở Profile */}
            <button type="button" onClick={onViewProfile} className="flex items-center gap-2.5 sm:gap-3 text-left hover:opacity-75 transition">
              <Avatar user={user} />
              <div className="flex flex-col items-start gap-0.5 leading-tight">
                <span className="hidden max-w-40 truncate text-sm font-semibold sm:block">{user.fullName}</span>
                <RoleBadge role={user.role} />
              </div>
            </button>

            <button
              type="button"
              onClick={() => {
                logout()
                if (onGoHome) onGoHome() // Đăng xuất xong về trang chủ
              }}
              className="ml-1 flex items-center gap-1.5 rounded-xl border border-line bg-white px-2.5 py-2 text-sm font-medium transition hover:bg-lilac sm:px-3.5"
              aria-label="Đăng xuất"
            >
              <LogoutIcon width={18} height={18} />
              <span className="hidden sm:inline">Đăng xuất</span>
            </button>
          </div>
        ) : (
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={onLogin}
              className="rounded-xl px-3.5 py-2 text-sm font-semibold transition hover:bg-lilac"
            >
              Đăng nhập
            </button>
            <button
              type="button"
              onClick={onRegister}
              className="rounded-xl bg-berry px-3.5 py-2 text-sm font-semibold text-white transition hover:bg-berry-dark"
            >
              Đăng ký
            </button>
          </div>
        )}
      </nav>

      {/* Màn hình nhỏ: hàng link nằm dưới thanh chính, cuộn ngang nếu thiếu chỗ */}
      <div className="flex gap-1 overflow-x-auto border-t border-line px-4 py-1.5 md:hidden">
        {NAV_LINKS.map((l) => (
          <NavLink key={l.to} to={l.to} end={l.end} className={navLinkClass}>
            {l.label}
          </NavLink>
        ))}
      </div>
    </header>
  )
}