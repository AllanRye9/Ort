import CategoryPageTemplate from '@/components/ui/CategoryPageTemplate';

const JEWELLERY_SUBCATEGORIES = [
  { slug: 'necklaces', label: 'Necklaces', icon: '📿', color: 'from-amber-500 to-yellow-600', desc: 'Gold, silver & gemstone necklaces' },
  { slug: 'rings', label: 'Rings', icon: '💍', color: 'from-yellow-500 to-amber-600', desc: 'Engagement, wedding & fashion rings' },
  { slug: 'bracelets', label: 'Bracelets', icon: '✨', color: 'from-amber-400 to-orange-500', desc: 'Bangles, cuffs & charm bracelets' },
  { slug: 'earrings', label: 'Earrings', icon: '💎', color: 'from-yellow-400 to-amber-500', desc: 'Studs, hoops & drop earrings' },
  { slug: 'pendants', label: 'Pendants', icon: '🏅', color: 'from-orange-400 to-amber-500', desc: 'Gemstone & precious metal pendants' },
  { slug: 'brooches', label: 'Brooches & Pins', icon: '🌸', color: 'from-amber-600 to-yellow-700', desc: 'Vintage & contemporary brooches' },
  { slug: 'sets', label: 'Jewellery Sets', icon: '🎁', color: 'from-yellow-600 to-amber-700', desc: 'Matching sets & collections' },
  { slug: 'other-jewellery', label: 'Other', icon: '🔮', color: 'from-amber-300 to-yellow-400', desc: 'Anklets, tiaras & more' },
];

export default function FineJewelleryPage() {
  return (
    <CategoryPageTemplate
      categorySlug="fine-jewellery"
      categoryLabel="Fine Jewellery"
      heroGradient="from-amber-900 via-yellow-800 to-amber-900"
      heroIcon="💎"
      heroTitle={
        <>
          Discover <span className="text-amber-400">Fine Jewellery</span>
        </>
      }
      heroSubtitle="Explore exquisite gold, silver and gemstone jewellery from verified sellers across UAE, Uganda, Kenya and China."
      subcategories={JEWELLERY_SUBCATEGORIES}
      basePath="/fine-jewellery"
      postCtaLabel="+ Sell Jewellery"
      whyItems={[
        { icon: '🔒', title: 'Verified Sellers', desc: 'Every jewellery seller is identity-verified for your peace of mind.' },
        { icon: '📸', title: 'Detailed Photos', desc: 'High-resolution imagery so you can inspect every piece closely.' },
        { icon: '💬', title: 'Direct Messaging', desc: 'Negotiate and ask questions directly with the seller.' },
        { icon: '🌍', title: 'Regional Coverage', desc: 'Fine jewellery listings from UAE, Uganda, Kenya and China.' },
      ]}
    />
  );
}
