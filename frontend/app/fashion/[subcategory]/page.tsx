import BrandsPageTemplate from '@/components/ui/BrandsPageTemplate';
import {
  FASHION_SUBCATEGORIES,
  FASHION_BRANDS_BY_SUBCATEGORY,
} from '../config';

export default function FashionSubcategoryPage() {
  return (
    <BrandsPageTemplate
      subcategories={FASHION_SUBCATEGORIES}
      brandsBySubcategory={FASHION_BRANDS_BY_SUBCATEGORY}
      basePath="/fashion"
      categoryLabel="Fashion"
      categoryHref="/fashion"
    />
  );
}
