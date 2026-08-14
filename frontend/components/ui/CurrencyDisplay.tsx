import { formatCurrency, convertCurrency } from '@/lib/utils';
import { Currency } from '@/lib/types';

interface Props {
  amount: number;
  currency: Currency;
  /** When provided, converts and shows the price in this currency instead */
  displayCurrency?: Currency;
  className?: string;
  /** Show the original currency label in smaller text when conversion is active */
  showOriginal?: boolean;
}

export function CurrencyDisplay({
  amount,
  currency,
  displayCurrency,
  className = '',
  showOriginal = false,
}: Props) {
  if (!displayCurrency || displayCurrency === currency) {
    return <span className={className}>{formatCurrency(amount, currency)}</span>;
  }

  const converted = convertCurrency(amount, currency, displayCurrency);
  return (
    <span className={className}>
      {formatCurrency(converted, displayCurrency)}
      {showOriginal && (
        <span className="ml-1 text-[0.7em] opacity-60 font-normal">
          ≈ {formatCurrency(amount, currency)}
        </span>
      )}
    </span>
  );
}
