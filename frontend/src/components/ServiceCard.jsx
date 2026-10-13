import { Link } from 'react-router-dom';
import { formatVND } from '../api/marketplace';

export default function ServiceCard({ service }) {
  const { id, name, vendorName, location, rating, price, oldPrice, discountPercent, imageUrl } = service;
  return (
    <article className="flex flex-col overflow-hidden rounded-xl border border-slate-200 bg-white">
      <div className="relative aspect-[4/3] bg-gradient-to-br from-violet-100 to-slate-200">
        {imageUrl && <img src={imageUrl} alt={name} className="h-full w-full object-cover" />}
        {discountPercent > 0 && (
          <span className="absolute left-3 top-3 rounded-full bg-rose-600 px-2.5 py-1 text-xs font-semibold text-white">
            Giảm {discountPercent}%
          </span>
        )}
      </div>
      <div className="flex flex-1 flex-col p-4">
        <h3 className="font-semibold text-slate-900">{name}</h3>
        <p className="mt-1 text-sm text-slate-500">
          {vendorName} · {location}
        </p>
        <p className="mt-1 text-sm text-slate-700">★ {rating}</p>
        <div className="mt-3 flex items-baseline gap-2">
          <span className="text-lg font-bold text-violet-700">{formatVND(price)}</span>
          {oldPrice && <span className="text-sm text-slate-400 line-through">{formatVND(oldPrice)}</span>}
        </div>
        <Link
          to={`/services/${id}`}
          className="mt-4 rounded-lg border border-violet-600 px-4 py-2 text-center text-sm font-semibold text-violet-700 hover:bg-violet-600 hover:text-white focus:outline-none focus:ring-2 focus:ring-violet-300"
        >
          Xem chi tiết
        </Link>
      </div>
    </article>
  );
}
