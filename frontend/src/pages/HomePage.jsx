import { useEffect, useState } from 'react';
import Hero from '../components/Hero';
import CategoryList from '../components/CategoryList';
import FeaturedVendors from '../components/FeaturedVendors';
import { getCategories, getFeaturedVendors } from '../api/marketplace';

export default function HomePage() {
  const [categories, setCategories] = useState([]);
  const [vendors, setVendors] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([getCategories(), getFeaturedVendors()])
      .then(([c, v]) => { setCategories(c); setVendors(v); })
      .finally(() => setLoading(false));
  }, []);

  return (
    <>
      <Hero categories={categories} />
      <CategoryList categories={categories} loading={loading} />
      <FeaturedVendors vendors={vendors} loading={loading} />
    </>
  );
}
