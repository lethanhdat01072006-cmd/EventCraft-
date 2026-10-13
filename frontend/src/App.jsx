import { useCallback, useState } from 'react'
import { Routes, Route, useNavigate } from 'react-router-dom'
import { useAuth } from './context/AuthContext'
import LoginModal from './components/LoginModal'
import Navbar from './components/Navbar'
import OtpModal from './components/OtpModal'
import RegisterModal from './components/RegisterModal'
import ForgotPasswordModal from './components/ForgotPasswordModal'
import HomePage from './pages/HomePage'
import ServicesPage from './pages/ServicesPage'
import PlaceholderPage from './pages/PlaceholderPage'
import ProfilePage from './pages/Profile/ProfilePage'

export default function App() {
  const { login } = useAuth()
  const navigate = useNavigate()
  const [modal, setModal] = useState(null) // null | 'login' | 'register' | 'otp' | 'forgot'
  const [otpEmail, setOtpEmail] = useState('')
  const [loginNotice, setLoginNotice] = useState('')
  const [loginEmail, setLoginEmail] = useState('')

  const close = useCallback(() => setModal(null), [])

  const openLogin = useCallback((notice = '', email = '') => {
    setLoginNotice(notice)
    setLoginEmail(email)
    setModal('login')
  }, [])

  const openRegister = useCallback(() => setModal('register'), [])

  // Hàm mở popup Quên mật khẩu
  const openForgot = useCallback(() => setModal('forgot'), [])

  const handleRegistered = (email) => {
    setOtpEmail(email)
    setModal('otp')
  }

  const handleVerified = (auth) => {
    if (auth) {
      login(auth)
      close()
    } else {
      openLogin('Tài khoản đã được kích hoạt. Hãy đăng nhập để tiếp tục.', otpEmail)
    }
  }

  return (
    <>
      <Navbar
        onLogin={() => openLogin()}
        onRegister={openRegister}
        onViewProfile={() => navigate('/profile')}
        onGoHome={() => navigate('/')}
      />

      <main>
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/services" element={<ServicesPage />} />
          <Route path="/services/:id" element={<PlaceholderPage title="Chi tiết dịch vụ" />} />
          <Route path="/workspace" element={<PlaceholderPage title="Workspace lên kế hoạch" />} />
          <Route path="/profile" element={<ProfilePage />} />
          <Route path="*" element={<PlaceholderPage title="Không tìm thấy trang" />} />
        </Routes>
      </main>

      {modal === 'login' && (
        <LoginModal
          notice={loginNotice}
          defaultEmail={loginEmail}
          onClose={close}
          onSwitchToRegister={openRegister}
          onOpenForgot={openForgot}
        />
      )}
      {modal === 'register' && (
        <RegisterModal onClose={close} onRegistered={handleRegistered} onSwitchToLogin={() => openLogin()} />
      )}
      {modal === 'otp' && (
        <OtpModal email={otpEmail} onClose={close} onVerified={handleVerified} onBack={openRegister} />
      )}
      {modal === 'forgot' && (
        <ForgotPasswordModal onClose={close} onSwitchToLogin={() => openLogin()} />
      )}
    </>
  )
}