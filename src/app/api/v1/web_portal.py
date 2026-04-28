"""
Public web marketplace portal served at /web.

No authentication required to browse listings.  Anyone can view properties,
agriculture listings, and manufacturing products.  Authentication is handled
by the /medi portal for posting / managing listings.
"""
import os
from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["web-portal"])

_API_BASE = os.getenv("API_BASE_URL", "/api/v1")

_HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Ort Marketplace</title>
<script src="https://cdn.tailwindcss.com"></script>
<style>
  body{font-family:'Inter',system-ui,sans-serif}
  .tab-nav-btn{color:#6b7280;padding:.375rem .75rem;border-radius:.5rem;font-size:.875rem;font-weight:500;transition:all .15s;background:none;border:none;cursor:pointer}
  .tab-nav-btn.active,.tab-nav-btn:hover{color:#15803d;background:#f0fdf4}
  .mob-tab-btn{flex:1;padding:.5rem .25rem;font-size:.75rem;font-weight:500;color:#6b7280;border:none;border-bottom:2px solid transparent;background:none;cursor:pointer;transition:all .15s}
  .mob-tab-btn.active{color:#15803d;border-bottom-color:#15803d}
  .listing-card{background:#fff;border-radius:.75rem;box-shadow:0 1px 3px rgba(0,0,0,.1);overflow:hidden;display:flex;flex-direction:column;transition:box-shadow .2s}
  .listing-card:hover{box-shadow:0 4px 12px rgba(0,0,0,.15)}
  .card-placeholder{width:100%;height:12rem;background:#f3f4f6;display:flex;align-items:center;justify-content:center}
  /* ── Dark theme ─────────────────────────────────────────────────────────── */
  html.theme-dark body{background:#111827!important;color:#f9fafb!important}
  html.theme-dark .listing-card,html.theme-dark .bg-white{background:#1f2937!important}
  html.theme-dark .tab-nav-btn.active,.tab-nav-btn:hover{color:#4ade80!important;background:#052e16!important}
  html.theme-dark header.bg-white{background:#1f2937!important;border-color:#374151!important}
  html.theme-dark .text-gray-800{color:#f9fafb!important}
  html.theme-dark .text-gray-700{color:#e5e7eb!important}
  html.theme-dark .text-gray-600{color:#d1d5db!important}
  html.theme-dark .text-gray-500{color:#9ca3af!important}
  html.theme-dark .text-gray-400{color:#6b7280!important}
  html.theme-dark .text-gray-300{color:#4b5563!important}
  html.theme-dark .bg-gray-50{background:#111827!important}
  html.theme-dark .bg-gray-100,.theme-dark .card-placeholder{background:#374151!important}
  html.theme-dark .border-b{border-color:#374151!important}
  html.theme-dark footer.bg-gray-900{background:#030712!important}
  html.theme-dark #themeMenu{background:#1f2937!important;border-color:#374151!important}
  html.theme-dark #themeMenu button:hover{background:#374151!important}
  html.theme-dark input{background:#374151!important;color:#f9fafb!important}
  /* ── Ocean theme ────────────────────────────────────────────────────────── */
  html.theme-ocean body{background:#eff6ff!important}
  html.theme-ocean header.bg-white{background:#fff!important;border-color:#bfdbfe!important}
  html.theme-ocean .text-green-700{color:#1d4ed8!important}
  html.theme-ocean .bg-green-700{background:#1d4ed8!important}
  html.theme-ocean .hover\:bg-green-800:hover{background:#1e40af!important}
  html.theme-ocean .tab-nav-btn.active,.tab-nav-btn:hover{color:#1d4ed8!important;background:#eff6ff!important}
  html.theme-ocean .mob-tab-btn.active{color:#1d4ed8!important;border-bottom-color:#1d4ed8!important}
  html.theme-ocean .listing-card{background:#fff!important}
  html.theme-ocean footer.bg-gray-900{background:#1e3a8a!important}
  html.theme-ocean #themeMenu button:hover{background:#eff6ff!important}
</style>
<script>
(function(){var t=localStorage.getItem('ort_web_theme')||'white';if(t!=='white')document.documentElement.classList.add('theme-'+t);})();
</script>
</head>
<body class="bg-gray-50 text-gray-800 min-h-screen">

<!-- ═══ HEADER ══════════════════════════════════════════════════════════════ -->
<header class="bg-white border-b shadow-sm sticky top-0 z-20">
  <div class="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between gap-3">
    <!-- Logo -->
    <a href="/web" class="flex items-center gap-2 shrink-0">
      <div class="w-8 h-8 rounded-full bg-green-700 flex items-center justify-center">
        <span class="text-white font-bold text-sm">O</span>
      </div>
      <span class="font-bold text-xl text-gray-900">Ort</span>
      <span class="hidden sm:block text-gray-400 text-sm">Marketplace</span>
    </a>
    <!-- Desktop category nav -->
    <nav class="hidden md:flex items-center gap-1">
      <button onclick="switchTab('properties')"   id="tab-properties"   class="tab-nav-btn active">🏠 Properties</button>
      <button onclick="switchTab('agriculture')"  id="tab-agriculture"  class="tab-nav-btn">🌾 Agriculture</button>
      <button onclick="switchTab('manufacturing')" id="tab-manufacturing" class="tab-nav-btn">🏭 Manufacturing</button>
    </nav>
    <!-- Actions -->
    <div class="flex items-center gap-2 shrink-0">
      <!-- Theme switcher -->
      <div class="relative" id="themeDropdown">
        <button onclick="toggleThemeMenu()"
          class="border border-gray-200 hover:border-gray-400 px-3 py-1.5 rounded-lg text-sm transition-colors"
          title="Change theme">🎨</button>
        <div id="themeMenu" class="hidden absolute right-0 top-9 bg-white border border-gray-200 rounded-lg shadow-lg z-50 w-32 py-1">
          <button onclick="setTheme('white')" class="w-full text-left px-3 py-2 text-xs hover:bg-gray-50 flex items-center gap-2 text-gray-700">☀️ White</button>
          <button onclick="setTheme('dark')"  class="w-full text-left px-3 py-2 text-xs hover:bg-gray-50 flex items-center gap-2 text-gray-700">🌙 Dark</button>
          <button onclick="setTheme('ocean')" class="w-full text-left px-3 py-2 text-xs hover:bg-gray-50 flex items-center gap-2 text-gray-700">🌊 Ocean</button>
        </div>
      </div>
      <a href="/medi" class="hidden sm:block text-sm font-medium text-gray-700 hover:text-gray-900 transition-colors">Sign In</a>
      <a href="/medi" class="bg-green-700 hover:bg-green-800 text-white text-sm font-medium px-4 py-1.5 rounded-lg transition-colors whitespace-nowrap">List Now</a>
    </div>
  </div>
  <!-- Mobile category tabs -->
  <div class="md:hidden border-t flex">
    <button onclick="switchTab('properties')"   id="mob-tab-properties"   class="mob-tab-btn active">🏠 Props</button>
    <button onclick="switchTab('agriculture')"  id="mob-tab-agriculture"  class="mob-tab-btn">🌾 Agri</button>
    <button onclick="switchTab('manufacturing')" id="mob-tab-manufacturing" class="mob-tab-btn">🏭 Manu</button>
  </div>
</header>

<!-- ═══ HERO ═════════════════════════════════════════════════════════════════ -->
<section class="bg-gradient-to-br from-green-900 to-green-700 text-white py-14 px-4">
  <div class="max-w-3xl mx-auto text-center">
    <h1 class="text-3xl sm:text-4xl font-bold mb-3">Discover Properties, Agriculture &amp; Goods</h1>
    <p class="text-green-200 mb-7 text-lg">Browse thousands of listings — no sign-up required</p>
    <div class="flex gap-2 max-w-xl mx-auto">
      <input id="searchInput" type="text" placeholder="Search listings by title, location, category…"
        class="flex-1 rounded-lg px-4 py-3 text-gray-800 text-sm focus:outline-none focus:ring-2 focus:ring-green-400 min-w-0"/>
      <button onclick="applySearch()"
        class="bg-white hover:bg-green-50 text-green-800 font-semibold px-5 py-3 rounded-lg transition-colors whitespace-nowrap">
        Search
      </button>
    </div>
  </div>
</section>

<!-- ═══ MAIN CONTENT ══════════════════════════════════════════════════════════ -->
<main class="max-w-7xl mx-auto px-4 py-8">

  <!-- Properties section -->
  <section id="sec-properties">
    <div class="flex items-center justify-between mb-5">
      <h2 class="text-xl font-bold text-gray-800">🏠 Properties</h2>
      <span id="props-count" class="text-sm text-gray-500"></span>
    </div>
    <div id="props-grid" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
      <div class="col-span-full flex justify-center py-16">
        <div class="w-8 h-8 border-4 border-green-600 border-t-transparent rounded-full animate-spin"></div>
      </div>
    </div>
  </section>

  <!-- Agriculture section -->
  <section id="sec-agriculture" class="hidden">
    <div class="flex items-center justify-between mb-5">
      <h2 class="text-xl font-bold text-gray-800">🌾 Agriculture</h2>
      <span id="agri-count" class="text-sm text-gray-500"></span>
    </div>
    <div id="agri-grid" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
      <div class="col-span-full flex justify-center py-16">
        <div class="w-8 h-8 border-4 border-green-600 border-t-transparent rounded-full animate-spin"></div>
      </div>
    </div>
  </section>

  <!-- Manufacturing section -->
  <section id="sec-manufacturing" class="hidden">
    <div class="flex items-center justify-between mb-5">
      <h2 class="text-xl font-bold text-gray-800">🏭 Manufacturing</h2>
      <span id="manu-count" class="text-sm text-gray-500"></span>
    </div>
    <div id="manu-grid" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
      <div class="col-span-full flex justify-center py-16">
        <div class="w-8 h-8 border-4 border-green-600 border-t-transparent rounded-full animate-spin"></div>
      </div>
    </div>
  </section>

</main>

<!-- ═══ DETAIL MODAL ══════════════════════════════════════════════════════════ -->
<div id="detailModal" class="hidden fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
  <div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
    <div class="flex items-center justify-between px-6 py-4 border-b">
      <h3 id="modalTitle" class="font-bold text-gray-900 text-lg pr-4"></h3>
      <button onclick="closeModal()" class="text-gray-400 hover:text-gray-700 text-2xl leading-none shrink-0">&times;</button>
    </div>
    <div id="modalContent" class="p-6 space-y-3 text-sm text-gray-700"></div>
    <div class="px-6 py-4 border-t flex gap-3">
      <a href="/medi"
        class="flex-1 text-center bg-green-700 hover:bg-green-800 text-white font-medium py-2.5 rounded-lg transition-colors text-sm">
        Contact Seller via Medi Portal
      </a>
      <button onclick="closeModal()"
        class="flex-1 border border-gray-300 hover:bg-gray-50 font-medium py-2.5 rounded-lg transition-colors text-sm text-gray-700">
        Close
      </button>
    </div>
  </div>
</div>

<!-- ═══ FOOTER ════════════════════════════════════════════════════════════════ -->
<footer class="bg-gray-900 text-gray-400 mt-16 py-10">
  <div class="max-w-7xl mx-auto px-4">
    <div class="flex flex-col md:flex-row items-center justify-between gap-6">
      <div class="flex items-center gap-3">
        <div class="w-8 h-8 rounded-full bg-green-700 flex items-center justify-center">
          <span class="text-white font-bold text-sm">O</span>
        </div>
        <div>
          <span class="font-bold text-white text-lg">Ort Marketplace</span>
          <p class="text-gray-500 text-xs mt-0.5">Properties · Agriculture · Manufacturing</p>
        </div>
      </div>
      <nav class="flex gap-6 text-sm">
        <a href="/web"  class="hover:text-white transition-colors">Browse Listings</a>
        <a href="/medi" class="hover:text-white transition-colors">Business Portal</a>
        <a href="/const" class="hover:text-white transition-colors">Admin</a>
      </nav>
      <p class="text-gray-600 text-xs">&copy; 2025 Ort. All rights reserved.</p>
    </div>
  </div>
</footer>

<script>
const API = '__API_BASE__';
const allData = { properties: [], agriculture: [], manufacturing: [] };
let currentTab = 'properties';
let searchTerm = '';

// ── Boot ───────────────────────────────────────────────────────────────────
window.addEventListener('DOMContentLoaded', () => {
  loadAll();
  document.getElementById('searchInput').addEventListener('keydown', e => {
    if (e.key === 'Enter') applySearch();
  });
  // Close modal on backdrop click
  document.getElementById('detailModal').addEventListener('click', function(e) {
    if (e.target === this) closeModal();
  });
  // Delegated view button handler
  document.addEventListener('click', function(e) {
    const btn = e.target.closest('.view-btn');
    if (btn) {
      const type = btn.dataset.type;
      const idx  = parseInt(btn.dataset.idx);
      showDetail(type, idx);
    }
    // Close theme menu when clicking outside
    const dd = document.getElementById('themeDropdown');
    if (dd && !dd.contains(e.target)) {
      document.getElementById('themeMenu').classList.add('hidden');
    }
  });
});

async function loadAll() {
  await Promise.all([
    fetchCategory('properties',   API + '/properties/?limit=50'),
    fetchCategory('agriculture',  API + '/agriculture/?limit=50'),
    fetchCategory('manufacturing', API + '/manufacturing/?limit=50'),
  ]);
}

async function fetchWithTimeout(url, ms) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ms);
  try {
    const r = await fetch(url, { signal: ctrl.signal });
    clearTimeout(timer);
    return r;
  } catch(e) {
    clearTimeout(timer);
    throw e;
  }
}

async function fetchCategory(type, url) {
  const gridKey = gridId(type);
  try {
    const r = await fetchWithTimeout(url, 12000);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const data = await r.json();
    const items = Array.isArray(data) ? data : (data.items || data.listings || data.products || []);
    allData[type] = items;
    renderGrid(type);
  } catch(e) {
    const grid = document.getElementById(gridKey + '-grid');
    if (grid) grid.innerHTML =
      '<p class="col-span-full text-center text-gray-400 py-16 text-sm">Could not load listings. ' +
      '<a href="/medi" class="text-green-700 underline">Sign in to view all.</a></p>';
    const count = document.getElementById(gridKey + '-count');
    if (count) count.textContent = '';
  }
}

function gridId(type) {
  return type === 'properties' ? 'props' : type === 'agriculture' ? 'agri' : 'manu';
}

// ── Tab switching ──────────────────────────────────────────────────────────
const TAB_SECTIONS = ['properties','agriculture','manufacturing'];

function switchTab(tab) {
  currentTab = tab;
  TAB_SECTIONS.forEach(t => {
    document.getElementById('sec-'+t).classList.toggle('hidden', t !== tab);
    const btn  = document.getElementById('tab-'+t);
    const mBtn = document.getElementById('mob-tab-'+t);
    if (btn)  btn.classList.toggle('active', t === tab);
    if (mBtn) mBtn.classList.toggle('active', t === tab);
  });
}

// ── Search ─────────────────────────────────────────────────────────────────
function applySearch() {
  searchTerm = document.getElementById('searchInput').value.toLowerCase().trim();
  TAB_SECTIONS.forEach(t => renderGrid(t));
}

// ── Render grid ────────────────────────────────────────────────────────────
function renderGrid(type) {
  const gid    = gridId(type);
  const grid   = document.getElementById(gid + '-grid');
  const count  = document.getElementById(gid + '-count');
  let items = allData[type] || [];
  if (searchTerm) {
    items = items.filter(item => {
      const text = [getTitle(item,type), getPrice(item), getMeta(item,type), item.description||''].join(' ').toLowerCase();
      return text.includes(searchTerm);
    });
  }
  if (count) count.textContent = items.length ? items.length + ' listing' + (items.length !== 1 ? 's' : '') : '';
  if (!items.length) {
    const msg = searchTerm ? 'No results for "' + esc(searchTerm) + '"' : 'No listings available.';
    grid.innerHTML = '<p class="col-span-full text-center text-gray-400 py-16 text-sm">' + msg + '</p>';
    return;
  }
  grid.innerHTML = items.map((item, i) => renderCard(item, type, i)).join('');
}

function renderCard(item, type, idx) {
  const img   = getImage(item);
  const title = getTitle(item, type);
  const price = getPrice(item);
  const meta  = getMeta(item, type);
  const status = item.status || '';
  const statusBadge = status
    ? '<span class="text-xs px-2 py-0.5 rounded-full ' + statusClass(status) + ' mb-1 inline-block">' + esc(status) + '</span>'
    : '';
  const imgSection = img
    ? '<img src="' + esc(img) + '" alt="' + esc(title) + '" class="w-full h-48 object-cover"' +
      ' onerror="this.outerHTML=\'<div class=card-placeholder>' + svgPlaceholderInline() + '</div>\'">'
    : '<div class="card-placeholder">' + placeholderSVG() + '</div>';
  return '<div class="listing-card">' +
    '<div class="overflow-hidden bg-gray-100">' + imgSection + '</div>' +
    '<div class="p-4 flex flex-col flex-1">' +
      statusBadge +
      '<h3 class="font-semibold text-gray-800 text-sm leading-snug mb-1" style="display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden">' + esc(title) + '</h3>' +
      (price ? '<p class="text-green-700 font-bold text-base mb-1">' + esc(price) + '</p>' : '') +
      (meta  ? '<p class="text-gray-500 text-xs mb-3">' + esc(meta) + '</p>' : '<div class="mb-3"></div>') +
      '<div class="mt-auto">' +
        '<button class="view-btn w-full bg-green-700 hover:bg-green-800 text-white text-sm font-medium py-2 rounded-lg transition-colors"' +
          ' data-type="' + type + '" data-idx="' + idx + '">View Details</button>' +
      '</div>' +
    '</div>' +
  '</div>';
}

function placeholderSVG() {
  return '<svg class="w-12 h-12 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">' +
    '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" ' +
    'd="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>' +
    '</svg>';
}

function svgPlaceholderInline() {
  // Simple text placeholder used inside onerror (no quotes that would break HTML attributes)
  return '';
}

// ── Detail modal ───────────────────────────────────────────────────────────
function showDetail(type, idx) {
  const item = allData[type][idx];
  if (!item) return;
  document.getElementById('modalTitle').textContent = getTitle(item, type);
  const rows = [];
  const addRow = (k, v) => {
    if (v) rows.push('<div class="flex gap-2">' +
      '<span class="font-medium text-gray-600 w-28 shrink-0">' + esc(k) + '</span>' +
      '<span class="text-gray-800">' + esc(String(v)) + '</span></div>');
  };
  addRow('Price',       getPrice(item));
  addRow('Category',    item.category   || item.crop_type || item.type || '');
  addRow('Location',    item.location   || item.city     || item.address || '');
  addRow('Status',      item.status     || '');
  addRow('Unit',        item.unit       || '');
  addRow('Description', item.description || '');
  const img = getImage(item);
  const imgHtml = img
    ? '<img src="' + esc(img) + '" alt="" class="w-full h-48 object-cover rounded-lg mb-4" onerror="this.remove()">'
    : '';
  document.getElementById('modalContent').innerHTML =
    imgHtml + (rows.length ? rows.join('') : '<p class="text-gray-400">No additional details.</p>');
  document.getElementById('detailModal').classList.remove('hidden');
}

function closeModal() {
  document.getElementById('detailModal').classList.add('hidden');
}

// ── Data helpers ───────────────────────────────────────────────────────────
function getImage(item) {
  const imgs = item.images || item.image_urls || [];
  if (imgs.length > 0) {
    const first = imgs[0];
    return typeof first === 'string' ? first : (first.image_url || first.url || '');
  }
  return item.image_url || item.image || '';
}

function getTitle(item, type) {
  return item.title || item.product_name || item.name ||
    (type === 'agriculture' ? 'Agriculture Listing' : type === 'manufacturing' ? 'Product' : 'Property');
}

function getPrice(item) {
  const p = item.price != null ? item.price :
            item.rent != null ? item.rent :
            item.price_per_unit != null ? item.price_per_unit :
            item.unit_price != null ? item.unit_price :
            item.amount != null ? item.amount : null;
  if (p === null) return '';
  const cur = item.currency || 'KES';
  const unit = item.unit ? ' /' + item.unit : '';
  return cur + ' ' + Number(p).toLocaleString() + unit;
}

function getMeta(item, type) {
  if (type === 'properties')   return item.city || item.address || item.type || '';
  if (type === 'agriculture')  return item.category || item.crop_type || item.location || '';
  return item.category || item.location || '';
}

function statusClass(s) {
  const m = {
    active:   'bg-green-100 text-green-800',
    pending:  'bg-yellow-100 text-yellow-800',
    sold:     'bg-blue-100 text-blue-800',
    inactive: 'bg-gray-100 text-gray-600',
    rejected: 'bg-red-100 text-red-700',
  };
  return m[s] || 'bg-gray-100 text-gray-600';
}

function esc(s) {
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// ── Theme switcher ─────────────────────────────────────────────────────────
function setTheme(t) {
  const cl = document.documentElement.classList;
  cl.remove('theme-white','theme-dark','theme-ocean');
  if (t !== 'white') cl.add('theme-' + t);
  localStorage.setItem('ort_web_theme', t);
  document.getElementById('themeMenu').classList.add('hidden');
}

function toggleThemeMenu() {
  document.getElementById('themeMenu').classList.toggle('hidden');
}
</script>
</body>
</html>"""

_HTML = _HTML.replace('__API_BASE__', _API_BASE)


@router.get("/web", response_class=HTMLResponse, include_in_schema=False)
def web_portal():
    """Public marketplace portal served at /web."""
    return HTMLResponse(content=_HTML)
