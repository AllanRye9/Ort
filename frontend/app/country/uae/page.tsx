// Uganda-only launch: the UAE storefront is disabled (404) rather than
// deleted, so it can be restored later by uncommenting the block below and
// removing the notFound() call.
import { notFound } from 'next/navigation';

export default function UAEPage() {
  notFound();
}

// import type { Metadata } from 'next';
// import CountryLandingClient from '../CountryLandingClient';
//
// export const metadata: Metadata = {
//   title: 'Piitrade — UAE Marketplace',
//   description: 'Browse all listings available in the UAE on Piitrade.',
// };
//
// export default function UAEPage() {
//   return <CountryLandingClient country="UAE" />;
// }
