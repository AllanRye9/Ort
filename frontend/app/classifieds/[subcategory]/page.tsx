import CategorySubcategoryTemplate from '@/components/ui/CategorySubcategoryTemplate';
import type { SubCategory } from '@/components/ui/CategoryPageTemplate';

const CLASSIFIEDS_SUBCATEGORIES: Record<string, SubCategory> = {
  'furniture-classifieds': { slug: 'furniture-classifieds', label: 'Furniture', icon: '🛋️', color: 'from-amber-600 to-orange-700', desc: 'Sofas, beds & more' },
  'appliances': { slug: 'appliances', label: 'Appliances', icon: '🧹', color: 'from-sky-600 to-blue-700', desc: 'Household appliances' },
  'tools-garden': { slug: 'tools-garden', label: 'Tools & Garden', icon: '🔨', color: 'from-lime-600 to-green-700', desc: 'Hand tools, garden gear' },
  'kids-baby': { slug: 'kids-baby', label: 'Kids & Baby', icon: '🧸', color: 'from-pink-600 to-rose-700', desc: 'Toys, clothes & gear' },
  'sports-outdoors': { slug: 'sports-outdoors', label: 'Sports & Outdoors', icon: '⚽', color: 'from-emerald-600 to-teal-700', desc: 'Sports equipment' },
  'books-hobbies': { slug: 'books-hobbies', label: 'Books & Hobbies', icon: '📚', color: 'from-violet-600 to-purple-700', desc: 'Books, art & crafts' },
};

export default function ClassifiedsSubcategoryPage() {
  return (
    <CategorySubcategoryTemplate
      subcategories={CLASSIFIEDS_SUBCATEGORIES}
      basePath="/classifieds"
      categoryLabel="Classifieds"
      categoryHref="/classifieds"
    />
  );
}
