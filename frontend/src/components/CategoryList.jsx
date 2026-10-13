import { Link } from 'react-router-dom';

export default function CategoryList({ categories = [], loading }) {
  const items = categories.slice(0, 6);
  return (
    <section className="mx-auto max-w-6xl px-4 py-12">
      <h2 className="text-2xl font-bold text-slate-900">Danh mục dịch vụ</h2>
      <div className="mt-6 grid grid-cols-2 gap-4 sm:grid-cols-3">
        {loading
          ? Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="h-24 animate-pulse rounded-xl bg-slate-100" />
            ))
          : items.map((c) => (
              <Link
                key={c.id}
                to={`/services?category=${c.id}`}
                className="rounded-xl border border-slate-200 p-4 hover:border-violet-600 focus:outline-none focus:ring-2 focus:ring-violet-300"
              >
                <p className="font-semibold text-slate-900">{c.name}</p>
                {c.description && <p className="mt-1 text-sm text-slate-500">{c.description}</p>}
              </Link>
            ))}
      </div>
    </section>
  );
}
