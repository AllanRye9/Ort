'use client';

import Link from 'next/link';
import { API_URL, api } from '@/lib/api';
import Image from 'next/image';
import { useEffect, useState } from 'react';
import { useCountry } from '@/context/CountryContext';
import { resolveImageUrl } from '@/lib/utils';

// ── CV Package (admin-governed pricing) ─────────────────────────────────────────
// This hub page never hardcodes a price. It mirrors the CV builder itself:
// the amount shown here is fetched from /cv-payment/active-package, which is
// sourced solely from whichever CV-scope SellerPackage the admin currently
// has active. If no package is active (or it has expired), there is nothing
// to charge, so the price line is omitted rather than showing a stale number.
interface ActiveCvPackagePrice {
  configured: boolean;
  isFree: boolean;
  price: { amount: number; currency: string } | null;
}

interface CVSampleImage {
  id: string;
  cdnUrl: string;
  title?: string | null;
  altText?: string | null;
  linkUrl?: string | null;
}

// ── Two core categories ────────────────────────────────────────────────────────
const CATEGORIES = [
  {
    id:    'cv',
    href:  '/cv-generator/builder',
    icon:  '&#x1F4C4;',
    title: 'CV / Resume',
    desc:  'Build your CV with live preview. Pay only when you download.',
    badge: 'Most Popular',
    badgeColor: 'bg-sky-100 text-sky-700',
    gradient: 'from-sky-500 to-blue-600',
    cta:   'Start Building',
  },
  {
    id:    'documents',
    href:  '/cv-generator/cover-letter',
    icon:  '&#x1F4CB;',
    title: 'Documents & Cover Letters',
    desc:  'Write a tailored cover letter with live preview. Pay only when you download.',
    badge: null,
    badgeColor: '',
    gradient: 'from-emerald-500 to-teal-600',
    cta:   'Start Building',
  },
];

const SUPPORT_LINKS = [
  { href: '/cv-services/writing',      icon: '&#x270D;',  label: 'Professional CV Writing' },
  { href: '/cv-services/interview',    icon: '&#x1F3A4;', label: 'Interview Prep' },
];

export default function CVGeneratorHub() {
  const { country } = useCountry();
  const [sampleImages, setSampleImages] = useState<CVSampleImage[]>([]);
  const [pkg, setPkg] = useState<ActiveCvPackagePrice | null>(null);

  useEffect(() => {
    fetch(`${API_URL}/api/site-media?section=cv-generator`)
      .then((r) => r.ok ? r.json() : null)
      .then((d: { media?: CVSampleImage[] } | null) => {
        if (d?.media?.length) setSampleImages(d.media.slice(0, 6));
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    let cancelled = false;
    api.get('/cv-payment/active-package', { params: { country } })
      .then(({ data }) => { if (!cancelled) setPkg(data as ActiveCvPackagePrice); })
      .catch((err) => {
        // Same philosophy as the builder: don't silently pretend pricing is
        // unavailable when it's actually a failed request — just log it and
        // fall back to omitting the price line below.
        console.error('[cv-generator] failed to load active CV package:', err?.response?.status, err?.message);
        if (!cancelled) setPkg(null);
      });
    return () => { cancelled = true; };
  }, [country]);

  const price = pkg?.configured && pkg.price ? pkg.price : null;
  const isFreePackage = !!pkg?.isFree;

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-white to-sky-50">
      <div className="max-w-4xl mx-auto px-4 pt-5 pb-8">

        {/* Breadcrumb */}
        <nav className="flex items-center gap-2 text-xs text-gray-400 mb-4">
          <Link href="/" className="hover:text-gray-600">Home</Link>
          <span>/</span>
          <span className="text-gray-700 font-medium">CV &amp; Documents</span>
        </nav>

        {/* Hero */}
        <div className="bg-gradient-to-br from-sky-600 to-blue-700 rounded-2xl sm:rounded-3xl p-4 sm:p-6 text-white mb-4 shadow-xl">
          <span className="inline-flex items-center gap-1.5 bg-white/15 text-xs font-bold px-3 py-1.5 rounded-full mb-3">
            <span className="text-sm">&#x2728;</span> CV, Certificates &amp; Documents
          </span>
          <h1 className="text-xl sm:text-3xl font-black mb-1.5">Build. Preview. Download.</h1>
          <p className="text-white/80 text-xs sm:text-sm max-w-lg">
            {isFreePackage ? (
              <>Create your CV completely free with live preview, and download it{' '}
                <strong className="text-yellow-300">free of charge</strong>. No subscription needed.</>
            ) : price ? (
              <>Create your CV completely free with live preview. Pay just{' '}
                <strong className="text-yellow-300">{price.amount} {price.currency}</strong>{' '}
                when you&apos;re ready to download. No subscription needed.</>
            ) : (
              <>Create your CV completely free with live preview. Downloads are{' '}
                <strong className="text-yellow-300">temporarily unavailable</strong> while pricing is configured.</>
            )}
          </p>
          <Link href="/cv-generator/builder"
            className="mt-3 inline-flex items-center gap-2 bg-white text-sky-700 font-bold px-5 py-2 rounded-xl hover:bg-sky-50 transition-all shadow-md text-sm">
            <span className="text-base">&#x1F4C4;</span> Start Building My CV
          </Link>
        </div>

        {/* CV Samples — admin-uploaded, at least 3 clearly visible per row without scrolling */}
        {sampleImages.length > 0 && (
          <section className="mb-4">
            <h2 className="text-sm font-bold text-gray-700 mb-2 uppercase tracking-wider">CV Samples</h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2.5">
              {sampleImages.map((img) => {
                const frame = (
                  <div className="group relative aspect-[3/4] overflow-hidden rounded-xl border border-gray-100 shadow-sm bg-white">
                    <Image
                      src={resolveImageUrl(img.cdnUrl)}
                      alt={img.altText || img.title || 'CV sample'}
                      fill
                      className="object-cover transition-transform duration-300 group-hover:scale-105"
                      sizes="(max-width: 640px) 50vw, 33vw"
                      quality={75}
                      loading="lazy"
                    />
                    {img.title && (
                      <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/60 to-transparent px-2 py-1.5">
                        <p className="text-[11px] font-semibold text-white truncate">{img.title}</p>
                      </div>
                    )}
                  </div>
                );
                return img.linkUrl ? (
                  <Link key={img.id} href={img.linkUrl}>{frame}</Link>
                ) : (
                  <div key={img.id}>{frame}</div>
                );
              })}
            </div>
          </section>
        )}

        {/* CV & Cover Letter categories */}
        <h2 className="text-base sm:text-lg font-bold text-gray-900 mb-2">CV, Certificates &amp; Documents</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-4">
          {CATEGORIES.map(cat => (
            <Link key={cat.id} href={cat.href}
              className="group bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all overflow-hidden flex flex-col">
              <div className={`bg-gradient-to-br ${cat.gradient} p-3 text-white`}>
                <div className="flex items-center justify-between">
                  <span className="text-2xl sm:text-3xl" dangerouslySetInnerHTML={{ __html: cat.icon }}/>
                  {cat.badge && (
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${cat.badgeColor} bg-white`}>{cat.badge}</span>
                  )}
                </div>
              </div>
              <div className="p-3 flex flex-col flex-1">
                <h3 className="font-bold text-gray-900 text-sm mb-1">{cat.title}</h3>
                <p className="text-xs text-gray-500 flex-1 leading-relaxed">{cat.desc}</p>
                <span className="mt-2 text-xs font-semibold text-sky-600 group-hover:underline">{cat.cta} &#8594;</span>
              </div>
            </Link>
          ))}
        </div>

        {/* How it works */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4 sm:p-5 mb-4">
          <h2 className="font-bold text-gray-900 mb-3 text-sm sm:text-base">How the CV Builder Works</h2>
          <ol className="space-y-2.5">
            {[
              { step: '1', icon: '&#x270F;',  title: 'Fill in your details', desc: 'Add your personal info, work history, education, and skills.' },
              { step: '2', icon: '&#x1F441;', title: 'Preview live',          desc: 'Watch your CV update in real-time. Edit until it looks perfect.' },
              { step: '3', icon: '&#x1F4B3;', title: 'Pay to download',       desc: isFreePackage
                  ? 'Free download — no payment required.'
                  : price
                    ? `One-time ${price.amount} ${price.currency}. Payment verified server-side before download unlocks.`
                    : 'Download pricing is set by the admin and will appear here once configured.' },
              { step: '4', icon: '&#x2B07;',  title: 'Download instantly',    desc: 'Your CV downloads immediately after payment confirmation.' },
            ].map(item => (
              <li key={item.step} className="flex items-start gap-3">
                <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-sky-100 text-sky-700 font-black text-xs flex items-center justify-center shrink-0">
                  {item.step}
                </div>
                <div>
                  <p className="font-semibold text-gray-900 text-xs sm:text-sm" dangerouslySetInnerHTML={{ __html: `${item.icon} ${item.title}` }}/>
                  <p className="text-[11px] sm:text-xs text-gray-500 mt-0.5">{item.desc}</p>
                </div>
              </li>
            ))}
          </ol>
          <div className="mt-4 pt-3 border-t border-gray-100">
            <Link href="/cv-generator/builder"
              className="inline-flex items-center gap-2 bg-sky-600 text-white font-bold px-5 py-2.5 rounded-xl hover:bg-sky-700 transition-all text-sm">
              Start Now &#8594;
            </Link>
          </div>
        </div>

        {/* Additional CV services */}
        <h2 className="text-sm font-bold text-gray-700 mb-2 uppercase tracking-wider">More Services</h2>
        <div className="grid grid-cols-2 gap-2.5">
          {SUPPORT_LINKS.map(link => (
            <Link key={link.href} href={link.href}
              className="bg-white border border-gray-100 rounded-xl p-3 text-center hover:border-sky-200 hover:shadow-sm transition-all group">
              <div className="text-2xl mb-1.5" dangerouslySetInnerHTML={{ __html: link.icon }}/>
              <p className="text-xs font-semibold text-gray-700 group-hover:text-sky-600 leading-tight">{link.label}</p>
            </Link>
          ))}
        </div>

        <div className="mt-5 bg-white rounded-2xl border border-gray-100 p-4 flex flex-wrap gap-4 items-center justify-between">
          <p className="text-sm text-gray-600">Looking for work?</p>
          <div className="flex gap-3">
            <Link href="/jobs" className="text-sm text-sky-600 hover:underline font-medium">Browse Jobs &#8594;</Link>
            <Link href="/profile" className="text-sm text-sky-600 hover:underline font-medium">Update Profile &#8594;</Link>
          </div>
        </div>
      </div>
    </div>
  );
}
