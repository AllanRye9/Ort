import CategorySubcategoryTemplate from '@/components/ui/CategorySubcategoryTemplate';
import type { SubCategory } from '@/components/ui/CategoryPageTemplate';

const SERVICES_SUBCATEGORIES: Record<string, SubCategory> = {
  'cleaning': { slug: 'cleaning', label: 'Cleaning', icon: '🧹', color: 'from-sky-600 to-blue-700', desc: 'Home & office cleaning' },
  'plumbing-electrical': { slug: 'plumbing-electrical', label: 'Plumbing & Electrical', icon: '🔧', color: 'from-slate-600 to-gray-800', desc: 'Repairs & installations' },
  'movers-storage': { slug: 'movers-storage', label: 'Movers & Storage', icon: '🚚', color: 'from-amber-600 to-orange-700', desc: 'Moving & storage services' },
  'tutoring': { slug: 'tutoring', label: 'Tutoring', icon: '📚', color: 'from-emerald-600 to-teal-700', desc: 'Academic tutoring' },
  'design-creative': { slug: 'design-creative', label: 'Design & Creative', icon: '🎨', color: 'from-violet-600 to-purple-700', desc: 'Graphic design & branding' },
  'it-tech-support': { slug: 'it-tech-support', label: 'IT & Tech Support', icon: '💻', color: 'from-blue-600 to-indigo-700', desc: 'Tech help & IT services' },
};

export default function ServicesSubcategoryPage() {
  return (
    <CategorySubcategoryTemplate
      subcategories={SERVICES_SUBCATEGORIES}
      basePath="/services"
      categoryLabel="Services"
      categoryHref="/services"
    />
  );
}
