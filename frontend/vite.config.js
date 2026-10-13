import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// Khi chạy `npm run dev`, mọi request bắt đầu bằng /api sẽ được chuyển sang Backend (Spring Boot, cổng 8080).
// Nhờ vậy trình duyệt không bị lỗi CORS. Nếu Backend chạy cổng khác thì sửa `target`.
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    proxy: {
      '/api': { target: 'http://localhost:8080', changeOrigin: true },
      '/uploads': { target: 'http://localhost:8080', changeOrigin: true },
    },
  },
})
