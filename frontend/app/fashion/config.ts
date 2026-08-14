import type { SubCategory } from '@/components/ui/CategoryPageTemplate';
import type { BrandItem } from '@/components/ui/BrandsPageTemplate';

export const FASHION_SUBCATEGORIES: Record<string, SubCategory> = {
  'women-clothing': { slug: 'women-clothing', label: "Women's Clothing", icon: '👗', color: 'from-pink-600 to-rose-700', desc: 'Dresses, tops & more' },
  'women-shoes': { slug: 'women-shoes', label: "Women's Shoes", icon: '👠', color: 'from-fuchsia-600 to-purple-700', desc: 'Heels, flats & sneakers' },
  'women-bags': { slug: 'women-bags', label: 'Bags & Accessories', icon: '👜', color: 'from-amber-600 to-orange-700', desc: 'Handbags & accessories' },
  'men-clothing': { slug: 'men-clothing', label: "Men's Clothing", icon: '👔', color: 'from-blue-600 to-indigo-700', desc: 'Shirts, trousers & suits' },
  'men-shoes': { slug: 'men-shoes', label: "Men's Shoes", icon: '👞', color: 'from-slate-600 to-gray-800', desc: 'Formal & casual shoes' },
  'watches': { slug: 'watches', label: 'Watches', icon: '⌚', color: 'from-emerald-600 to-teal-700', desc: 'Luxury & everyday watches' },
  'girls-clothing': { slug: 'girls-clothing', label: "Girls' Clothing", icon: '🎀', color: 'from-rose-600 to-pink-700', desc: "Kids' girls fashion" },
  'boys-clothing': { slug: 'boys-clothing', label: "Boys' Clothing", icon: '🧢', color: 'from-sky-600 to-cyan-700', desc: "Kids' boys fashion" },
};

export const FASHION_BRANDS_BY_SUBCATEGORY: Record<string, BrandItem[]> = {
  'women-clothing': [
    { name: 'Zara', slug: 'zara', icon: '👗', color: 'from-gray-800 to-black' },
    { name: 'H&M', slug: 'hm', icon: '👗', color: 'from-red-600 to-red-800' },
    { name: 'Gucci', slug: 'gucci', icon: '👗', color: 'from-amber-700 to-yellow-900' },
    { name: 'Chanel', slug: 'chanel', icon: '👗', color: 'from-gray-700 to-gray-900' },
    { name: 'Nike', slug: 'nike', icon: '👗', color: 'from-gray-700 to-gray-900' },
    { name: 'Adidas', slug: 'adidas', icon: '👗', color: 'from-blue-700 to-blue-900' },
    { name: 'Shein', slug: 'shein', icon: '👗', color: 'from-pink-600 to-rose-800' },
    { name: 'Other', slug: 'other', icon: '🏷️', color: 'from-gray-500 to-slate-700' },
  ],
  'women-shoes': [
    { name: 'Nike', slug: 'nike', icon: '👠', color: 'from-gray-700 to-gray-900' },
    { name: 'Adidas', slug: 'adidas', icon: '👠', color: 'from-blue-700 to-blue-900' },
    { name: 'Puma', slug: 'puma', icon: '👠', color: 'from-red-600 to-red-800' },
    { name: 'Gucci', slug: 'gucci', icon: '👠', color: 'from-amber-700 to-yellow-900' },
    { name: 'Louis Vuitton', slug: 'louis-vuitton', icon: '👠', color: 'from-amber-600 to-orange-800' },
    { name: 'Jimmy Choo', slug: 'jimmy-choo', icon: '👠', color: 'from-rose-500 to-pink-700' },
    { name: 'Other', slug: 'other', icon: '🏷️', color: 'from-gray-500 to-slate-700' },
  ],
  'women-bags': [
    { name: 'Louis Vuitton', slug: 'louis-vuitton', icon: '👜', color: 'from-amber-600 to-yellow-800' },
    { name: 'Gucci', slug: 'gucci', icon: '👜', color: 'from-amber-700 to-yellow-900' },
    { name: 'Chanel', slug: 'chanel', icon: '👜', color: 'from-gray-700 to-gray-900' },
    { name: 'Prada', slug: 'prada', icon: '👜', color: 'from-slate-600 to-gray-900' },
    { name: 'Michael Kors', slug: 'michael-kors', icon: '👜', color: 'from-yellow-600 to-amber-800' },
    { name: 'Coach', slug: 'coach', icon: '👜', color: 'from-red-600 to-red-900' },
    { name: 'Other', slug: 'other', icon: '🏷️', color: 'from-gray-500 to-slate-700' },
  ],
  'men-clothing': [
    { name: 'Nike', slug: 'nike', icon: '👔', color: 'from-gray-700 to-gray-900' },
    { name: 'Adidas', slug: 'adidas', icon: '👔', color: 'from-blue-700 to-blue-900' },
    { name: 'Zara', slug: 'zara', icon: '👔', color: 'from-gray-800 to-black' },
    { name: 'H&M', slug: 'hm', icon: '👔', color: 'from-red-600 to-red-800' },
    { name: 'Ralph Lauren', slug: 'ralph-lauren', icon: '👔', color: 'from-blue-800 to-indigo-900' },
    { name: 'Tommy Hilfiger', slug: 'tommy-hilfiger', icon: '👔', color: 'from-red-700 to-blue-800' },
    { name: 'Other', slug: 'other', icon: '🏷️', color: 'from-gray-500 to-slate-700' },
  ],
  'men-shoes': [
    { name: 'Nike', slug: 'nike', icon: '👞', color: 'from-gray-700 to-gray-900' },
    { name: 'Adidas', slug: 'adidas', icon: '👞', color: 'from-blue-700 to-blue-900' },
    { name: 'Puma', slug: 'puma', icon: '👞', color: 'from-red-600 to-red-800' },
    { name: 'New Balance', slug: 'new-balance', icon: '👞', color: 'from-gray-600 to-gray-800' },
    { name: 'Jordan', slug: 'jordan', icon: '👟', color: 'from-red-700 to-red-900' },
    { name: 'Timberland', slug: 'timberland', icon: '👞', color: 'from-yellow-700 to-amber-900' },
    { name: 'Other', slug: 'other', icon: '🏷️', color: 'from-gray-500 to-slate-700' },
  ],
  watches: [
    { name: 'Rolex', slug: 'rolex', icon: '⌚', color: 'from-yellow-600 to-amber-800' },
    { name: 'Omega', slug: 'omega', icon: '⌚', color: 'from-blue-700 to-indigo-900' },
    { name: 'Casio', slug: 'casio', icon: '⌚', color: 'from-gray-700 to-gray-900' },
    { name: 'Seiko', slug: 'seiko', icon: '⌚', color: 'from-red-700 to-red-900' },
    { name: 'Apple', slug: 'apple', icon: '⌚', color: 'from-gray-600 to-gray-800' },
    { name: 'Samsung', slug: 'samsung', icon: '⌚', color: 'from-blue-600 to-cyan-800' },
    { name: 'Tag Heuer', slug: 'tag-heuer', icon: '⌚', color: 'from-red-600 to-rose-800' },
    { name: 'Other', slug: 'other', icon: '🏷️', color: 'from-gray-500 to-slate-700' },
  ],
  'girls-clothing': [
    { name: 'Zara Kids', slug: 'zara', icon: '🎀', color: 'from-pink-700 to-rose-900' },
    { name: 'H&M Kids', slug: 'hm', icon: '🎀', color: 'from-red-600 to-red-800' },
    { name: 'Nike', slug: 'nike', icon: '🎀', color: 'from-gray-700 to-gray-900' },
    { name: 'Adidas', slug: 'adidas', icon: '🎀', color: 'from-blue-700 to-blue-900' },
    { name: 'Other', slug: 'other', icon: '🏷️', color: 'from-gray-500 to-slate-700' },
  ],
  'boys-clothing': [
    { name: 'Nike', slug: 'nike', icon: '🧢', color: 'from-gray-700 to-gray-900' },
    { name: 'Adidas', slug: 'adidas', icon: '🧢', color: 'from-blue-700 to-blue-900' },
    { name: 'Zara Kids', slug: 'zara', icon: '🧢', color: 'from-gray-800 to-black' },
    { name: 'H&M Kids', slug: 'hm', icon: '🧢', color: 'from-red-600 to-red-800' },
    { name: 'Other', slug: 'other', icon: '🏷️', color: 'from-gray-500 to-slate-700' },
  ],
};

export const FASHION_PRICE_RANGES = [
  { label: 'Any Price', min: '', max: '' },
  { label: 'Under $50', min: '', max: '50' },
  { label: '$50–$200', min: '50', max: '200' },
  { label: '$200–$500', min: '200', max: '500' },
  { label: '$500–$2k', min: '500', max: '2000' },
  { label: 'Over $2k', min: '2000', max: '' },
];
