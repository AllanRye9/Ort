import CategoryPageTemplate from '@/components/ui/CategoryPageTemplate';

const ARTS_SUBCATEGORIES = [
  { slug: 'paintings', label: 'Paintings', icon: '🖼️', color: 'from-indigo-500 to-blue-600', desc: 'Original paintings & prints' },
  { slug: 'sculptures', label: 'Sculptures', icon: '🗿', color: 'from-blue-500 to-indigo-600', desc: 'Bronze, stone & mixed-media works' },
  { slug: 'photography', label: 'Photography', icon: '📷', color: 'from-sky-500 to-blue-600', desc: 'Fine art & limited-edition prints' },
  { slug: 'antiques', label: 'Antiques', icon: '🏺', color: 'from-stone-500 to-amber-700', desc: 'Historical artefacts & antiques' },
  { slug: 'coins-stamps', label: 'Coins & Stamps', icon: '🪙', color: 'from-yellow-600 to-amber-700', desc: 'Numismatic & philatelic items' },
  { slug: 'vintage', label: 'Vintage Items', icon: '🕰️', color: 'from-amber-500 to-orange-600', desc: 'Retro collectibles & memorabilia' },
  { slug: 'tribal-art', label: 'Tribal & Cultural Art', icon: '🎭', color: 'from-orange-600 to-red-700', desc: 'African, Asian & traditional art' },
  { slug: 'other-art', label: 'Other Collectibles', icon: '🔮', color: 'from-purple-500 to-indigo-600', desc: 'Rare finds & unique collectibles' },
];

export default function ArtsCollectiblesPage() {
  return (
    <CategoryPageTemplate
      categorySlug="arts-collectibles"
      categoryLabel="Art & Collectibles"
      heroGradient="from-indigo-900 via-blue-800 to-indigo-900"
      heroIcon="🎨"
      heroTitle={
        <>
          Browse <span className="text-sky-400">Art &amp; Collectibles</span>
        </>
      }
      heroSubtitle="Discover rare original artworks, antiques, sculptures and collectibles from trusted sellers worldwide."
      subcategories={ARTS_SUBCATEGORIES}
      basePath="/arts-collectibles"
      postCtaLabel="+ List Your Artwork"
      whyItems={[
        { icon: '🔒', title: 'Verified Sellers', desc: 'All sellers are verified to protect the integrity of every transaction.' },
        { icon: '📸', title: 'High-Quality Photos', desc: 'Detailed images so you can inspect provenance and condition.' },
        { icon: '💬', title: 'Direct Messaging', desc: 'Connect directly with sellers and collectors for negotiations.' },
        { icon: '🌍', title: 'Global Reach', desc: 'Art & collectible listings from UAE, Uganda, Kenya and China.' },
      ]}
    />
  );
}
