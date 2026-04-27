"""
Company / Organisation web portal served at /medi.

Authentication is handled in JavaScript via the existing /api/v1/auth/login
and /api/v1/auth/register endpoints.  Company and organisation accounts are
created here; regular users and agents register via the Flutter app.
"""
import os
from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["medi-portal"])

_API_BASE = os.getenv("API_BASE_URL", "/api/v1")

_HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Ort Medi Portal</title>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"
        integrity="sha256-oFMFVRpPnlzr3h4TpMCoLHpRSdVTnLMBSPdqvEK2oiU="
        crossorigin="anonymous"></script>
<style>
  body{font-family:'Inter',system-ui,sans-serif}
  .sidebar-link{display:flex;align-items:center;gap:0.75rem;padding:0.625rem 1rem;border-radius:0.5rem;color:#d1d5db;transition:background-color 0.15s,color 0.15s;cursor:pointer;font-size:0.875rem;font-weight:500;background:none;border:none;width:100%;text-align:left}
  .sidebar-link:hover,.sidebar-link.active{background-color:#15803d;color:#fff}
  .badge{display:inline-block;padding:0.125rem 0.5rem;border-radius:9999px;font-size:0.75rem;font-weight:600}
  #toast{transition:opacity .3s}
  .tab-btn{padding:0.5rem 1.25rem;border-radius:0.5rem;font-size:0.875rem;font-weight:500;cursor:pointer;border:1px solid #d1d5db;background:#fff;color:#374151;transition:all .15s}
  .tab-btn.active{background:#15803d;color:#fff;border-color:#15803d}
  #orgTypeRow{display:none}
  /* ── Mobile sidebar ─────────────────────────────────────────────────────── */
  @media(max-width:767px){
    #sidebar{position:fixed;top:0;left:0;bottom:0;z-index:30;width:16rem;transform:translateX(-100%);transition:transform .3s ease}
    #sidebar.sidebar-open{transform:translateX(0)}
    #sidebarOverlay{display:none;position:fixed;inset:0;background:rgba(0,0,0,.5);z-index:20}
    #sidebarOverlay.show{display:block}
  }
  @media(min-width:768px){#sidebar{position:relative!important;transform:none!important}}
  /* ── Dark theme ─────────────────────────────────────────────────────────── */
  html.theme-dark body{background:#111827!important;color:#f9fafb!important}
  html.theme-dark aside{background:#030712!important}
  html.theme-dark .border-green-800{border-color:#1f2937!important}
  html.theme-dark header.bg-white,html.theme-dark .bg-white{background:#1f2937!important}
  html.theme-dark .bg-gray-50{background:#111827!important}
  html.theme-dark .text-gray-800{color:#f9fafb!important}
  html.theme-dark .text-gray-700{color:#e5e7eb!important}
  html.theme-dark .text-gray-600{color:#d1d5db!important}
  html.theme-dark .text-gray-500{color:#9ca3af!important}
  html.theme-dark .text-gray-400{color:#6b7280!important}
  html.theme-dark .border-b,html.theme-dark .border-gray-300{border-color:#374151!important}
  html.theme-dark input,html.theme-dark select,html.theme-dark textarea{background:#374151!important;color:#f9fafb!important;border-color:#4b5563!important}
  html.theme-dark thead tr{background:#374151!important}
  html.theme-dark tbody tr:hover{background:#374151!important}
  html.theme-dark #themeMenu{background:#1f2937!important;border-color:#374151!important}
  html.theme-dark #themeMenu button:hover{background:#374151!important}
  html.theme-dark .tab-btn{background:#374151!important;color:#e5e7eb!important;border-color:#4b5563!important}
  html.theme-dark .tab-btn.active{background:#15803d!important;color:#fff!important;border-color:#15803d!important}
  /* ── Ocean theme ────────────────────────────────────────────────────────── */
  html.theme-ocean body{background:#eff6ff!important}
  html.theme-ocean aside{background:#1e3a8a!important}
  html.theme-ocean .border-green-800{border-color:#1d4ed8!important}
  html.theme-ocean .bg-green-600{background:#2563eb!important}
  html.theme-ocean .text-green-400{color:#93c5fd!important}
  html.theme-ocean .text-green-700{color:#1d4ed8!important}
  html.theme-ocean .bg-green-700{background:#1d4ed8!important}
  html.theme-ocean .border-green-200{border-color:#bfdbfe!important}
  html.theme-ocean .sidebar-link:hover,.sidebar-link.active{background:#1d4ed8!important}
  html.theme-ocean .bg-green-50{background:#eff6ff!important}
</style>
<script>
(function(){var t=localStorage.getItem('ort_medi_theme')||'white';if(t!=='white')document.documentElement.classList.add('theme-'+t);})();
</script>
</head>
<body class="bg-gray-50 text-gray-800">

<!-- ═══ AUTH OVERLAY ════════════════════════════════════════════════════════ -->
<div id="authOverlay" class="fixed inset-0 bg-gradient-to-br from-green-900 to-green-700 flex items-center justify-center z-50">
  <div class="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-md">

    <!-- Logo -->
    <div class="flex flex-col items-center mb-6">
      <div class="w-14 h-14 rounded-full bg-green-100 flex items-center justify-center mb-3">
        <svg class="w-8 h-8 text-green-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
        </svg>
      </div>
      <h1 class="text-2xl font-bold text-gray-900">Ort Medi Portal</h1>
      <p class="text-gray-400 text-sm mt-1">Company &amp; Organisation Management</p>
    </div>

    <!-- Tab switcher -->
    <div class="flex gap-2 mb-6">
      <button id="tabLoginBtn" class="tab-btn active flex-1" onclick="switchTab('login')">Sign In</button>
      <button id="tabRegBtn" class="tab-btn flex-1" onclick="switchTab('register')">Register</button>
    </div>

    <!-- ── Login form ── -->
    <form id="loginForm" class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
        <input id="loginEmail" type="email" required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
          placeholder="company@example.com"/>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Password</label>
        <input id="loginPassword" type="password" required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
          placeholder="••••••••"/>
      </div>
      <p id="loginError" class="text-red-500 text-xs hidden"></p>
      <button type="submit"
        class="w-full bg-green-700 hover:bg-green-800 text-white font-semibold py-2.5 rounded-lg transition-colors text-sm">
        Sign In
      </button>
    </form>

    <!-- ── Register form ── -->
    <form id="registerForm" class="space-y-3 hidden">
      <!-- Account type -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Account Type *</label>
        <select id="regAccountType" required onchange="onAccountTypeChange()"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
          <option value="company">Company</option>
          <option value="organization">Organisation</option>
        </select>
      </div>
      <div id="orgTypeRow">
        <label class="block text-sm font-medium text-gray-700 mb-1">Organisation Type *</label>
        <select id="regOrgType"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
          <option value="ngo">NGO (Non-Governmental Org)</option>
          <option value="government">Government Body</option>
          <option value="enterprise">Enterprise</option>
          <option value="sme">SME (Small/Medium Enterprise)</option>
        </select>
      </div>
      <!-- Company name -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Company / Organisation Name *</label>
        <input id="regCompanyName" type="text" required maxlength="255"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
          placeholder="Acme Corp"/>
      </div>
      <!-- Contact person -->
      <div class="flex gap-2">
        <div class="flex-1">
          <label class="block text-sm font-medium text-gray-700 mb-1">First Name *</label>
          <input id="regFirstName" type="text" required maxlength="100"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"/>
        </div>
        <div class="flex-1">
          <label class="block text-sm font-medium text-gray-700 mb-1">Last Name *</label>
          <input id="regLastName" type="text" required maxlength="100"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"/>
        </div>
      </div>
      <!-- Email / password -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Email *</label>
        <input id="regEmail" type="email" required
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
          placeholder="contact@company.com"/>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Password *</label>
        <input id="regPassword" type="password" required minlength="8"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
          placeholder="Min 8 characters"/>
      </div>
      <!-- Optional fields -->
      <div class="flex gap-2">
        <div class="flex-1">
          <label class="block text-sm font-medium text-gray-700 mb-1">Business Phone</label>
          <input id="regBusinessPhone" type="tel" maxlength="30"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"/>
        </div>
        <div class="flex-1">
          <label class="block text-sm font-medium text-gray-700 mb-1">Business Email</label>
          <input id="regBusinessEmail" type="email"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"/>
        </div>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Address</label>
        <input id="regAddress" type="text"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"/>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Country</label>
        <input id="regCountry" type="text" maxlength="100"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"/>
      </div>
      <p id="registerError" class="text-red-500 text-xs hidden"></p>
      <p id="registerSuccess" class="text-green-600 text-xs hidden font-medium"></p>
      <button type="submit"
        class="w-full bg-green-700 hover:bg-green-800 text-white font-semibold py-2.5 rounded-lg transition-colors text-sm">
        Create Account
      </button>
    </form>

  </div>
</div>

<!-- ═══ MAIN LAYOUT ══════════════════════════════════════════════════════════ -->
<div id="sidebarOverlay" onclick="toggleSidebar()"></div>
<div id="app" class="hidden min-h-screen flex">

  <!-- Sidebar -->
  <aside id="sidebar" class="w-64 bg-green-900 text-white flex flex-col shrink-0">
    <div class="px-5 py-5 border-b border-green-800">
      <div class="flex items-center gap-3">
        <div class="w-9 h-9 rounded-full bg-green-600 flex items-center justify-center shrink-0">
          <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
          </svg>
        </div>
        <div>
          <div class="font-bold text-white text-sm">Ort Medi Portal</div>
          <div id="portalEmail" class="text-green-400 text-xs truncate max-w-[140px]"></div>
        </div>
      </div>
    </div>
    <nav class="flex-1 px-3 py-4 space-y-1">
      <button class="sidebar-link active" id="navPostings" onclick="showSection('postings')">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
        </svg>Postings</button>
      <button class="sidebar-link" id="navAnalytics" onclick="showSection('analytics')">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
        </svg>Analytics</button>
      <button class="sidebar-link" id="navProfile" onclick="showSection('profile')">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>Profile</button>
    </nav>
    <div class="px-3 py-4 border-t border-green-800">
      <button onclick="logout()"
        class="sidebar-link w-full text-red-300 hover:text-white hover:bg-red-700">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/>
        </svg>Sign Out</button>
    </div>
  </aside>

  <!-- Main Content -->
  <main class="flex-1 overflow-y-auto">
    <header class="bg-white border-b px-6 py-3 flex items-center justify-between sticky top-0 z-10 shadow-sm">
      <div class="flex items-center gap-3">
        <button onclick="toggleSidebar()"
          class="md:hidden p-1.5 rounded-lg text-gray-600 hover:bg-gray-100" aria-label="Menu">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
          </svg>
        </button>
        <h2 id="pageTitle" class="text-lg font-semibold text-gray-800">Postings</h2>
      </div>
      <div class="flex items-center gap-2">
        <button onclick="refreshCurrent()"
          class="text-green-700 hover:text-green-900 text-xs font-medium border border-green-200 hover:border-green-400 px-3 py-1.5 rounded-lg transition-colors">
          ↻ Refresh
        </button>
        <div class="relative" id="themeDropdown">
          <button onclick="toggleThemeMenu()"
            class="text-xs font-medium border border-gray-200 hover:border-gray-400 px-3 py-1.5 rounded-lg transition-colors flex items-center gap-1"
            title="Change theme">
            🎨 Theme
          </button>
          <div id="themeMenu" class="hidden absolute right-0 top-9 bg-white border border-gray-200 rounded-lg shadow-lg z-50 w-32 py-1">
            <button onclick="setTheme('white')" class="w-full text-left px-3 py-2 text-xs hover:bg-gray-50 flex items-center gap-2 text-gray-700">☀️ White</button>
            <button onclick="setTheme('dark')"  class="w-full text-left px-3 py-2 text-xs hover:bg-gray-50 flex items-center gap-2 text-gray-700">🌙 Dark</button>
            <button onclick="setTheme('ocean')" class="w-full text-left px-3 py-2 text-xs hover:bg-gray-50 flex items-center gap-2 text-gray-700">🌊 Ocean</button>
          </div>
        </div>
      </div>
    </header>

    <div id="toast" class="hidden fixed top-4 right-4 z-50 px-4 py-3 rounded-xl shadow-lg text-white text-sm font-medium max-w-xs"></div>

    <!-- ── Postings section ───────────────────────────────────────────── -->
    <section id="sec-postings" class="p-6 space-y-6">
      <!-- Agriculture -->
      <div class="bg-white rounded-2xl shadow p-5">
        <h3 class="font-semibold text-gray-700 mb-3 text-sm flex items-center gap-2">
          <span class="w-2 h-2 rounded-full bg-green-500 inline-block"></span>Agriculture Listings
        </h3>
        <div id="agricultureTable" class="overflow-x-auto">
          <p class="text-gray-400 text-sm">Loading…</p>
        </div>
      </div>
      <!-- Manufacturing -->
      <div class="bg-white rounded-2xl shadow p-5">
        <h3 class="font-semibold text-gray-700 mb-3 text-sm flex items-center gap-2">
          <span class="w-2 h-2 rounded-full bg-blue-500 inline-block"></span>Manufacturing Products
        </h3>
        <div id="manufacturingTable" class="overflow-x-auto">
          <p class="text-gray-400 text-sm">Loading…</p>
        </div>
      </div>
    </section>

    <!-- ── Analytics section ──────────────────────────────────────────── -->
    <section id="sec-analytics" class="p-6 space-y-6 hidden">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="bg-white rounded-2xl shadow p-5">
          <h3 class="font-semibold text-gray-700 mb-3 text-sm">Agriculture by Status</h3>
          <canvas id="agriChart" height="200"></canvas>
        </div>
        <div class="bg-white rounded-2xl shadow p-5">
          <h3 class="font-semibold text-gray-700 mb-3 text-sm">Manufacturing by Status</h3>
          <canvas id="manuChart" height="200"></canvas>
        </div>
      </div>
    </section>

    <!-- ── Profile section ────────────────────────────────────────────── -->
    <section id="sec-profile" class="p-6 hidden">
      <div class="bg-white rounded-2xl shadow p-6 max-w-lg">
        <h3 class="font-semibold text-gray-800 mb-4">Account Details</h3>
        <div id="profileDetails" class="space-y-3 text-sm text-gray-600">
          <p class="text-gray-400">Loading…</p>
        </div>
      </div>
    </section>
  </main>
</div>

<script>
const API = '__API_BASE__';
let token = localStorage.getItem('medi_token') || '';
let currentUser = null;
let agriData = [];
let manuData = [];
let agriChartInst = null;
let manuChartInst = null;

// ── On load ────────────────────────────────────────────────────────────────
window.addEventListener('DOMContentLoaded', () => {
  if (token) {
    fetchMe().then(ok => { if (ok) enterPortal(); else showOverlay(); });
  } else {
    showOverlay();
  }
});

function showOverlay() {
  document.getElementById('authOverlay').classList.remove('hidden');
  document.getElementById('app').classList.add('hidden');
}

function enterPortal() {
  document.getElementById('authOverlay').classList.add('hidden');
  document.getElementById('app').classList.remove('hidden');
  if (currentUser) {
    document.getElementById('portalEmail').textContent =
      currentUser.email || currentUser.company_name || '';
  }
  showSection('postings');
}

// ── Tab switcher ───────────────────────────────────────────────────────────
function switchTab(tab) {
  const isLogin = tab === 'login';
  document.getElementById('loginForm').classList.toggle('hidden', !isLogin);
  document.getElementById('registerForm').classList.toggle('hidden', isLogin);
  document.getElementById('tabLoginBtn').classList.toggle('active', isLogin);
  document.getElementById('tabRegBtn').classList.toggle('active', !isLogin);
}

function onAccountTypeChange() {
  const isOrg = document.getElementById('regAccountType').value === 'organization';
  document.getElementById('orgTypeRow').style.display = isOrg ? 'block' : 'none';
}

// ── Login ──────────────────────────────────────────────────────────────────
document.getElementById('loginForm').addEventListener('submit', async e => {
  e.preventDefault();
  const email = document.getElementById('loginEmail').value.trim();
  const password = document.getElementById('loginPassword').value;
  const errEl = document.getElementById('loginError');
  errEl.classList.add('hidden');
  try {
    const r = await fetch(`${API}/auth/login`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({email, password}),
    });
    const data = await r.json();
    if (!r.ok) { errEl.textContent = data.detail || 'Login failed'; errEl.classList.remove('hidden'); return; }
    token = data.access_token;
    localStorage.setItem('medi_token', token);
    await fetchMe();
    if (!['company','organization'].includes(currentUser?.role)) {
      errEl.textContent = 'This portal is for company and organisation accounts only.';
      errEl.classList.remove('hidden');
      token = '';
      localStorage.removeItem('medi_token');
      return;
    }
    enterPortal();
  } catch {
    errEl.textContent = 'Network error. Please try again.';
    errEl.classList.remove('hidden');
  }
});

// ── Register ───────────────────────────────────────────────────────────────
document.getElementById('registerForm').addEventListener('submit', async e => {
  e.preventDefault();
  const errEl = document.getElementById('registerError');
  const okEl = document.getElementById('registerSuccess');
  errEl.classList.add('hidden');
  okEl.classList.add('hidden');

  const accountType = document.getElementById('regAccountType').value;
  const payload = {
    role: accountType,
    company_name: document.getElementById('regCompanyName').value.trim(),
    first_name: document.getElementById('regFirstName').value.trim(),
    last_name: document.getElementById('regLastName').value.trim(),
    email: document.getElementById('regEmail').value.trim(),
    password: document.getElementById('regPassword').value,
  };
  if (accountType === 'organization') {
    payload.org_type = document.getElementById('regOrgType').value;
  }
  const bp = document.getElementById('regBusinessPhone').value.trim();
  const be = document.getElementById('regBusinessEmail').value.trim();
  const addr = document.getElementById('regAddress').value.trim();
  const country = document.getElementById('regCountry').value.trim();
  if (bp) payload.business_phone = bp;
  if (be) payload.business_email = be;
  if (addr) payload.address = addr;
  if (country) payload.country = country;

  try {
    const r = await fetch(`${API}/auth/register`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(payload),
    });
    const data = await r.json();
    if (!r.ok) { errEl.textContent = data.detail || 'Registration failed'; errEl.classList.remove('hidden'); return; }
    okEl.textContent = 'Registered successfully! Please sign in.';
    okEl.classList.remove('hidden');
    document.getElementById('registerForm').reset();
    setTimeout(() => switchTab('login'), 1500);
  } catch {
    errEl.textContent = 'Network error. Please try again.';
    errEl.classList.remove('hidden');
  }
});

// ── Auth helpers ───────────────────────────────────────────────────────────
async function fetchMe() {
  try {
    const r = await fetch(`${API}/users/me`, { headers: authHeaders() });
    if (!r.ok) { token = ''; localStorage.removeItem('medi_token'); return false; }
    currentUser = await r.json();
    return true;
  } catch { return false; }
}

function authHeaders() {
  return { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' };
}

function logout() {
  token = '';
  localStorage.removeItem('medi_token');
  currentUser = null;
  agriData = [];
  manuData = [];
  showOverlay();
}

// ── Section navigation ─────────────────────────────────────────────────────
const sections = ['postings', 'analytics', 'profile'];
const titles = { postings: 'Postings', analytics: 'Analytics', profile: 'Profile' };

function showSection(name) {
  closeSidebar();
  sections.forEach(s => {
    document.getElementById(`sec-${s}`).classList.toggle('hidden', s !== name);
    const btn = document.getElementById(`nav${s.charAt(0).toUpperCase()+s.slice(1)}`);
    if (btn) btn.classList.toggle('active', s === name);
  });
  document.getElementById('pageTitle').textContent = titles[name] || name;
  if (name === 'postings') loadPostings();
  if (name === 'analytics') loadAnalytics();
  if (name === 'profile') loadProfile();
}

function refreshCurrent() {
  const title = document.getElementById('pageTitle').textContent;
  const s = Object.entries(titles).find(([,v]) => v === title)?.[0];
  if (s) showSection(s);
}

// ── Postings ───────────────────────────────────────────────────────────────
async function loadPostings() {
  await Promise.all([loadAgriculture(), loadManufacturing()]);
}

async function loadAgriculture() {
  const el = document.getElementById('agricultureTable');
  el.innerHTML = '<p class="text-gray-400 text-sm">Loading…</p>';
  try {
    const r = await fetch(`${API}/agriculture/?limit=100`, { headers: authHeaders() });
    const data = await r.json();
    const items = Array.isArray(data) ? data : (data.listings || data.items || []);
    agriData = items;
    if (!items.length) { el.innerHTML = '<p class="text-gray-400 text-sm">No agriculture listings.</p>'; return; }
    el.innerHTML = `<table class="min-w-full text-sm">
      <thead class="bg-gray-50 border-b"><tr>
        <th class="px-4 py-2 text-left font-semibold text-gray-600">ID</th>
        <th class="px-4 py-2 text-left font-semibold text-gray-600">Title</th>
        <th class="px-4 py-2 text-left font-semibold text-gray-600">Category</th>
        <th class="px-4 py-2 text-left font-semibold text-gray-600">Status</th>
        <th class="px-4 py-2 text-left font-semibold text-gray-600">Price/Unit</th>
      </tr></thead>
      <tbody class="divide-y divide-gray-100">
        ${items.map(i => `<tr class="hover:bg-gray-50">
          <td class="px-4 py-2 text-gray-500">${i.id}</td>
          <td class="px-4 py-2 font-medium">${esc(i.title)}</td>
          <td class="px-4 py-2">${esc(i.category||'')}</td>
          <td class="px-4 py-2"><span class="badge ${statusColor(i.status)}">${esc(i.status||'')}</span></td>
          <td class="px-4 py-2">${i.price_per_unit != null ? '$'+Number(i.price_per_unit).toFixed(2) : '—'}</td>
        </tr>`).join('')}
      </tbody></table>`;
  } catch { el.innerHTML = '<p class="text-red-500 text-sm">Failed to load.</p>'; }
}

async function loadManufacturing() {
  const el = document.getElementById('manufacturingTable');
  el.innerHTML = '<p class="text-gray-400 text-sm">Loading…</p>';
  try {
    const r = await fetch(`${API}/manufacturing/?limit=100`, { headers: authHeaders() });
    const data = await r.json();
    const items = Array.isArray(data) ? data : (data.products || data.items || []);
    manuData = items;
    if (!items.length) { el.innerHTML = '<p class="text-gray-400 text-sm">No manufacturing products.</p>'; return; }
    el.innerHTML = `<table class="min-w-full text-sm">
      <thead class="bg-gray-50 border-b"><tr>
        <th class="px-4 py-2 text-left font-semibold text-gray-600">ID</th>
        <th class="px-4 py-2 text-left font-semibold text-gray-600">Title</th>
        <th class="px-4 py-2 text-left font-semibold text-gray-600">Category</th>
        <th class="px-4 py-2 text-left font-semibold text-gray-600">Status</th>
        <th class="px-4 py-2 text-left font-semibold text-gray-600">Price</th>
      </tr></thead>
      <tbody class="divide-y divide-gray-100">
        ${items.map(i => `<tr class="hover:bg-gray-50">
          <td class="px-4 py-2 text-gray-500">${i.id}</td>
          <td class="px-4 py-2 font-medium">${esc(i.title)}</td>
          <td class="px-4 py-2">${esc(i.category||'')}</td>
          <td class="px-4 py-2"><span class="badge ${statusColor(i.status)}">${esc(i.status||'')}</span></td>
          <td class="px-4 py-2">${i.price != null ? '$'+Number(i.price).toFixed(2) : '—'}</td>
        </tr>`).join('')}
      </tbody></table>`;
  } catch { el.innerHTML = '<p class="text-red-500 text-sm">Failed to load.</p>'; }
}

// ── Analytics ──────────────────────────────────────────────────────────────
async function loadAnalytics() {
  if (!agriData.length && !manuData.length) await loadPostings();
  renderStatusChart('agriChart', agriData, agriChartInst, c => agriChartInst = c);
  renderStatusChart('manuChart', manuData, manuChartInst, c => manuChartInst = c);
}

function renderStatusChart(canvasId, data, existing, setter) {
  const counts = {};
  data.forEach(i => { counts[i.status || 'unknown'] = (counts[i.status || 'unknown'] || 0) + 1; });
  const labels = Object.keys(counts);
  const values = Object.values(counts);
  const colors = ['#16a34a','#2563eb','#f59e0b','#ef4444','#8b5cf6','#6b7280'];
  if (existing) existing.destroy();
  const ctx = document.getElementById(canvasId);
  if (!ctx) return;
  const chart = new Chart(ctx, {
    type: 'doughnut',
    data: { labels, datasets: [{ data: values, backgroundColor: colors.slice(0, labels.length), borderWidth: 2 }] },
    options: { responsive: true, plugins: { legend: { position: 'bottom' } } },
  });
  setter(chart);
}

// ── Profile ────────────────────────────────────────────────────────────────
function loadProfile() {
  if (!currentUser) return;
  const el = document.getElementById('profileDetails');
  const fields = [
    ['Name', `${currentUser.first_name||''} ${currentUser.last_name||''}`.trim()],
    ['Email', currentUser.email],
    ['Role', currentUser.role],
    ['Company', currentUser.company_name],
    ['Business Email', currentUser.business_email],
    ['Business Phone', currentUser.business_phone],
    ['Address', currentUser.address],
    ['Country', currentUser.country],
  ].filter(([,v]) => v);
  el.innerHTML = fields.map(([k,v]) =>
    `<div class="flex gap-3"><span class="font-medium text-gray-700 w-32 shrink-0">${esc(k)}</span><span>${esc(String(v))}</span></div>`
  ).join('');
}

// ── Utilities ──────────────────────────────────────────────────────────────
function statusColor(s) {
  const map = { active:'bg-green-100 text-green-800', pending:'bg-yellow-100 text-yellow-800',
    sold:'bg-blue-100 text-blue-800', inactive:'bg-gray-100 text-gray-600',
    rejected:'bg-red-100 text-red-700' };
  return map[s] || 'bg-gray-100 text-gray-600';
}

function esc(s) {
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function showToast(msg, isError=false) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.style.backgroundColor = isError ? '#dc2626' : '#15803d';
  t.className = 'fixed top-4 right-4 z-50 px-4 py-3 rounded-xl shadow-lg text-white text-sm font-medium max-w-xs';
  t.classList.remove('hidden');
  setTimeout(() => t.classList.add('hidden'), 3000);
}

// ── Mobile sidebar ─────────────────────────────────────────────────────────
function toggleSidebar() {
  document.getElementById('sidebar').classList.toggle('sidebar-open');
  document.getElementById('sidebarOverlay').classList.toggle('show');
}
function closeSidebar() {
  document.getElementById('sidebar').classList.remove('sidebar-open');
  document.getElementById('sidebarOverlay').classList.remove('show');
}

// ── Theme switcher ─────────────────────────────────────────────────────────
function setTheme(t) {
  const cl = document.documentElement.classList;
  cl.remove('theme-white','theme-dark','theme-ocean');
  if (t !== 'white') cl.add('theme-'+t);
  localStorage.setItem('ort_medi_theme', t);
  document.getElementById('themeMenu').classList.add('hidden');
}
function toggleThemeMenu() {
  document.getElementById('themeMenu').classList.toggle('hidden');
}
document.addEventListener('click', function(e) {
  const dd = document.getElementById('themeDropdown');
  if (dd && !dd.contains(e.target)) document.getElementById('themeMenu').classList.add('hidden');
});
</script>
</body>
</html>"""

_HTML = _HTML.replace('__API_BASE__', _API_BASE)


@router.get("/medi", response_class=HTMLResponse, include_in_schema=False)
def medi_portal():
    return HTMLResponse(content=_HTML)
