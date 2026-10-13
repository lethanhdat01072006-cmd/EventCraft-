import { useParams } from 'react-router-dom';

// Trang tạm cho các route chưa làm (Detail, Workspace, Profile).
export default function PlaceholderPage({ title }) {
  const { id } = useParams();
  return (
    <div className="mx-auto max-w-6xl px-4 py-16">
      <h1 className="text-2xl font-bold text-slate-900">{title}{id ? ` #${id}` : ''}</h1>
      <p className="mt-2 text-slate-500">Trang này sẽ được hoàn thiện sau.</p>
    </div>
  );
}
