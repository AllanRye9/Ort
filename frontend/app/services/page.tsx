import CategoryPageTemplate from '@/components/ui/CategoryPageTemplate';

const SERVICES_SUBCATEGORIES = [
  { slug: 'cleaning', label: 'Cleaning', icon: '🧹', color: 'from-sky-500 to-blue-600', desc: 'Home & office cleaning' },
  { slug: 'plumbing-electrical', label: 'Plumbing & Electrical', icon: '🔧', color: 'from-slate-500 to-gray-700', desc: 'Repairs & installations' },
  { slug: 'movers-storage', label: 'Movers & Storage', icon: '🚚', color: 'from-amber-500 to-orange-600', desc: 'Moving & storage services' },
  { slug: 'tutoring', label: 'Tutoring', icon: '📚', color: 'from-emerald-500 to-teal-600', desc: 'Academic tutoring & coaching' },
  { slug: 'design-creative', label: 'Design & Creative', icon: '🎨', color: 'from-violet-500 to-purple-600', desc: 'Graphic design & branding' },
  { slug: 'it-tech-support', label: 'IT & Tech Support', icon: '💻', color: 'from-blue-500 to-indigo-600', desc: 'Tech help & IT services' },
];

export default function ServicesPage() {
  return (
    <CategoryPageTemplate
      categorySlug="services"
      categoryLabel="Services"
      heroGradient="from-slate-900 via-gray-800 to-slate-900"
      heroIcon="🔧"
      heroTitle={
        <>
          Find Trusted <span className="text-amber-400">Services</span>
        </>
      }
      heroSubtitle="Connect with professional service providers for home, business and personal needs."
      subcategories={SERVICES_SUBCATEGORIES}
      basePath="/services"
      postCtaLabel="+ Offer a Service"
    />
  );
}
