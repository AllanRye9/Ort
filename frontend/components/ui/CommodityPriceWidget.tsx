'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';

/* ─── Types ────────────────────────────────────────────────────────────────── */

interface CommodityItem {
  id: string;
  name: string;
  unit: string;
  price: number;
  previousPrice: number | null;
  marketType: 'RETAIL' | 'WHOLESALE';
  location: string | null;
}

/* ─── Helpers ──────────────────────────────────────────────────────────────── */

function formatUGX(value: number): string {
  return value.toLocaleString('en-UG', { maximumFractionDigits: value % 1 === 0 ? 0 : 2 });
}

function trend(item: CommodityItem): 'up' | 'down' | 'flat' {
  if (item.previousPrice == null || item.previousPrice === item.price) return 'flat';
  return item.price > item.previousPrice ? 'up' : 'down';
}

function shuffle<T>(arr: T[]): T[] {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

/* ─── PriceRow ─────────────────────────────────────────────────────────────── */

function PriceRow({ item }: { item: CommodityItem }) {
  const dir = trend(item);
  const changePct =
    item.previousPrice && item.previousPrice > 0
      ? (((item.price - item.previousPrice) / item.previousPrice) * 100).toFixed(1)
      : null;

  return (
    <div className="flex items-center justify-between gap-1 px-1.5 py-1 rounded-md hover:bg-gray-50 transition-colors">
      <div className="min-w-0">
        <p className="text-[9px] font-bold text-gray-700 truncate leading-tight">{item.name}</p>
        <p className="text-[7px] text-gray-400 leading-tight">per {item.unit}</p>
      </div>
      <div className="flex items-center gap-0.5 shrink-0">
        <span className="text-[9px] font-black text-gray-800 tabular-nums">{formatUGX(item.price)}</span>
        {dir === 'up' && (
          <span className="flex items-center text-emerald-600" aria-label="Price up">
            <svg className="w-2 h-2" fill="currentColor" viewBox="0 0 20 20"><path d="M10 3l6 8h-4v6H8v-6H4l6-8z" /></svg>
          </span>
        )}
        {dir === 'down' && (
          <span className="flex items-center text-red-600" aria-label="Price down">
            <svg className="w-2 h-2" fill="currentColor" viewBox="0 0 20 20"><path d="M10 17l-6-8h4V3h4v6h4l-6 8z" /></svg>
          </span>
        )}
        {dir === 'flat' && <span className="text-[8px] text-gray-300" aria-label="No change">–</span>}
      </div>
      {changePct && (
        <span className={`text-[7px] font-semibold shrink-0 w-8 text-right ${dir === 'up' ? 'text-emerald-600' : dir === 'down' ? 'text-red-600' : 'text-gray-300'}`}>
          {dir === 'up' ? '+' : ''}{changePct}%
        </span>
      )}
    </div>
  );
}

/* ─── CommodityPriceWidget ────────────────────────────────────────────────────
 *
 * Occupies the exact slot the old "3RELITE EXCHANGE · Money Transfer Rates"
 * currency widget used inside SiteAnalytics.tsx (same outer classes / rough
 * footprint — stat cards beside it are untouched). Shows 6 commodities at a
 * time, rotating through the full admin-managed list every 8s, each with a
 * trend arrow based on the last price change. Links out to /market-prices
 * for the full filterable table.
 */
export default function CommodityPriceWidget() {
  const [items, setItems] = useState<CommodityItem[]>([]);
  const [visible, setVisible] = useState<CommodityItem[]>([]);
  const [updatedAt, setUpdatedAt] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/commodity-prices')
      .then(({ data }: { data: { items?: CommodityItem[]; updatedAt?: string } }) => {
        if (data?.items?.length) {
          setItems(data.items);
          setVisible(shuffle(data.items).slice(0, 6));
          setUpdatedAt(data.updatedAt ?? null);
        }
      })
      .catch(() => { /* keep empty state on network failure */ })
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (items.length <= 6) { setVisible(items); return; }
    const ROTATE_INTERVAL_MS = 8_000;
    const timer = setInterval(() => setVisible(shuffle(items).slice(0, 6)), ROTATE_INTERVAL_MS);
    return () => clearInterval(timer);
  }, [items]);

  const left = visible.slice(0, 3);
  const right = visible.slice(3, 6);

  return (
    <div className="flex-1 min-w-0 bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
      {/* ── Header bar ── */}
      <div className="bg-white border-b border-gray-200 px-2 py-[5px] flex items-center flex-nowrap justify-between gap-1">
        <div className="flex items-center flex-nowrap gap-1.5 min-w-0">
          <span className="shrink-0 text-sm leading-none" aria-hidden="true">🇺🇬</span>
          <span className="text-[9px] font-black tracking-widest uppercase text-emerald-700 whitespace-nowrap">UGANDA MARKET PRICES</span>
          <span className="hidden xs:inline text-[7px] text-gray-500 uppercase tracking-wide whitespace-nowrap">· Market Price Watch</span>
        </div>
        <Link
          href="/market-prices"
          className="shrink-0 flex items-center gap-0.5 rounded px-1.5 py-0.5 text-[8px] font-black tracking-wide leading-none text-white bg-emerald-600 hover:bg-emerald-700 transition-colors"
        >
          VIEW ALL
        </Link>
      </div>

      {/* ── Body: left 3 | right 3, matching the old widget's row layout ── */}
      <div className="flex items-stretch divide-x divide-gray-100" style={{ minHeight: '88px' }}>
        {loading ? (
          <div className="flex-1 flex items-center justify-center py-4">
            <div className="w-4 h-4 border-2 border-emerald-400 border-t-transparent rounded-full animate-spin" />
          </div>
        ) : items.length === 0 ? (
          <div className="flex-1 flex flex-col items-center justify-center gap-1 py-3 text-center px-2">
            <p className="text-[9px] text-gray-400">Prices haven&apos;t been published yet.</p>
            <Link href="/market-prices" className="text-[8px] font-semibold text-emerald-600 hover:text-emerald-700">Browse Market Prices →</Link>
          </div>
        ) : (
          <>
            <div className="flex flex-col justify-center gap-px p-1 flex-1 min-w-0">
              {left.map((item) => <PriceRow key={item.id} item={item} />)}
            </div>
            <div className="flex flex-col justify-center gap-px p-1 flex-1 min-w-0">
              {right.map((item) => <PriceRow key={item.id} item={item} />)}
            </div>
          </>
        )}
      </div>

      {updatedAt && (
        <p className="px-2 py-0.5 text-[6px] text-gray-300 border-t border-gray-50">
          Updated {new Date(updatedAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
        </p>
      )}
    </div>
  );
}
