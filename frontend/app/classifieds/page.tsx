import CategoryPageTemplate from '@/components/ui/CategoryPageTemplate';

const CLASSIFIEDS_SUBCATEGORIES = [
  { slug: 'furniture-classifieds', label: 'Furniture', icon: '🛋️', color: 'from-amber-500 to-orange-600', desc: 'Sofas, beds & more' },
  { slug: 'appliances', label: 'Appliances', icon: '🧹', color: 'from-sky-500 to-blue-600', desc: 'Household appliances' },
  { slug: 'tools-garden', label: 'Tools & Garden', icon: '🔨', color: 'from-lime-500 to-green-600', desc: 'Hand tools, garden gear' },
  { slug: 'kids-baby', label: 'Kids & Baby', icon: '🧸', color: 'from-pink-500 to-rose-600', desc: 'Toys, clothes & gear' },
  { slug: 'sports-outdoors', label: 'Sports & Outdoors', icon: '⚽', color: 'from-emerald-500 to-teal-600', desc: 'Sports equipment & gear' },
  { slug: 'books-hobbies', label: 'Books & Hobbies', icon: '📚', color: 'from-violet-500 to-purple-600', desc: 'Books, art & crafts' },
];

export default function ClassifiedsPage() {
  return (
    <CategoryPageTemplate
      categorySlug="classifieds"
      categoryLabel="Classifieds"
      heroGradient="from-amber-900 via-orange-800 to-amber-900"
      heroIcon="📋"
      heroTitle={
        <>
          Buy &amp; Sell <span className="text-amber-400">Everything</span>
        </>
      }
      heroSubtitle="From household items to sports gear — find great deals on everyday items across the region."
      subcategories={CLASSIFIEDS_SUBCATEGORIES}
      basePath="/classifieds"
      postCtaLabel="+ Post Classified Ad"
    />
  );
}
