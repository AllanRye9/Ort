"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const multer_1 = __importDefault(require("multer"));
const crypto_1 = require("crypto");
const jsonStore_1 = require("../utils/jsonStore");
const auth_1 = require("../middleware/auth");
const errorHandler_1 = require("../middleware/errorHandler");
const router = (0, express_1.Router)();
const COMMODITY_PRICES_PATH = 'data/commodity-prices.json';
const DEFAULT_COMMODITY_PRICES = {
    currency: 'UGX',
    items: [
        { id: (0, crypto_1.randomUUID)(), name: 'Sugar', unit: 'kg', price: 4500, previousPrice: 4300, marketType: 'RETAIL', location: 'Kampala', updatedAt: new Date().toISOString() },
        { id: (0, crypto_1.randomUUID)(), name: 'Coffee', unit: 'kg (beans)', price: 9500, previousPrice: 9200, marketType: 'RETAIL', location: 'Kampala', updatedAt: new Date().toISOString() },
        { id: (0, crypto_1.randomUUID)(), name: 'Cement', unit: 'bag (50kg)', price: 38000, previousPrice: 38000, marketType: 'RETAIL', location: 'Kampala', updatedAt: new Date().toISOString() },
        { id: (0, crypto_1.randomUUID)(), name: 'Beans', unit: 'kg', price: 3800, previousPrice: 4000, marketType: 'RETAIL', location: 'Kampala', updatedAt: new Date().toISOString() },
        { id: (0, crypto_1.randomUUID)(), name: 'Maize Flour', unit: 'kg', price: 2800, previousPrice: 2800, marketType: 'RETAIL', location: 'Kampala', updatedAt: new Date().toISOString() },
        { id: (0, crypto_1.randomUUID)(), name: 'Rice', unit: 'kg', price: 4200, previousPrice: 4000, marketType: 'RETAIL', location: 'Kampala', updatedAt: new Date().toISOString() },
        { id: (0, crypto_1.randomUUID)(), name: 'Cooking Oil', unit: 'litre', price: 8500, previousPrice: 8700, marketType: 'RETAIL', location: 'Kampala', updatedAt: new Date().toISOString() },
        { id: (0, crypto_1.randomUUID)(), name: 'Salt', unit: 'kg', price: 1500, previousPrice: 1500, marketType: 'RETAIL', location: 'Kampala', updatedAt: new Date().toISOString() },
        { id: (0, crypto_1.randomUUID)(), name: 'Milk', unit: 'litre', price: 1800, previousPrice: 1700, marketType: 'RETAIL', location: 'Kampala', updatedAt: new Date().toISOString() },
        { id: (0, crypto_1.randomUUID)(), name: 'Charcoal', unit: 'bag (50kg)', price: 65000, previousPrice: 62000, marketType: 'RETAIL', location: 'Kampala', updatedAt: new Date().toISOString() },
        { id: (0, crypto_1.randomUUID)(), name: 'Electricity', unit: 'kWh', price: 796.9, previousPrice: 796.9, marketType: 'RETAIL', location: null, updatedAt: new Date().toISOString() },
        { id: (0, crypto_1.randomUUID)(), name: 'Petrol', unit: 'litre', price: 4650, previousPrice: 4700, marketType: 'RETAIL', location: 'Kampala', updatedAt: new Date().toISOString() },
        { id: (0, crypto_1.randomUUID)(), name: 'Diesel', unit: 'litre', price: 4450, previousPrice: 4500, marketType: 'RETAIL', location: 'Kampala', updatedAt: new Date().toISOString() },
    ],
    updatedAt: new Date().toISOString(),
};
function loadCommodityPrices() {
    return (0, jsonStore_1.readJsonFile)(COMMODITY_PRICES_PATH, DEFAULT_COMMODITY_PRICES);
}
function saveCommodityPrices(store) {
    (0, jsonStore_1.writeJsonFile)(COMMODITY_PRICES_PATH, store);
}
function round2(value) {
    return Math.round((value + Number.EPSILON) * 100) / 100;
}
// Identifies "the same commodity row" across updates when no id is supplied
// (e.g. a fresh JSON-paste or CSV upload) — name + unit + marketType +
// location together, case-insensitively on name/location.
function naturalKey(item) {
    return [
        item.name.trim().toLowerCase(),
        item.unit.trim().toLowerCase(),
        item.marketType,
        (item.location || '').trim().toLowerCase(),
    ].join('|');
}
function normalizeMarketType(value) {
    return String(value || '').trim().toUpperCase() === 'WHOLESALE' ? 'WHOLESALE' : 'RETAIL';
}
// Shared upsert used by the admin table (PUT, full replace), the JSON-paste
// endpoint, and the CSV/JSON file-upload endpoint (both merge into existing
// items) — so previousPrice / updatedAt are computed identically no matter
// which of the three input paths an admin used, per the request that all
// three ("JSON paste", "CSV/File upload", and implicitly manual editing)
// behave the same way.
function upsertItems(existing, incoming) {
    const byId = new Map(existing.map((i) => [i.id, i]));
    const byKey = new Map(existing.map((i) => [naturalKey(i), i]));
    const now = new Date().toISOString();
    const errors = [];
    const items = [];
    incoming.forEach((raw, idx) => {
        const name = String(raw.name || '').trim();
        const unit = String(raw.unit || '').trim();
        const price = Number(raw.price);
        if (!name || !unit || !Number.isFinite(price) || price < 0) {
            errors.push(`Row ${idx + 1}: "name", "unit", and a non-negative numeric "price" are required.`);
            return;
        }
        const marketType = normalizeMarketType(raw.marketType);
        const location = raw.location ? String(raw.location).trim() || null : null;
        const roundedPrice = round2(price);
        const match = (raw.id && byId.get(raw.id)) || byKey.get(naturalKey({ name, unit, marketType, location }));
        const changed = !match || match.price !== roundedPrice;
        items.push({
            id: raw.id || match?.id || (0, crypto_1.randomUUID)(),
            name,
            unit,
            price: roundedPrice,
            previousPrice: changed ? (match?.price ?? null) : (match?.previousPrice ?? null),
            marketType,
            location,
            updatedAt: changed ? now : (match?.updatedAt ?? now),
        });
    });
    return { items, errors };
}
// ─── Minimal dependency-free CSV parser ────────────────────────────────────────
// Handles quoted fields (so commodity names/locations containing commas work),
// escaped quotes (""), and both \n and \r\n line endings. Expected columns
// (header row required, order doesn't matter): name, unit, price, marketType
// (optional, defaults to RETAIL), location (optional).
function parseCsv(text) {
    const rows = [];
    let field = '';
    let row = [];
    let inQuotes = false;
    for (let i = 0; i < text.length; i++) {
        const char = text[i];
        if (inQuotes) {
            if (char === '"') {
                if (text[i + 1] === '"') {
                    field += '"';
                    i++;
                }
                else {
                    inQuotes = false;
                }
            }
            else {
                field += char;
            }
        }
        else if (char === '"') {
            inQuotes = true;
        }
        else if (char === ',') {
            row.push(field);
            field = '';
        }
        else if (char === '\n' || char === '\r') {
            if (char === '\r' && text[i + 1] === '\n')
                i++;
            row.push(field);
            field = '';
            if (row.some((f) => f.trim() !== ''))
                rows.push(row);
            row = [];
        }
        else {
            field += char;
        }
    }
    if (field !== '' || row.length > 0) {
        row.push(field);
        rows.push(row);
    }
    if (rows.length === 0)
        return [];
    const header = rows[0].map((h) => h.trim().toLowerCase());
    return rows.slice(1).map((r) => {
        const obj = {};
        header.forEach((key, i) => { obj[key] = (r[i] ?? '').trim(); });
        return obj;
    });
}
// ─── Public read ────────────────────────────────────────────────────────────────
// GET /api/commodity-prices?location=Kampala&marketType=RETAIL
router.get('/', async (req, res, next) => {
    try {
        const store = loadCommodityPrices();
        const { location, marketType } = req.query;
        let items = store.items;
        if (location) {
            const loc = location.toLowerCase();
            items = items.filter((i) => (i.location || '').toLowerCase() === loc);
        }
        if (marketType) {
            const mt = normalizeMarketType(marketType);
            items = items.filter((i) => i.marketType === mt);
        }
        // Prices change only when an admin updates them — cache briefly, same as currency-rates.
        res.set('Cache-Control', 'public, max-age=300, stale-while-revalidate=600');
        res.json({ currency: store.currency, items, updatedAt: store.updatedAt });
    }
    catch (err) {
        next(err);
    }
});
// GET /api/commodity-prices/locations — distinct location list for filter UI
router.get('/locations', async (_req, res, next) => {
    try {
        const store = loadCommodityPrices();
        const locations = [...new Set(store.items.map((i) => i.location).filter((l) => !!l))].sort();
        res.json({ locations });
    }
    catch (err) {
        next(err);
    }
});
// ─── Admin: full replace (mirrors the admin table's "Save All") ───────────────
// PUT /api/commodity-prices
router.put('/', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (req, res, next) => {
    try {
        const incoming = Array.isArray(req.body.items) ? req.body.items : [];
        const existing = loadCommodityPrices();
        const { items, errors } = upsertItems(existing.items, incoming);
        if (items.length === 0) {
            return next((0, errorHandler_1.createError)(errors[0] || 'At least one valid commodity price must be provided.', 400));
        }
        const payload = {
            currency: String(req.body.currency || existing.currency || 'UGX'),
            items,
            updatedAt: new Date().toISOString(),
        };
        saveCommodityPrices(payload);
        res.json({ ...payload, warnings: errors });
    }
    catch (err) {
        next(err);
    }
});
// ─── Admin: JSON paste (merge/upsert, doesn't remove untouched items) ─────────
// POST /api/commodity-prices/bulk
// Body: { items: [{ name, unit, price, marketType?, location? }, ...] }
router.post('/bulk', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (req, res, next) => {
    try {
        const incoming = Array.isArray(req.body.items) ? req.body.items : [];
        if (incoming.length === 0) {
            return next((0, errorHandler_1.createError)('Provide a JSON array of items with at least "name", "unit", and "price".', 400));
        }
        const existing = loadCommodityPrices();
        const { items, errors } = upsertItems(existing.items, incoming);
        if (items.length === 0) {
            return next((0, errorHandler_1.createError)(errors[0] || 'None of the provided items were valid.', 400));
        }
        const payload = { ...existing, items, updatedAt: new Date().toISOString() };
        saveCommodityPrices(payload);
        res.json({ ...payload, updated: items.length, warnings: errors });
    }
    catch (err) {
        next(err);
    }
});
// ─── Admin: CSV / JSON file upload (merge/upsert) ──────────────────────────────
// POST /api/commodity-prices/upload  (multipart, field name "file")
const uploadStorage = multer_1.default.memoryStorage();
const fileUpload = (0, multer_1.default)({
    storage: uploadStorage,
    limits: { fileSize: 2 * 1024 * 1024 }, // 2MB — plenty for a price list
    fileFilter: (_req, file, cb) => {
        const ok = /\.(csv|json)$/i.test(file.originalname);
        cb(ok ? null : (0, errorHandler_1.createError)('Only .csv or .json files are accepted', 400));
    },
});
router.post('/upload', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), (req, res, next) => {
    fileUpload.single('file')(req, res, (err) => {
        if (err instanceof multer_1.default.MulterError)
            return next((0, errorHandler_1.createError)(err.message, 400));
        if (err)
            return next(err);
        next();
    });
}, async (req, res, next) => {
    try {
        const file = req.file;
        if (!file)
            return next((0, errorHandler_1.createError)('No file uploaded (expected field name "file")', 400));
        const text = file.buffer.toString('utf-8');
        const isJson = /\.json$/i.test(file.originalname);
        let incoming;
        if (isJson) {
            let parsed;
            try {
                parsed = JSON.parse(text);
            }
            catch {
                return next((0, errorHandler_1.createError)('That file is not valid JSON.', 400));
            }
            const arr = Array.isArray(parsed) ? parsed : parsed?.items;
            if (!Array.isArray(arr)) {
                return next((0, errorHandler_1.createError)('Expected a JSON array of items, or an object with an "items" array.', 400));
            }
            incoming = arr;
        }
        else {
            const rows = parseCsv(text);
            if (rows.length === 0) {
                return next((0, errorHandler_1.createError)('That CSV file has no data rows (or is missing a header row).', 400));
            }
            incoming = rows.map((r) => ({
                name: r.name,
                unit: r.unit,
                price: r.price,
                marketType: r.markettype || r.market_type || r['market type'],
                location: r.location,
            }));
        }
        if (incoming.length === 0) {
            return next((0, errorHandler_1.createError)('No rows found in the uploaded file.', 400));
        }
        const existing = loadCommodityPrices();
        const { items, errors } = upsertItems(existing.items, incoming);
        if (items.length === 0) {
            return next((0, errorHandler_1.createError)(errors[0] || 'None of the rows in that file were valid.', 400));
        }
        const payload = { ...existing, items, updatedAt: new Date().toISOString() };
        saveCommodityPrices(payload);
        res.json({ ...payload, updated: items.length, warnings: errors });
    }
    catch (err) {
        next(err);
    }
});
// ─── Admin: remove a single item ───────────────────────────────────────────────
// DELETE /api/commodity-prices/:id
router.delete('/:id', auth_1.authenticate, (0, auth_1.authorize)('ADMIN'), async (req, res, next) => {
    try {
        const existing = loadCommodityPrices();
        const items = existing.items.filter((i) => i.id !== req.params.id);
        if (items.length === existing.items.length) {
            return next((0, errorHandler_1.createError)('Commodity price item not found', 404));
        }
        const payload = { ...existing, items, updatedAt: new Date().toISOString() };
        saveCommodityPrices(payload);
        res.json(payload);
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
//# sourceMappingURL=commodityPrices.js.map