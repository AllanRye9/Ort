import CategoryPageTemplate from '@/components/ui/CategoryPageTemplate';

const ELECTRONICS_SUBCATEGORIES = [
  { slug: 'laptops', label: 'Laptops', icon: '💻', color: 'from-blue-500 to-indigo-600', desc: 'Portable computers' },
  { slug: 'desktops', label: 'Desktops & Monitors', icon: '🖥️', color: 'from-sky-500 to-cyan-600', desc: 'Desktop PCs & screens' },
  { slug: 'tablets', label: 'Tablets', icon: '📱', color: 'from-teal-500 to-emerald-600', desc: 'iPad, Android & more' },
  { slug: 'smartphones', label: 'Smartphones', icon: '📱', color: 'from-rose-500 to-pink-600', desc: 'All phone brands' },
  { slug: 'headphones', label: 'Headphones', icon: '🎧', color: 'from-purple-500 to-violet-600', desc: 'Earbuds & headphones' },
  { slug: 'cameras', label: 'Cameras', icon: '📷', color: 'from-amber-500 to-orange-600', desc: 'DSLR, mirrorless & more' },
  { slug: 'consoles', label: 'Consoles', icon: '🎮', color: 'from-red-500 to-rose-600', desc: 'PS5, Xbox, Nintendo' },
  { slug: 'games-accessories', label: 'Games & Accessories', icon: '🕹️', color: 'from-slate-500 to-gray-700', desc: 'Games, controllers & more' },
];

export default function ElectronicsPage() {
  return (
    <CategoryPageTemplate
      categorySlug="electronics"
      categoryLabel="Electronics"
      heroGradient="from-blue-900 via-indigo-800 to-blue-900"
      heroIcon="💻"
      heroTitle={
        <>
          Buy &amp; Sell <span className="text-amber-400">Electronics</span>
        </>
      }
      heroSubtitle="Shop the latest laptops, smartphones, cameras and gaming gear from verified sellers."
      subcategories={ELECTRONICS_SUBCATEGORIES}
      basePath="/electronics"
      postCtaLabel="+ Sell Electronics"
    />
  );
}
