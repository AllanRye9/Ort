import BrandListingsTemplate from '@/components/ui/BrandListingsTemplate';
import {
  FASHION_SUBCATEGORIES,
  FASHION_BRANDS_BY_SUBCATEGORY,
  FASHION_PRICE_RANGES,
} from '../../config';

export default function FashionBrandPage() {
  return (
    <BrandListingsTemplate
      subcategories={FASHION_SUBCATEGORIES}
      brandsBySubcategory={FASHION_BRANDS_BY_SUBCATEGORY}
      basePath="/fashion"
      categoryLabel="Fashion"
      categoryHref="/fashion"
      priceRanges={FASHION_PRICE_RANGES}
    />
  );
}
