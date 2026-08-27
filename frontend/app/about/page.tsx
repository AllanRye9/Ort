import { ContentPage } from '@/components/ui/ContentPage';

export default function AboutPage() {
  return (
    <ContentPage
      eyebrow="About Piitrade"
      title="A marketplace built for trusted local trade"
      intro="Piitrade connects buyers and sellers across Uganda with fast discovery, local relevance, and clearer trust signals for every listing."
      sections={[
        {
          title: 'What we do',
          body: [
            'We make it easier to sell everyday goods, premium inventory, and in-demand local products without getting buried in cluttered classified experiences.',
            'The platform is designed around practical actions: list quickly, filter by region, contact sellers directly, and manage your account from one place.',
          ],
        },
        {
          title: 'Where we operate',
          body: [
            'Piitrade is currently focused on Uganda, with region-aware browsing that helps shoppers see listings relevant to their own area.',
            'That regional focus lets us keep the experience simpler and more useful than a generic global marketplace.',
          ],
        },
      ]}
      ctaHref="/listings/create"
      ctaLabel="Start selling"
    />
  );
}