import { useState } from 'react';
import { useNavigate } from 'react-router-dom';

const LOCATIONS = ['Đà Nẵng', 'Hội An', 'Huế'];

export default function Hero({ categories = [] }) {
  const navigate = useNavigate();
  const [category, setCategory] = useState('');
  const [date, setDate] = useState('');
  const [location, setLocation] = useState('');

  const handleSearch = (e) => {
    e.preventDefault();
    const params = new URLSearchParams();
    if (category) params.set('category', category);
    if (date) params.set('date', date);
    if (location) params.set('location', location);
    navigate(`/services?${params.toString()}`);
  };

  const field =
    'w-full rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-sm focus:border-violet-600 focus:outline-none focus:ring-2 focus:ring-violet-200';

  return (
    <section className="bg-slate-900 text-white">
      <div className="mx-auto max-w-6xl px-4 py-16 sm:py-24">
        <h1 className="max-w-2xl text-4xl font-bold leading-tight sm:text-5xl">
          Tìm đúng đối tác cho sự kiện của bạn
        </h1>
        <p className="mt-4 max-w-xl text-slate-300">
          So sánh nhà cung cấp tiệc, trang trí, chụp ảnh và âm thanh ở một nơi.
        </p>

        <form
          onSubmit={handleSearch}
          className="mt-8 grid gap-3 rounded-xl bg-white p-4 text-slate-900 sm:grid-cols-4"
        >
          <label className="text-sm font-medium">
            Loại tiệc
            <select className={`${field} mt-1`} value={category} onChange={(e) => setCategory(e.target.value)}>
              <option value="">Tất cả</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </label>
          <label className="text-sm font-medium">
            Ngày tổ chức
            <input type="date" className={`${field} mt-1`} value={date} onChange={(e) => setDate(e.target.value)} />
          </label>
          <label className="text-sm font-medium">
            Địa điểm
            <select className={`${field} mt-1`} value={location} onChange={(e) => setLocation(e.target.value)}>
              <option value="">Mọi nơi</option>
              {LOCATIONS.map((l) => (
                <option key={l} value={l}>{l}</option>
              ))}
            </select>
          </label>
          <button
            type="submit"
            className="self-end rounded-lg bg-violet-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-violet-700 focus:outline-none focus:ring-2 focus:ring-violet-300"
          >
            Tìm dịch vụ
          </button>
        </form>
      </div>
    </section>
  );
}
