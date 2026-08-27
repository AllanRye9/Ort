'use client';

/**
 * /admin/commodity-prices
 *
 * Manages the "Uganda Market Price Watch" data shown in the homepage widget
 * (components/ui/CommodityPriceWidget.tsx, rendered from SiteAnalytics.tsx)
 * and the full /market-prices page. Three ways to update prices, all
 * converging on the same backend store (see routes/commodityPrices.ts):
 *   1. Manual table — edit rows directly, "Save All" replaces the whole set.
 *   2. JSON paste — paste an array of { name, unit, price, ... } objects.
 *   3. File upload — .csv or .json file, same shape as the JSON paste.
 * Paths 2 and 3 merge into existing data (upsert); path 1 is a full replace,
 * matching how /admin/currency-rates' "Save & Go Live" already behaves.
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { api } from '@/lib/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface CommodityRow {
  id: string;
  name: string;
  unit: string;
  price: string; // kept as string while editing, like currency-rates' RateRow
  previousPrice: number | null;
  marketType: 'RETAIL' | 'WHOLESALE';
  location: string;
  updatedAt: string;
}

const SUGGESTED_COMMODITIES = [
  { name: 'Sugar', unit: 'kg' },
  { name: 'Coffee', unit: 'kg (beans)' },
  { name: 'Cement', unit: 'bag (50kg)' },
  { name: 'Beans', unit: 'kg' },
  { name: 'Maize Flour', unit: 'kg' },
  { name: 'Rice', unit: 'kg' },
  { name: 'Cooking Oil', unit: 'litre' },
  { name: 'Salt', unit: 'kg' },
  { name: 'Milk', unit: 'litre' },
  { name: 'Charcoal', unit: 'bag (50kg)' },
  { name: 'Electricity', unit: 'kWh' },
  { name: 'Petrol', unit: 'litre' },
  { name: 'Diesel', unit: 'litre' },
];

const JSON_PLACEHOLDER = `[
  { "name": "Sugar", "unit": "kg", "price": 4600, "marketType": "RETAIL", "location": "Kampala" },
  { "name": "Cement", "unit": "bag (50kg)", "price": 39000, "marketType": "WHOLESALE", "location": "Jinja" }
]`;

function emptyRow(): CommodityRow {
  return { id: '', name: '', unit: '', price: '', previousPrice: null, marketType: 'RETAIL', location: '', updatedAt: '' };
}

function isRowValid(row: CommodityRow): boolean {
  return row.name.trim() !== '' && row.unit.trim() !== '' && !isNaN(parseFloat(row.price)) && parseFloat(row.price) >= 0;
}

// ── Main page ─────────────────────────────────────────────────────────────────

export default function CommodityPricesAdminPage() {
  const { user, loading: authLoading } = useAuth();
  const router = useRouter();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [rows, setRows] = useState<CommodityRow[]>([]);
  const [fetching, setFetching] = useState(true);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [lastUpdated, setLastUpdated] = useState('');
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null);
  const [jsonPaste, setJsonPaste] = useState('');
  const [mode, setMode] = useState<'table' | 'json' | 'file'>('table');

  useEffect(() => {
    if (!authLoading && (!user || user.role !== 'ADMIN')) {
      router.replace('/admin/auth/login');
    }
  }, [user, authLoading, router]);

  const showToast = (msg: string, ok: boolean) => {
    setToast({ msg, ok });
    setTimeout(() => setToast(null), 4000);
  };

  const fetchPrices = useCallback(async () => {
    setFetching(true);
    try {
      const { data } = await api.get('/commodity-prices');
      if (Array.isArray(data.items)) {
        setRows(
          data.items.map((i: { id: string; name: string; unit: string; price: number; previousPrice: number | null; marketType: 'RETAIL' | 'WHOLESALE'; location: string | null; updatedAt: string }) => ({
            id: i.id,
            name: i.name,
            unit: i.unit,
            price: String(i.price),
            previousPrice: i.previousPrice,
            marketType: i.marketType,
            location: i.location || '',
            updatedAt: i.updatedAt,
          })),
        );
        setLastUpdated(data.updatedAt ?? '');
      }
    } catch {
      showToast('Failed to load commodity prices', false);
    } finally {
      setFetching(false);
    }
  }, []);

  useEffect(() => { fetchPrices(); }, [fetchPrices]);

  // ── Table row handlers ────────────────────────────────────────────────────
  const updateField = (idx: number, field: 'name' | 'unit' | 'price' | 'location', value: string) => {
    setRows((prev) => {
      const next = [...prev];
      next[idx] = { ...next[idx], [field]: value };
      return next;
    });
  };

  const updateMarketType = (idx: number, value: 'RETAIL' | 'WHOLESALE') => {
    setRows((prev) => {
      const next = [...prev];
      next[idx] = { ...next[idx], marketType: value };
      return next;
    });
  };

  const addRow = () => setRows((prev) => [...prev, emptyRow()]);
  const removeRow = (idx: number) => setRows((prev) => prev.filter((_, i) => i !== idx));

  const quickAdd = (name: string, unit: string) => {
    if (rows.some((r) => r.name.toLowerCase() === name.toLowerCase())) {
      showToast(`${name} is already in the list`, false);
      return;
    }
    setRows((prev) => [...prev, { ...emptyRow(), name, unit }]);
  };

  const handleSaveTable = async () => {
    const valid = rows.filter(isRowValid);
    if (valid.length === 0) {
      showToast('Add at least one valid commodity before saving', false);
      return;
    }
    setSaving(true);
    try {
      const { data } = await api.put('/commodity-prices', {
        currency: 'UGX',
        items: valid.map((r) => ({
          id: r.id || undefined,
          name: r.name.trim(),
          unit: r.unit.trim(),
          price: parseFloat(r.price),
          marketType: r.marketType,
          location: r.location.trim() || undefined,
        })),
      });
      showToast(`✓ Saved ${valid.length} price${valid.length !== 1 ? 's' : ''} — live on site`, true);
      if (Array.isArray(data?.warnings) && data.warnings.length) {
        showToast(`Saved, but ${data.warnings.length} row(s) were skipped — check for missing name/unit/price`, false);
      }
      await fetchPrices();
    } catch {
      showToast('Save failed — please try again', false);
    } finally {
      setSaving(false);
    }
  };

  // ── JSON paste ────────────────────────────────────────────────────────────
  const handleSubmitJson = async () => {
    let parsed: unknown;
    try {
      parsed = JSON.parse(jsonPaste);
    } catch {
      showToast('That is not valid JSON — check for a trailing comma or missing bracket', false);
      return;
    }
    const items = Array.isArray(parsed) ? parsed : (parsed as { items?: unknown })?.items;
    if (!Array.isArray(items) || items.length === 0) {
      showToast('Expected a JSON array of items, or an object with an "items" array', false);
      return;
    }

    setSaving(true);
    try {
      const { data } = await api.post('/commodity-prices/bulk', { items });
      showToast(`✓ Updated ${data.updated} price${data.updated !== 1 ? 's' : ''} from pasted JSON`, true);
      if (Array.isArray(data?.warnings) && data.warnings.length) {
        showToast(`${data.warnings.length} row(s) were skipped: ${data.warnings[0]}`, false);
      }
      setJsonPaste('');
      setMode('table');
      await fetchPrices();
    } catch (err) {
      const message = (err as { response?: { data?: { error?: string } } })?.response?.data?.error;
      showToast(message || 'Failed to apply pasted JSON', false);
    } finally {
      setSaving(false);
    }
  };

  // ── File upload (.csv or .json) ───────────────────────────────────────────
  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      const formData = new FormData();
      formData.append('file', file);
      const { data } = await api.post('/commodity-prices/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      showToast(`✓ Updated ${data.updated} price${data.updated !== 1 ? 's' : ''} from ${file.name}`, true);
      if (Array.isArray(data?.warnings) && data.warnings.length) {
        showToast(`${data.warnings.length} row(s) were skipped: ${data.warnings[0]}`, false);
      }
      await fetchPrices();
    } catch (err) {
      const message = (err as { response?: { data?: { error?: string } } })?.response?.data?.error;
      showToast(message || 'Upload failed', false);
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const handleDeleteRow = async (row: CommodityRow) => {
    if (!row.id) {
      // Never-saved local row — just remove it from the table, nothing to delete server-side.
      setRows((prev) => prev.filter((r) => r !== row));
      return;
    }
    if (!confirm(`Remove "${row.name}" from the price list?`)) return;
    try {
      await api.delete(`/commodity-prices/${row.id}`);
      showToast(`Removed ${row.name}`, true);
      await fetchPrices();
    } catch {
      showToast('Failed to remove item', false);
    }
  };

  if (authLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="w-8 h-8 border-4 border-emerald-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 py-8">
      {toast && (
        <div className={`fixed top-4 right-4 z-50 px-5 py-3 rounded-xl shadow-xl text-sm font-semibold text-white transition-all ${toast.ok ? 'bg-emerald-600' : 'bg-red-600'}`}>
          {toast.msg}
        </div>
      )}

      {/* Page header */}
      <div className="mb-6 flex items-start gap-4">
        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center text-2xl shadow-md shrink-0">
          🌾
        </div>
        <div>
          <h1 className="text-2xl font-black text-gray-900">Uganda Market Price Watch</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            Manage the commodity prices shown in the homepage widget and on <code className="bg-gray-100 px-1 rounded">/market-prices</code>.
            Prices are in <strong>UGX</strong>. The trend arrow is computed automatically from each item&apos;s previous price whenever you change it.
          </p>
          {lastUpdated && (
            <p className="text-xs text-gray-400 mt-1">Last saved: {new Date(lastUpdated).toLocaleString('en-US')}</p>
          )}
        </div>
      </div>

      {/* Mode switcher */}
      <div className="flex gap-2 mb-5 border-b border-gray-200">
        {([
          ['table', '📋 Manual Table'],
          ['json', '{ } JSON Paste'],
          ['file', '📁 CSV / JSON Upload'],
        ] as const).map(([key, label]) => (
          <button
            key={key}
            onClick={() => setMode(key)}
            className={`px-4 py-2.5 text-sm font-semibold border-b-2 -mb-px transition-colors ${
              mode === key ? 'border-emerald-600 text-emerald-700' : 'border-transparent text-gray-400 hover:text-gray-600'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {mode === 'table' && (
        <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
          {/* ── LEFT: editor table ── */}
          <div className="lg:col-span-3 space-y-4">
            <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
              <div className="flex items-center justify-between px-5 py-3 bg-gray-50 border-b border-gray-200">
                <h2 className="font-bold text-gray-800 text-sm">
                  Commodities
                  <span className="ml-2 text-xs font-normal text-gray-400">({rows.filter(isRowValid).length} valid)</span>
                </h2>
                <button
                  onClick={addRow}
                  className="flex items-center gap-1.5 text-xs font-semibold text-emerald-600 hover:text-emerald-700 px-3 py-1.5 rounded-lg border border-emerald-200 hover:bg-emerald-50 transition-colors"
                >
                  <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M12 4v16m8-8H4" /></svg>
                  Add Row
                </button>
              </div>

              {fetching ? (
                <div className="p-10 text-center">
                  <div className="w-8 h-8 border-4 border-emerald-400 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
                  <p className="text-sm text-gray-400">Loading prices…</p>
                </div>
              ) : (
                <div className="divide-y divide-gray-50">
                  {rows.length === 0 && (
                    <p className="px-5 py-8 text-center text-sm text-gray-400">No commodities yet. Add a row, or pick a suggestion →</p>
                  )}
                  {rows.map((row, idx) => {
                    const invalid = (row.name !== '' || row.unit !== '' || row.price !== '') && !isRowValid(row);
                    return (
                      <div key={idx} className={`px-4 py-3 space-y-2 ${invalid ? 'bg-red-50/40' : 'hover:bg-gray-50/60'}`}>
                        <div className="flex gap-2 items-start">
                          <div className="flex-1 min-w-0">
                            <label className="text-[9px] font-bold text-gray-400 uppercase tracking-wider mb-0.5 block">Commodity</label>
                            <input
                              type="text"
                              value={row.name}
                              onChange={(e) => updateField(idx, 'name', e.target.value)}
                              placeholder="e.g. Sugar"
                              className="w-full text-sm border border-gray-200 rounded-lg px-2.5 py-1.5 focus:outline-none focus:ring-2 focus:ring-emerald-400"
                            />
                          </div>
                          <div className="w-28 shrink-0">
                            <label className="text-[9px] font-bold text-gray-400 uppercase tracking-wider mb-0.5 block">Unit</label>
                            <input
                              type="text"
                              value={row.unit}
                              onChange={(e) => updateField(idx, 'unit', e.target.value)}
                              placeholder="kg, bag, litre…"
                              className="w-full text-sm border border-gray-200 rounded-lg px-2.5 py-1.5 focus:outline-none focus:ring-2 focus:ring-emerald-400"
                            />
                          </div>
                          <div className="w-32 shrink-0">
                            <label className="text-[9px] font-bold text-gray-400 uppercase tracking-wider mb-0.5 block">Price (UGX)</label>
                            <input
                              type="number"
                              value={row.price}
                              onChange={(e) => updateField(idx, 'price', e.target.value)}
                              placeholder="4500"
                              min="0"
                              step="any"
                              className={`w-full text-sm font-mono font-bold border rounded-lg px-2.5 py-1.5 focus:outline-none focus:ring-2 ${
                                row.price && (isNaN(parseFloat(row.price)) || parseFloat(row.price) < 0)
                                  ? 'border-red-300 bg-red-50 focus:ring-red-400'
                                  : 'border-gray-200 focus:ring-emerald-400'
                              }`}
                            />
                          </div>
                          <button
                            onClick={() => handleDeleteRow(row)}
                            aria-label={`Remove ${row.name || 'row'}`}
                            className="mt-5 p-1.5 text-gray-300 hover:text-red-500 transition-colors rounded"
                          >
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                          </button>
                        </div>

                        <div className="flex gap-2">
                          <div className="flex-1">
                            <label className="text-[9px] font-bold text-gray-400 uppercase tracking-wider mb-0.5 block">Location <span className="normal-case font-normal text-gray-300">(optional)</span></label>
                            <input
                              type="text"
                              value={row.location}
                              onChange={(e) => updateField(idx, 'location', e.target.value)}
                              placeholder="Kampala, Jinja, Gulu… (blank = national)"
                              className="w-full text-xs border border-gray-200 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-emerald-400"
                            />
                          </div>
                          <div className="w-36">
                            <label className="text-[9px] font-bold text-gray-400 uppercase tracking-wider mb-0.5 block">Market Type</label>
                            <select
                              value={row.marketType}
                              onChange={(e) => updateMarketType(idx, e.target.value as 'RETAIL' | 'WHOLESALE')}
                              className="w-full text-xs border border-gray-200 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-emerald-400 bg-white"
                            >
                              <option value="RETAIL">Retail</option>
                              <option value="WHOLESALE">Wholesale</option>
                            </select>
                          </div>
                        </div>

                        {row.previousPrice != null && row.previousPrice !== parseFloat(row.price) && !isNaN(parseFloat(row.price)) && (
                          <p className="text-[10px] text-amber-600">
                            Was UGX {row.previousPrice.toLocaleString('en-UG')} — trend arrow will update on save.
                          </p>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            <div className="flex items-center justify-between gap-4">
              <button onClick={addRow} className="flex items-center gap-1.5 text-sm text-emerald-600 font-semibold hover:text-emerald-700 transition-colors">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M12 4v16m8-8H4" /></svg>
                Add empty row
              </button>
              <button
                onClick={handleSaveTable}
                disabled={saving || fetching}
                className="flex items-center gap-2 px-6 py-2.5 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 disabled:opacity-50 text-white font-bold text-sm rounded-xl shadow-lg hover:shadow-xl transition-all active:scale-95"
              >
                {saving ? (
                  <><div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" /> Saving…</>
                ) : (
                  <><svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" /></svg> Save &amp; Go Live</>
                )}
              </button>
            </div>

            <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 flex gap-3">
              <span className="text-lg shrink-0">💡</span>
              <p className="text-xs text-amber-800">
                <strong>Note:</strong> &quot;Save &amp; Go Live&quot; replaces the entire price list with exactly what&apos;s in this table — remove a row here and it disappears from the site too. For incremental updates without touching everything else, use JSON Paste or CSV/JSON Upload instead.
              </p>
            </div>
          </div>

          {/* ── RIGHT: suggested commodities ── */}
          <div className="lg:col-span-2">
            <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden sticky top-4">
              <div className="px-4 py-3 bg-gradient-to-r from-teal-600 to-emerald-600 text-white">
                <h2 className="font-bold text-sm">Suggested Commodities</h2>
                <p className="text-[11px] text-white/75 mt-0.5">Common Uganda market goods · click to add</p>
              </div>
              <div className="divide-y divide-gray-50">
                {SUGGESTED_COMMODITIES.map((c) => {
                  const added = rows.some((r) => r.name.toLowerCase() === c.name.toLowerCase());
                  return (
                    <button
                      key={c.name}
                      type="button"
                      onClick={() => !added && quickAdd(c.name, c.unit)}
                      disabled={added}
                      className={`w-full flex items-center justify-between px-4 py-2.5 text-left text-sm transition-colors ${
                        added ? 'opacity-50 cursor-not-allowed bg-gray-50' : 'hover:bg-emerald-50 hover:text-emerald-700'
                      }`}
                    >
                      <span>
                        <span className="font-semibold text-gray-800">{c.name}</span>
                        <span className="text-gray-400 ml-1.5 text-xs">per {c.unit}</span>
                      </span>
                      {added ? (
                        <span className="text-[9px] bg-emerald-100 text-emerald-700 px-1.5 py-0.5 rounded font-semibold">✓ Added</span>
                      ) : (
                        <span className="text-[9px] text-emerald-500 font-semibold">+ Add</span>
                      )}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        </div>
      )}

      {mode === 'json' && (
        <div className="max-w-3xl">
          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-5">
            <h2 className="font-bold text-gray-800 text-sm mb-1">Paste JSON</h2>
            <p className="text-xs text-gray-500 mb-3">
              Paste an array of commodity objects. Matches existing items by name + unit + market type + location (case-insensitive) and updates only those — everything else stays untouched.
            </p>
            <textarea
              value={jsonPaste}
              onChange={(e) => setJsonPaste(e.target.value)}
              placeholder={JSON_PLACEHOLDER}
              rows={14}
              spellCheck={false}
              className="w-full font-mono text-xs border border-gray-200 rounded-xl px-3 py-2.5 focus:outline-none focus:ring-2 focus:ring-emerald-400 bg-gray-50"
            />
            <div className="flex items-center justify-between mt-3">
              <p className="text-[11px] text-gray-400">Required: <code>name</code>, <code>unit</code>, <code>price</code>. Optional: <code>marketType</code> (defaults to RETAIL), <code>location</code>.</p>
              <button
                onClick={handleSubmitJson}
                disabled={saving || !jsonPaste.trim()}
                className="flex items-center gap-2 px-5 py-2 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 disabled:opacity-50 text-white font-bold text-sm rounded-xl shadow transition-all active:scale-95"
              >
                {saving ? 'Applying…' : 'Apply JSON'}
              </button>
            </div>
          </div>
        </div>
      )}

      {mode === 'file' && (
        <div className="max-w-3xl">
          <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-5">
            <h2 className="font-bold text-gray-800 text-sm mb-1">Upload CSV or JSON</h2>
            <p className="text-xs text-gray-500 mb-4">
              Same matching behaviour as JSON Paste — this merges into the existing list, it doesn&apos;t replace it.
              CSV columns (header row required, any order): <code>name</code>, <code>unit</code>, <code>price</code>, <code>marketType</code> <span className="text-gray-400">(optional)</span>, <code>location</code> <span className="text-gray-400">(optional)</span>.
            </p>

            <div
              className="flex flex-col items-center justify-center p-8 rounded-xl border-2 border-dashed border-gray-200 hover:border-emerald-400 bg-gray-50 hover:bg-emerald-50/40 cursor-pointer transition-all group"
              onClick={() => !uploading && fileInputRef.current?.click()}
            >
              {uploading ? (
                <>
                  <div className="w-8 h-8 border-4 border-emerald-400 border-t-transparent rounded-full animate-spin mb-2" />
                  <p className="text-sm font-medium text-gray-700">Uploading…</p>
                </>
              ) : (
                <>
                  <div className="w-12 h-12 rounded-full bg-emerald-100 group-hover:bg-emerald-200 flex items-center justify-center text-2xl mb-2 transition-colors">📁</div>
                  <p className="text-sm font-medium text-gray-700">Click to select a .csv or .json file</p>
                  <p className="text-xs text-gray-400 mt-0.5">Max 2 MB</p>
                </>
              )}
              <input
                ref={fileInputRef}
                type="file"
                accept=".csv,.json,text/csv,application/json"
                className="hidden"
                onChange={handleFileChange}
                disabled={uploading}
              />
            </div>

            <div className="mt-4 bg-gray-50 border border-gray-200 rounded-xl p-3">
              <p className="text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-1.5">Example CSV</p>
              <pre className="text-[10px] text-gray-500 font-mono overflow-x-auto">{`name,unit,price,marketType,location
Sugar,kg,4600,RETAIL,Kampala
Cement,bag (50kg),39000,WHOLESALE,Jinja`}</pre>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
