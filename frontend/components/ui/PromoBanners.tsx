import Link from 'next/link';
import { FlagIcon } from '@/components/ui/FlagIcon'; // SVG flags — not emoji

interface Banner {
  title: string;
  subtitle: string;
  cta: string;
  href: string;
  emoji: string;
  bgGradient: string;
  cities: string;
  isoCode: string; // ISO 3166-1 alpha-2 for SVG FlagIcon
}

const banners: Banner[] = [
  {
    title: 'Kampala',
    subtitle: 'The capital — the highest concentration of listings on Piitrade',
    cta: 'Explore Kampala',
    href: '/listings?location=Kampala',
    emoji: '🏙️',
    isoCode: 'UG',
    bgGradient: 'from-emerald-500 to-green-700',
    cities: 'Central Region',
  },
  {
    title: 'Jinja',
    subtitle: 'Source of the Nile — a growing hub for trade and tourism',
    cta: 'Explore Jinja',
    href: '/listings?location=Jinja',
    emoji: '🌊',
    isoCode: 'UG',
    bgGradient: 'from-red-500 to-rose-600',
    cities: 'Eastern Region',
  },
  {
    title: 'Gulu',
    subtitle: 'Northern Uganda\'s commercial centre',
    cta: 'Explore Gulu',
    href: '/listings?location=Gulu',
    emoji: '🌾',
    isoCode: 'UG',
    bgGradient: 'from-amber-500 to-orange-600',
    cities: 'Northern Region',
  },
  {
    title: 'Mbarara',
    subtitle: 'The heart of the southwest — vibrant local markets',
    cta: 'Explore Mbarara',
    href: '/listings?location=Mbarara',
    emoji: '🐄',
    isoCode: 'UG',
    bgGradient: 'from-red-500 to-rose-700',
    cities: 'Western Region',
  },
];

export default function PromoBanners() {
  return (
    <section className="grid grid-cols-1 xs:grid-cols-2 lg:grid-cols-4 gap-3 xs:gap-4">
      {banners.map((banner) => (
        <Link
          key={banner.title}
          href={banner.href}
          className={`group relative overflow-hidden rounded-xl p-5 sm:p-6 bg-gradient-to-br ${banner.bgGradient} text-white hover:shadow-2xl hover:-translate-y-1 transition-all duration-300 interactive`}
        >
          {/* Glow top-right */}
          <div
            className="absolute -top-6 -right-6 w-36 xs:w-44 h-36 xs:h-44 bg-white/15 rounded-full blur-2xl group-hover:scale-125 transition-transform duration-500"
            aria-hidden="true"
          />
          {/* Bottom highlight */}
          <div className="absolute bottom-0 left-0 w-full h-1 bg-white/30" aria-hidden="true" />

          <div className="relative">
            <div className="flex items-center gap-2 mb-3">
              {/* SVG flag — replaces emoji flag */}
              <div className="rounded overflow-hidden ring-2 ring-white/40 shadow shrink-0">
                <FlagIcon code={banner.isoCode} size={32} />
              </div>
              <span className="text-2xl xs:text-3xl" aria-hidden="true">{banner.emoji}</span>
            </div>
            <h3 className="text-lg xs:text-xl font-extrabold mb-1 text-white">{banner.title}</h3>
            <p className="text-white/90 text-xs xs:text-sm font-medium mb-1">{banner.cities}</p>
            <p className="text-white/70 text-xs mb-4 hidden sm:block">{banner.subtitle}</p>

            <div className="inline-flex items-center gap-2 text-xs xs:text-sm font-bold bg-white/20 hover:bg-white/30 border border-white/30 text-white px-3 xs:px-4 py-1.5 xs:py-2 rounded-full transition-colors">
              ✦ {banner.cta}
              <svg className="w-3.5 h-3.5 xs:w-4 xs:h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
              </svg>
            </div>
          </div>
        </Link>
      ))}
    </section>
  );
}
