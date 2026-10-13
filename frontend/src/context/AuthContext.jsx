import { createContext, useCallback, useContext, useMemo, useState } from 'react'
import { TOKEN_KEY, USER_KEY } from '../api/client'
import { isTokenExpired } from '../utils/jwt'

const AuthContext = createContext(null)

function readStoredSession() {
  try {
    const token = localStorage.getItem(TOKEN_KEY)
    const user = JSON.parse(localStorage.getItem(USER_KEY) || 'null')
    if (!token || !user) return { token: null, user: null }
    if (isTokenExpired(token)) {
      localStorage.removeItem(TOKEN_KEY)
      localStorage.removeItem(USER_KEY)
      return { token: null, user: null }
    }
    return { token, user }
  } catch {
    return { token: null, user: null }
  }
}

export function AuthProvider({ children }) {
  const [session, setSession] = useState(readStoredSession)

  const login = useCallback((data) => {
    localStorage.setItem(TOKEN_KEY, data.token)
    localStorage.setItem(USER_KEY, JSON.stringify(data.user))
    setSession({ token: data.token, user: data.user })
  }, [])

  const logout = useCallback(() => {
    localStorage.removeItem(TOKEN_KEY)
    localStorage.removeItem(USER_KEY)
    setSession({ token: null, user: null })
  }, [])

  // HÀM MỚI THÊM VÀO: Cập nhật thông tin user ngay lập tức
  const updateSessionUser = useCallback((updates) => {
    setSession(prev => {
      if (!prev.user) return prev;
      const newUser = { ...prev.user, ...updates };
      localStorage.setItem(USER_KEY, JSON.stringify(newUser));
      return { ...prev, user: newUser };
    });
  }, []);

  const value = useMemo(
    () => ({ ...session, isAuthenticated: Boolean(session.token), login, logout, updateSessionUser }),
    [session, login, logout, updateSessionUser],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth phải được dùng bên trong <AuthProvider>')
  return ctx
}