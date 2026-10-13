import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import FilterSidebar from '../components/FilterSidebar';
import ServiceCard from '../components/ServiceCard';
import { getCategories, getServices } from '../api/marketplace';

const KEYS = ['category', 'minPrice', 'maxPrice', 'location', 'minRating', 'keyword'];

export default function ServicesPage() {
  // Bộ lọc nằm trên URL: chia sẻ link được và bấm Back vẫn đúng.
  const [params, setParams] = useSearchParams();
  const filters = Object.fromEntries(KEYS.map((k) => [k, params.get(k) || '']));

  const [categories, setCategories] = useState([]);
  const [services, setServices] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => { getCategories().then(setCategories); }, []);

  const query = params.toString();
  useEffect(() => {
    setLoading(true);
    getServices(filters).then(setServices).finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query]);

  const handleChange = (patch) => {
    const next = new URLSearchParams(params);
    Object.entries(patch).forEach(([k, v]) => (v === '' || v == null ? next.delete(k) : next.set(k, v)));
    setParams(next);
  };

  return (
    <div className="mx-auto grid max-w-6xl gap-6 px-4 py-8 lg:grid-cols-[260px_1fr]">
      <FilterSidebar categories={categories} filters={filters} onChange={handleChange} onReset={() => setParams({})} />
      <section>
        <h1 className="text-2xl font-bold text-slate-900">Dịch vụ sự kiện</h1>
        <p className="mt-1 text-sm text-slate-500">{loading ? 'Đang tải...' : `${services.length} dịch vụ phù hợp`}</p>

        {!loading && services.length === 0 ? (
          <div className="mt-8 rounded-xl border border-dashed border-slate-300 p-8 text-center">
            <p className="font-medium text-slate-900">Chưa có dịch vụ nào khớp bộ lọc</p>
            <p className="mt-1 text-sm text-slate-500">Thử nới khoảng giá hoặc bỏ bớt bộ lọc.</p>
          </div>
        ) : (
          <div className="mt-6 grid gap-5 sm:grid-cols-2 xl:grid-cols-3">
            {services.map((s) => <ServiceCard key={s.id} service={s} />)}
          </div>
        )}
      </section>
    </div>
  );
}
