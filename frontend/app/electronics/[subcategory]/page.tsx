import BrandsPageTemplate from '@/components/ui/BrandsPageTemplate';
import {
  ELECTRONICS_SUBCATEGORIES,
  ELECTRONICS_BRANDS_BY_SUBCATEGORY,
} from '../config';

export default function ElectronicsSubcategoryPage() {
  return (
    <BrandsPageTemplate
      subcategories={ELECTRONICS_SUBCATEGORIES}
      brandsBySubcategory={ELECTRONICS_BRANDS_BY_SUBCATEGORY}
      basePath="/electronics"
      categoryLabel="Electronics"
      categoryHref="/electronics"
    />
  );
}
