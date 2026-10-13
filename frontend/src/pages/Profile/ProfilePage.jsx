import { useEffect, useState } from 'react'
import * as userApi from '../../api/user'
import { useAuth } from '../../context/AuthContext'
import { Field, Notice, PasswordInput, PrimaryButton, inputClass } from '../../components/ui'
import RoleBadge from '../../components/RoleBadge'

function normalizeAvatarUrl(url) {
  if (!url) return null
  if (url.startsWith('http://localhost:8080/uploads/')) {
    return url.replace('http://localhost:8080/uploads/', '/uploads/')
  }
  if (url.startsWith('http://localhost:8081/uploads/')) {
    return url.replace('http://localhost:8081/uploads/', '/uploads/')
  }
  return url
}

export default function ProfilePage() {
  const { updateSessionUser } = useAuth()
  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)
  
  // States: Sửa thông tin
  const [editName, setEditName] = useState('')
  const [editPhone, setEditPhone] = useState('')
  const [isSavingProfile, setIsSavingProfile] = useState(false)
  const [profileMsg, setProfileMsg] = useState({ type: '', text: '' })

  // States: Đổi mật khẩu
  const [oldPassword, setOldPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [isSavingPass, setIsSavingPass] = useState(false)
  const [passMsg, setPassMsg] = useState({ type: '', text: '' })

  // Lấy dữ liệu lúc mới vào trang
  useEffect(() => {
    userApi.getProfile()
      .then((res) => {
        const data = res.data ?? res
        setProfile(data)
        setEditName(data.fullName || '')
        setEditPhone(data.phoneNumber || data.phone || '')
        
        // Ép Navbar trên cùng cập nhật ảnh và tên theo dữ liệu mới nhất (đề phòng lúc F5)
        const av = normalizeAvatarUrl(data.avatarUrl || data.avatar)
        if (updateSessionUser) {
          updateSessionUser({ fullName: data.fullName, avatar: av })
        }
      })
      .catch((err) => console.error(err))
      .finally(() => setLoading(false))
  }, [updateSessionUser])

  // Đổi Avatar (Tính năng Instant Preview chớp nhoáng)
  const handleAvatarChange = async (e) => {
    const file = e.target.files[0]
    if (!file) return

    // TÍNH NĂNG 1 & 3: Tự động thay đổi ảnh ngay lập tức (Instant Preview)
    const previewUrl = URL.createObjectURL(file)
    setProfile(p => ({ ...p, avatarUrl: previewUrl }))
    
    // TÍNH NĂNG 2: Đồng bộ ngay lập tức lên thanh Navbar
    if (updateSessionUser) updateSessionUser({ avatar: previewUrl })

    // Gửi ngầm file ảnh lên Backend
    try {
      const res = await userApi.uploadAvatar(file)
      const serverAvatar = normalizeAvatarUrl(res.data?.avatarUrl || res.data || previewUrl)
      setProfile(p => ({ ...p, avatarUrl: serverAvatar }))
      if (updateSessionUser) updateSessionUser({ avatar: serverAvatar })
    } catch (error) {
      console.log("Lỗi gửi ảnh lên Backend: ", error.message)
      alert("Lỗi tải ảnh lên: " + (error.message || "Không thể lưu ảnh."))
    }
  }

  // Cập nhật thông tin (Tên, SĐT)
  const handleUpdateProfile = async (e) => {
    e.preventDefault()
    setProfileMsg({ type: '', text: '' })
    setIsSavingProfile(true)
    try {
      await userApi.updateProfile({ fullName: editName, phone: editPhone, phoneNumber: editPhone })
      setProfileMsg({ type: 'success', text: 'Cập nhật thông tin thành công!' })
      setProfile(p => ({ ...p, fullName: editName, phone: editPhone, phoneNumber: editPhone }))
      // Cập nhật tên lên Navbar luôn
      if (updateSessionUser) updateSessionUser({ fullName: editName })
    } catch (error) {
      setProfileMsg({ type: 'error', text: error.message })
    } finally {
      setIsSavingProfile(false)
    }
  }

  // Đổi mật khẩu
  const handleChangePassword = async (e) => {
    e.preventDefault()
    if (!oldPassword || !newPassword || !confirmPassword) return setPassMsg({ type: 'error', text: 'Vui lòng nhập đủ thông tin.' })
    if (newPassword.length < 6) return setPassMsg({ type: 'error', text: 'Mật khẩu mới phải từ 6 ký tự.' })
    if (newPassword !== confirmPassword) return setPassMsg({ type: 'error', text: 'Mật khẩu xác nhận không khớp!' })

    setPassMsg({ type: '', text: '' })
    setIsSavingPass(true)
    try {
      await userApi.changePassword({ oldPassword, newPassword, confirmPassword })
      setPassMsg({ type: 'success', text: 'Đổi mật khẩu thành công!' })
      setOldPassword('')
      setNewPassword('')
      setConfirmPassword('')
    } catch (error) {
      setPassMsg({ type: 'error', text: error.message })
    } finally {
      setIsSavingPass(false)
    }
  }

  if (loading) return <div className="p-10 text-center text-muted">Đang tải thông tin...</div>
  if (!profile) return <div className="p-10 text-center text-red-500">Lỗi khi tải dữ liệu.</div>

  const cleanRole = String(profile.role || profile.roleName || 'CUSTOMER').replace(/^ROLE_/i, '').toUpperCase()
  const displayAvatar = normalizeAvatarUrl(profile.avatarUrl || profile.avatar)

  return (
    <div className="mx-auto max-w-4xl p-6">
      <h1 className="mb-6 text-2xl font-bold text-ink">Tài khoản của tôi</h1>
      
      <div className="grid grid-cols-1 gap-8 md:grid-cols-3">
        {/* CỘT TRÁI: Avatar & Thông tin chung */}
        <div className="rounded-2xl border border-line bg-white p-6 shadow-sm">
          <div className="flex flex-col items-center text-center">
            <div className="relative mb-4">
              <img 
                src={displayAvatar || `https://ui-avatars.com/api/?name=${encodeURIComponent(profile.fullName || 'User')}&background=random`} 
                alt="Avatar" 
                className="h-28 w-28 rounded-full object-cover border-4 border-paper shadow-sm"
              />
              <label className="absolute bottom-0 right-0 cursor-pointer rounded-full bg-berry p-2 text-white shadow-md hover:bg-berry-dark transition">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M4 5a2 2 0 00-2 2v8a2 2 0 002 2h12a2 2 0 002-2V7a2 2 0 00-2-2h-1.586a1 1 0 01-.707-.293l-1.121-1.121A2 2 0 0011.172 3H8.828a2 2 0 00-1.414.586L6.293 4.707A1 1 0 015.586 5H4zm6 9a3 3 0 100-6 3 3 0 000 6z" clipRule="evenodd" />
                </svg>
                <input type="file" accept="image/*" className="hidden" onChange={handleAvatarChange} />
              </label>
            </div>
            <h2 className="text-xl font-semibold text-ink">{profile.fullName}</h2>
            <p className="text-sm text-muted mb-2">{profile.email}</p>
            <RoleBadge role={cleanRole} />
          </div>
          <div className="mt-6 border-t border-line pt-4 text-sm text-muted">
            <p>Ngày tham gia: {profile.joinedDate || profile.createdAt ? new Date(profile.joinedDate || profile.createdAt).toLocaleDateString('vi-VN') : 'Hôm nay'}</p>
          </div>
        </div>

        {/* CỘT PHẢI: Form Cập nhật & Đổi mật khẩu */}
        <div className="col-span-2 space-y-6">
          
          <div className="rounded-2xl border border-line bg-white p-6 shadow-sm">
            <h3 className="mb-4 text-lg font-semibold text-ink">Chỉnh sửa thông tin</h3>
            {profileMsg.text && <Notice type={profileMsg.type}>{profileMsg.text}</Notice>}
            <form onSubmit={handleUpdateProfile} className="mt-4 space-y-4">
              <Field id="prof-name" label="Họ và tên">
                <input id="prof-name" value={editName} onChange={e => setEditName(e.target.value)} className={inputClass()} />
              </Field>
              <Field id="prof-phone" label="Số điện thoại">
                <input id="prof-phone" value={editPhone} onChange={e => setEditPhone(e.target.value)} className={inputClass()} />
              </Field>
              <div className="text-right">
                <PrimaryButton type="submit" loading={isSavingProfile} className="w-auto inline-flex px-6">
                  Lưu thay đổi
                </PrimaryButton>
              </div>
            </form>
          </div>

          <div className="rounded-2xl border border-line bg-white p-6 shadow-sm">
            <h3 className="mb-4 text-lg font-semibold text-ink">Đổi mật khẩu</h3>
            {passMsg.text && <Notice type={passMsg.type}>{passMsg.text}</Notice>}
            <form onSubmit={handleChangePassword} className="mt-4 space-y-4">
              <Field id="old-pass" label="Mật khẩu hiện tại">
                <PasswordInput id="old-pass" value={oldPassword} onChange={e => setOldPassword(e.target.value)} />
              </Field>
              <Field id="new-pass" label="Mật khẩu mới (ít nhất 8 ký tự)">
                <PasswordInput id="new-pass" value={newPassword} onChange={e => setNewPassword(e.target.value)} />
              </Field>
              <Field id="confirm-pass" label="Xác nhận mật khẩu mới">
                <PasswordInput id="confirm-pass" value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)} />
              </Field>
              <div className="text-right">
                <PrimaryButton type="submit" loading={isSavingPass} className="w-auto inline-flex px-6">
                  Cập nhật mật khẩu
                </PrimaryButton>
              </div>
            </form>
          </div>

        </div>
      </div>
    </div>
  )
}