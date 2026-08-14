'use client';

import Link from 'next/link';

const categories = [
  { label: 'Motors', slug: 'motors', href: '/motors' },
  { label: 'Electronics', slug: 'electronics', href: '/electronics' },
  { label: 'Fashion', slug: 'fashion', href: '/fashion' },
  { label: 'Home & Garden', slug: 'home-garden', href: '/furniture' },
  { label: 'Health & Beauty', slug: 'health-beauty', href: '/listings?category=health-beauty' },
  { label: 'Real Estate', slug: 'real-estate', href: '/property' },
  { label: 'Sports', slug: 'sports-outdoors', href: '/classifieds/sports-outdoors' },
  { label: 'Jobs', slug: 'jobs', href: '/jobs' },
  { label: 'Services', slug: 'services', href: '/services' },
  { label: 'Kids & Baby', slug: 'kids-baby', href: '/classifieds/kids-baby' },
  { label: 'Books', slug: 'books-education', href: '/classifieds/books-hobbies' },
  { label: 'Food & Drink', slug: 'food-beverages', href: '/listings?category=food-beverages' },
];

export default function CategoryPills() {
  return (
    <nav aria-label="Product categories" className="bg-white/80 backdrop-blur-sm border-b border-gray-100 shadow-sm">
      <div className="max-w-7xl mx-auto px-3 sm:px-6">
        <div className="flex flex-wrap gap-1.5 py-2.5 stagger-children">
          {categories.map((cat) => (
            <Link
              key={cat.slug}
              href={cat.href}
              className="flex-shrink-0 px-3 sm:px-4 py-1 sm:py-1.5 rounded-full text-xs sm:text-sm font-medium bg-gray-50 text-gray-700 border border-gray-200 hover:bg-[var(--theme-primary)] hover:text-white hover:border-[var(--theme-primary)] hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 interactive"
            >
              {cat.label}
            </Link>
          ))}
        </div>
      </div>
    </nav>
  );
}
