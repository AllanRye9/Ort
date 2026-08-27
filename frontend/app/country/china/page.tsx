// Uganda-only launch: the China storefront is disabled (404) rather than
// deleted, so it can be restored later by uncommenting the block below and
// removing the notFound() call.
import { notFound } from 'next/navigation';

export default function ChinaPage() {
  notFound();
}

// import type { Metadata } from 'next';
// import CountryLandingClient from '../CountryLandingClient';
//
// export const metadata: Metadata = {
//   title: 'Piitrade — China Marketplace',
//   description: 'Browse all listings available in China on Piitrade.',
// };
//
// export default function ChinaPage() {
//   return <CountryLandingClient country="CHINA" />;
// }
