import { MOCK_CATEGORIES, MOCK_VENDORS, MOCK_SERVICES } from '../data/mock';

const BASE = import.meta.env.VITE_API_URL || 'http://localhost:8080/api';
// Đặt VITE_USE_MOCK=true trong .env để luôn dùng dữ liệu giả.
const FORCE_MOCK = import.meta.env.VITE_USE_MOCK === 'true';

async function get(path, params = {}) {
  const qs = new URLSearchParams(
    Object.entries(params).filter(([, v]) => v !== '' && v != null)
  ).toString();
  const res = await fetch(`${BASE}${path}${qs ? `?${qs}` : ''}`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

// Thử gọi API thật, lỗi thì dùng mock để vẫn làm tiếp được giao diện.
async function withFallback(call, fallback) {
  if (FORCE_MOCK) return fallback();
  try {
    return await call();
  } catch (e) {
    console.warn('API lỗi, dùng dữ liệu giả:', e.message);
    return fallback();
  }
}

export const getCategories = () =>
  withFallback(() => get('/categories'), () => MOCK_CATEGORIES);

export const getFeaturedVendors = () =>
  withFallback(() => get('/vendors/featured'), () => MOCK_VENDORS);

// filters: { category, minPrice, maxPrice, location, minRating, keyword }
export const getServices = (filters = {}) =>
  withFallback(
    () => get('/services', filters),
    () =>
      MOCK_SERVICES.filter(
        (s) =>
          (!filters.category || String(s.categoryId) === String(filters.category)) &&
          (!filters.location || s.location === filters.location) &&
          (!filters.minPrice || s.price >= Number(filters.minPrice)) &&
          (!filters.maxPrice || s.price <= Number(filters.maxPrice)) &&
          (!filters.minRating || s.rating >= Number(filters.minRating)) &&
          (!filters.keyword || s.name.toLowerCase().includes(filters.keyword.toLowerCase()))
      )
  );

export const formatVND = (n) => `${Number(n).toLocaleString('vi-VN')}₫`;
