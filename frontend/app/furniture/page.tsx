import CategoryPageTemplate from '@/components/ui/CategoryPageTemplate';

const FURNITURE_SUBCATEGORIES = [
  { slug: 'living-room', label: 'Living Room', icon: '🛋️', color: 'from-amber-500 to-orange-600', desc: 'Sofas, tables & decor' },
  { slug: 'bedroom', label: 'Bedroom', icon: '🛏️', color: 'from-violet-500 to-purple-600', desc: 'Beds, wardrobes & more' },
  { slug: 'kitchen-dining', label: 'Kitchen & Dining', icon: '🍽️', color: 'from-rose-500 to-pink-600', desc: 'Dining tables & kitchenware' },
  { slug: 'garden-furniture', label: 'Garden Furniture', icon: '🌿', color: 'from-lime-500 to-green-600', desc: 'Outdoor tables & chairs' },
  { slug: 'bbq-grills', label: 'BBQ & Grills', icon: '🔥', color: 'from-red-500 to-rose-600', desc: 'Grills & outdoor cooking' },
  { slug: 'plants-seeds', label: 'Plants & Seeds', icon: '🌱', color: 'from-emerald-500 to-teal-600', desc: 'Indoor & outdoor plants' },
];

export default function FurniturePage() {
  return (
    <CategoryPageTemplate
      categorySlug="furniture"
      categoryLabel="Furniture & Garden"
      heroGradient="from-amber-900 via-yellow-800 to-amber-900"
      heroIcon="🛋️"
      heroTitle={
        <>
          Home &amp; <span className="text-amber-400">Garden</span>
        </>
      }
      heroSubtitle="Furnish your home or transform your garden with quality pieces from verified sellers."
      subcategories={FURNITURE_SUBCATEGORIES}
      basePath="/furniture"
      postCtaLabel="+ List Furniture"
    />
  );
}
