import { Link } from 'react-router-dom';

export default function FeaturedVendors({ vendors = [], loading }) {
  return (
    <section className="bg-slate-50">
      <div className="mx-auto max-w-6xl px-4 py-12">
        <div className="flex items-end justify-between">
          <h2 className="text-2xl font-bold text-slate-900">Đối tác tiêu biểu</h2>
          <Link to="/services" className="text-sm font-medium text-violet-700 hover:underline">
            Xem tất cả dịch vụ
          </Link>
        </div>
        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {loading
            ? Array.from({ length: 4 }).map((_, i) => (
                <div key={i} className="h-32 animate-pulse rounded-xl bg-slate-200" />
              ))
            : vendors.map((v) => (
                <div key={v.id} className="rounded-xl border border-slate-200 bg-white p-4">
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-violet-100 text-lg font-bold text-violet-700">
                    {v.name.charAt(0)}
                  </div>
                  <p className="mt-3 font-semibold text-slate-900">{v.name}</p>
                  <p className="text-sm text-slate-500">{v.location}</p>
                  <p className="mt-2 text-sm text-slate-700">
                    ★ {v.rating} · {v.eventsDone} sự kiện
                  </p>
                </div>
              ))}
        </div>
      </div>
    </section>
  );
}
