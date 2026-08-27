// Uganda-only launch: the Kenya storefront is disabled (404) rather than
// deleted, so it can be restored later by uncommenting the block below and
// removing the notFound() call.
import { notFound } from 'next/navigation';

export default function KenyaPage() {
  notFound();
}

// import type { Metadata } from 'next';
// import CountryLandingClient from '../CountryLandingClient';
//
// export const metadata: Metadata = {
//   title: 'Piitrade — Kenya Marketplace',
//   description: 'Browse all listings available in Kenya on Piitrade.',
// };
//
// export default function KenyaPage() {
//   return <CountryLandingClient country="KENYA" />;
// }
