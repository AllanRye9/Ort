import BrandListingsTemplate from '@/components/ui/BrandListingsTemplate';
import {
  ELECTRONICS_SUBCATEGORIES,
  ELECTRONICS_BRANDS_BY_SUBCATEGORY,
  ELECTRONICS_PRICE_RANGES,
} from '../../config';

export default function ElectronicsBrandPage() {
  return (
    <BrandListingsTemplate
      subcategories={ELECTRONICS_SUBCATEGORIES}
      brandsBySubcategory={ELECTRONICS_BRANDS_BY_SUBCATEGORY}
      basePath="/electronics"
      categoryLabel="Electronics"
      categoryHref="/electronics"
      priceRanges={ELECTRONICS_PRICE_RANGES}
    />
  );
}
