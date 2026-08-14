'use client';

import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { Listing, Currency } from '@/lib/types';
import { convertToUSD, convertCurrency } from '@/lib/utils';
import { useCountry } from '@/context/CountryContext';

export interface CartItemVariants {
  /** Selected colour option, e.g. "Black" */
  color?:     string;
  /** Selected size option, e.g. "M" */
  size?:      string;
  /** Any additional listing-specific attributes (key → value) */
  attributes?: Record<string, string>;
}

export interface CartItem {
  listing:   Listing;
  quantity:  number;
  /** Variant / option selections the buyer made on the listing detail page */
  variants?: CartItemVariants;
}

interface CartContextType {
  items: CartItem[];
  addToCart: (listing: Listing, variants?: CartItemVariants) => void;
  removeFromCart: (listingId: string) => void;
  updateQuantity: (listingId: string, quantity: number) => void;
  clearCart: () => void;
  totalItems: number;
  totalPrice: number;
  conversionInfo: { from: Currency; to: Currency; at: number; auto?: boolean } | null;
  clearConversionInfo: () => void;
}

const CartContext = createContext<CartContextType | undefined>(undefined);

export function CartProvider({ children }: { children: React.ReactNode }) {
  const [items, setItems] = useState<CartItem[]>([]);
  const { currency: selectedCurrency, lastSelection } = useCountry();
  const [conversionInfo, setConversionInfo] = useState<{ from: Currency; to: Currency; at: number; auto?: boolean } | null>(null);

  useEffect(() => {
    try {
      const saved = localStorage.getItem('cart');
      if (saved) setItems(JSON.parse(saved));
    } catch {
      // ignore malformed data
    }
  }, []);

  const persist = useCallback((next: CartItem[]) => {
    setItems(next);
    localStorage.setItem('cart', JSON.stringify(next));
  }, []);

  const addToCart = useCallback((listing: Listing, variants?: CartItemVariants) => {
    setItems((prev) => {
      // Ensure the listing stored in cart uses the currently selected currency
      const listingToStore = listing.currency === selectedCurrency
        ? listing
        : { ...listing, price: convertCurrency(listing.price, listing.currency, selectedCurrency), currency: selectedCurrency };

      // If we converted the listing on add, record conversion info
      if (listing.currency !== selectedCurrency) {
        setConversionInfo({ from: listing.currency, to: selectedCurrency, at: Date.now(), auto: lastSelection === 'auto' });
      }

      // Match on listing id + variant fingerprint so the same item with
      // different options creates separate cart lines (proper logistics)
      const variantKey = variants
        ? JSON.stringify({ color: variants.color, size: variants.size, ...variants.attributes })
        : '';

      const existing = prev.find(
        (i) => i.listing.id === listingToStore.id &&
               JSON.stringify({ color: i.variants?.color, size: i.variants?.size, ...i.variants?.attributes }) === variantKey
      );

      const next = existing
        ? prev.map((i) =>
            i.listing.id === listingToStore.id &&
            JSON.stringify({ color: i.variants?.color, size: i.variants?.size, ...i.variants?.attributes }) === variantKey
              ? { ...i, quantity: i.quantity + 1 }
              : i
          )
        : [...prev, { listing: listingToStore, quantity: 1, variants }];

      localStorage.setItem('cart', JSON.stringify(next));
      return next;
    });
  }, [selectedCurrency, lastSelection]);

  const removeFromCart = useCallback((listingId: string) => {
    persist(items.filter((i) => i.listing.id !== listingId));
  }, [items, persist]);

  const updateQuantity = useCallback((listingId: string, quantity: number) => {
    if (quantity < 1) {
      persist(items.filter((i) => i.listing.id !== listingId));
    } else {
      persist(items.map((i) => i.listing.id === listingId ? { ...i, quantity } : i));
    }
  }, [items, persist]);

  const clearCart = useCallback(() => {
    persist([]);
  }, [persist]);

  const totalItems = items.reduce((sum, i) => sum + i.quantity, 0);
  const totalPrice = items.reduce(
    (sum, i) => sum + convertToUSD(i.listing.price, i.listing.currency) * i.quantity,
    0,
  );

  // When the selected country (and therefore currency) changes, convert any cart items
  useEffect(() => {
    if (!selectedCurrency) return;
    setItems((prev) => {
      const differing = Array.from(new Set(prev.map((i) => i.listing.currency))).filter((c) => c !== selectedCurrency);
      const next = prev.map((i) => {
        if (i.listing.currency === selectedCurrency) return i;
        const converted = convertCurrency(i.listing.price, i.listing.currency, selectedCurrency);
        return { ...i, listing: { ...i.listing, price: converted, currency: selectedCurrency } };
      });
      try { localStorage.setItem('cart', JSON.stringify(next)); } catch {}
      if (differing.length > 0) {
        setConversionInfo({ from: differing[0] as Currency, to: selectedCurrency, at: Date.now(), auto: lastSelection === 'auto' });
      }
      return next;
    });
  }, [selectedCurrency]);

  const clearConversionInfo = useCallback(() => setConversionInfo(null), []);

  return (
    <CartContext.Provider value={{ items, addToCart, removeFromCart, updateQuantity, clearCart, totalItems, totalPrice, conversionInfo, clearConversionInfo }}>
      {children}
    </CartContext.Provider>
  );
}

export function useCart() {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error('useCart must be used within CartProvider');
  return ctx;
}
