const ROLES = {
  CUSTOMER: { label: 'Khách hàng', className: 'bg-lilac text-ink' },
  VENDOR: { label: 'Nhà cung cấp', className: 'bg-marigold/30 text-ink' },
  ADMIN: { label: 'Quản trị viên', className: 'bg-ink text-white' },
}

export default function RoleBadge({ role }) {
  const info = ROLES[role] ?? { label: role, className: 'bg-lilac text-ink' }
  return (
    <span className={`inline-block whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-medium ${info.className}`}>
      {info.label}
    </span>
  )
}
