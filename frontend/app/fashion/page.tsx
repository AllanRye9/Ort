import CategoryPageTemplate from '@/components/ui/CategoryPageTemplate';

const FASHION_SUBCATEGORIES = [
  { slug: 'women-clothing', label: "Women's Clothing", icon: '👗', color: 'from-pink-500 to-rose-600', desc: 'Dresses, tops & more' },
  { slug: 'women-shoes', label: "Women's Shoes", icon: '👠', color: 'from-fuchsia-500 to-purple-600', desc: 'Heels, flats & sneakers' },
  { slug: 'women-bags', label: 'Bags & Accessories', icon: '👜', color: 'from-amber-500 to-orange-600', desc: 'Handbags & accessories' },
  { slug: 'men-clothing', label: "Men's Clothing", icon: '👔', color: 'from-blue-500 to-indigo-600', desc: 'Shirts, trousers & suits' },
  { slug: 'men-shoes', label: "Men's Shoes", icon: '👞', color: 'from-slate-500 to-gray-700', desc: 'Formal & casual shoes' },
  { slug: 'watches', label: 'Watches', icon: '⌚', color: 'from-emerald-500 to-teal-600', desc: 'Luxury & everyday watches' },
  { slug: 'girls-clothing', label: "Girls' Clothing", icon: '🎀', color: 'from-rose-500 to-pink-600', desc: "Kids' girls fashion" },
  { slug: 'boys-clothing', label: "Boys' Clothing", icon: '🧢', color: 'from-sky-500 to-cyan-600', desc: "Kids' boys fashion" },
];

export default function FashionPage() {
  return (
    <CategoryPageTemplate
      categorySlug="fashion"
      categoryLabel="Fashion"
      heroGradient="from-pink-900 via-rose-800 to-pink-900"
      heroIcon="👗"
      heroTitle={
        <>
          Shop &amp; Sell <span className="text-amber-400">Fashion</span>
        </>
      }
      heroSubtitle="Discover clothing, shoes, bags and accessories for women, men and kids from top sellers."
      subcategories={FASHION_SUBCATEGORIES}
      basePath="/fashion"
      postCtaLabel="+ Sell Fashion Items"
    />
  );
}
