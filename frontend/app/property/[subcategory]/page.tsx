import CategorySubcategoryTemplate from '@/components/ui/CategorySubcategoryTemplate';
import type { SubCategory } from '@/components/ui/CategoryPageTemplate';

const PROPERTY_SUBCATEGORIES: Record<string, SubCategory> = {
  'apartments-rent': { slug: 'apartments-rent', label: 'Apartments for Rent', icon: '🏢', color: 'from-sky-600 to-blue-700', desc: 'Flats & apartments to rent' },
  'houses-rent': { slug: 'houses-rent', label: 'Houses for Rent', icon: '🏡', color: 'from-emerald-600 to-teal-700', desc: 'Houses & villas to rent' },
  'rooms-rent': { slug: 'rooms-rent', label: 'Rooms for Rent', icon: '🛏️', color: 'from-violet-600 to-purple-700', desc: 'Private & shared rooms' },
  'apartments-sale': { slug: 'apartments-sale', label: 'Apartments for Sale', icon: '🏗️', color: 'from-amber-600 to-orange-700', desc: 'Flats & apartments to buy' },
  'houses-sale': { slug: 'houses-sale', label: 'Houses for Sale', icon: '🏠', color: 'from-rose-600 to-red-700', desc: 'Houses & villas to buy' },
  'land-plots': { slug: 'land-plots', label: 'Land & Plots', icon: '🌱', color: 'from-lime-600 to-green-700', desc: 'Land and vacant plots' },
  'office-space': { slug: 'office-space', label: 'Office Space', icon: '🏢', color: 'from-slate-600 to-gray-800', desc: 'Commercial offices' },
  'shops-retail': { slug: 'shops-retail', label: 'Shops & Retail', icon: '🏪', color: 'from-pink-600 to-fuchsia-700', desc: 'Retail space & shops' },
  'warehouses': { slug: 'warehouses', label: 'Warehouses', icon: '🏭', color: 'from-stone-600 to-neutral-800', desc: 'Industrial & storage units' },
};

const PROPERTY_PRICE_RANGES = [
  { label: 'Any Price', min: '', max: '' },
  { label: 'Under $500/mo', min: '', max: '500' },
  { label: '$500–$1.5k/mo', min: '500', max: '1500' },
  { label: '$1.5k–$5k/mo', min: '1500', max: '5000' },
  { label: '$5k–$20k', min: '5000', max: '20000' },
  { label: '$20k–$100k', min: '20000', max: '100000' },
  { label: 'Over $100k', min: '100000', max: '' },
];

export default function PropertySubcategoryPage() {
  return (
    <CategorySubcategoryTemplate
      subcategories={PROPERTY_SUBCATEGORIES}
      basePath="/property"
      categoryLabel="Property"
      categoryHref="/property"
      priceRanges={PROPERTY_PRICE_RANGES}
    />
  );
}
