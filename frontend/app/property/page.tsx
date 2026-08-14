import CategoryPageTemplate from '@/components/ui/CategoryPageTemplate';

const PROPERTY_SUBCATEGORIES = [
  { slug: 'apartments-rent', label: 'Apartments for Rent', icon: '🏢', color: 'from-sky-500 to-blue-600', desc: 'Flats & apartments to rent' },
  { slug: 'houses-rent', label: 'Houses for Rent', icon: '🏡', color: 'from-emerald-500 to-teal-600', desc: 'Houses & villas to rent' },
  { slug: 'rooms-rent', label: 'Rooms for Rent', icon: '🛏️', color: 'from-violet-500 to-purple-600', desc: 'Private & shared rooms' },
  { slug: 'apartments-sale', label: 'Apartments for Sale', icon: '🏗️', color: 'from-amber-500 to-orange-600', desc: 'Flats & apartments to buy' },
  { slug: 'houses-sale', label: 'Houses for Sale', icon: '🏠', color: 'from-rose-500 to-red-600', desc: 'Houses & villas to buy' },
  { slug: 'land-plots', label: 'Land & Plots', icon: '🌱', color: 'from-lime-500 to-green-600', desc: 'Land and vacant plots' },
  { slug: 'office-space', label: 'Office Space', icon: '🏢', color: 'from-slate-500 to-gray-700', desc: 'Commercial offices to rent/buy' },
  { slug: 'shops-retail', label: 'Shops & Retail', icon: '🏪', color: 'from-pink-500 to-fuchsia-600', desc: 'Retail space & shops' },
  { slug: 'warehouses', label: 'Warehouses', icon: '🏭', color: 'from-stone-500 to-neutral-700', desc: 'Industrial & storage units' },
];

export default function PropertyPage() {
  return (
    <CategoryPageTemplate
      categorySlug="property"
      categoryLabel="Property"
      heroGradient="from-sky-900 via-blue-800 to-sky-900"
      heroIcon="🏠"
      heroTitle={
        <>
          Find Your <span className="text-amber-400">Perfect Home</span>
        </>
      }
      heroSubtitle="Browse thousands of property listings for rent and sale across UAE, Uganda, Kenya and China."
      subcategories={PROPERTY_SUBCATEGORIES}
      basePath="/property"
      postCtaLabel="+ List Property"
      whyItems={[
        { icon: '🔒', title: 'Verified Listings', desc: 'All properties are verified by our team.' },
        { icon: '📸', title: 'Full Photo Galleries', desc: 'Browse interior and exterior photos before visiting.' },
        { icon: '💬', title: 'Contact Landlords', desc: 'Message owners directly to schedule viewings.' },
        { icon: '🌍', title: 'Regional Coverage', desc: 'Properties in UAE, Uganda, Kenya and China.' },
      ]}
    />
  );
}
