import { formatVND } from '../api/marketplace';

export const PRICE_MAX = 50000000;
const STEP = 500000;
const LOCATIONS = ['Đà Nẵng', 'Hội An', 'Huế'];
const RATINGS = [4.5, 4, 3];

export default function FilterSidebar({ categories = [], filters, onChange, onReset }) {
  const minPrice = Number(filters.minPrice || 0);
  const maxPrice = Number(filters.maxPrice || PRICE_MAX);

  const setMin = (v) => onChange({ minPrice: Math.min(Number(v), maxPrice) || '' });
  const setMax = (v) => onChange({ maxPrice: Math.max(Number(v), minPrice) });

  const legend = 'mb-2 text-sm font-semibold text-slate-900';

  return (
    <aside className="space-y-6 rounded-xl border border-slate-200 bg-white p-4">
      <fieldset>
        <legend className={legend}>Ngành hàng</legend>
        <div className="space-y-1.5 text-sm">
          <label className="flex items-center gap-2">
            <input type="radio" name="category" checked={!filters.category} onChange={() => onChange({ category: '' })} />
            Tất cả
          </label>
          {categories.map((c) => (
            <label key={c.id} className="flex items-center gap-2">
              <input
                type="radio"
                name="category"
                checked={String(filters.category) === String(c.id)}
                onChange={() => onChange({ category: c.id })}
              />
              {c.name}
            </label>
          ))}
        </div>
      </fieldset>

      <fieldset>
        <legend className={legend}>Khoảng giá</legend>
        <p className="text-sm text-slate-600">
          {formatVND(minPrice)} – {formatVND(maxPrice)}
        </p>
        <label className="mt-2 block text-xs text-slate-500">
          Từ
          <input type="range" min={0} max={PRICE_MAX} step={STEP} value={minPrice}
            onChange={(e) => setMin(e.target.value)} className="w-full accent-violet-600" />
        </label>
        <label className="block text-xs text-slate-500">
          Đến
          <input type="range" min={0} max={PRICE_MAX} step={STEP} value={maxPrice}
            onChange={(e) => setMax(e.target.value)} className="w-full accent-violet-600" />
        </label>
      </fieldset>

      <fieldset>
        <legend className={legend}>Khu vực</legend>
        <select
          className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          value={filters.location || ''}
          onChange={(e) => onChange({ location: e.target.value })}
        >
          <option value="">Mọi nơi</option>
          {LOCATIONS.map((l) => <option key={l} value={l}>{l}</option>)}
        </select>
      </fieldset>

      <fieldset>
        <legend className={legend}>Đánh giá</legend>
        <div className="space-y-1.5 text-sm">
          <label className="flex items-center gap-2">
            <input type="radio" name="rating" checked={!filters.minRating} onChange={() => onChange({ minRating: '' })} />
            Tất cả
          </label>
          {RATINGS.map((r) => (
            <label key={r} className="flex items-center gap-2">
              <input type="radio" name="rating" checked={Number(filters.minRating) === r}
                onChange={() => onChange({ minRating: r })} />
              Từ {r} ★ trở lên
            </label>
          ))}
        </div>
      </fieldset>

      <button type="button" onClick={onReset}
        className="w-full rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium hover:bg-slate-50">
        Xóa bộ lọc
      </button>
    </aside>
  );
}
