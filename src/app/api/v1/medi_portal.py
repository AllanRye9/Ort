"""
Company / Organisation web portal served at /medi.

Authentication is handled in JavaScript via the existing /api/v1/auth/login
and /api/v1/auth/register endpoints.  Company and organisation accounts are
created here; regular users and agents register via the Flutter app.

Features:
- Login / register for company & organisation accounts
- Postings: create, edit, delete agriculture listings and manufacturing products
  (scoped to the logged-in user's tenant)
- Image upload (via /api/v1/upload/image)
- Google Maps link field per listing
- Analytics: status charts per category
- Profile: account details
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
  .modal-backdrop{position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:50;display:flex;align-items:center;justify-content:center;padding:1rem}
  .modal-box{background:#fff;border-radius:1rem;box-shadow:0 20px 60px rgba(0,0,0,0.3);width:100%;max-width:42rem;max-height:90vh;overflow-y:auto;padding:1.5rem}
  .form-label{display:block;font-size:0.875rem;font-weight:500;color:#374151;margin-bottom:0.25rem}
  .form-input{width:100%;border:1px solid #d1d5db;border-radius:0.5rem;padding:0.5rem 0.75rem;font-size:0.875rem;outline:none;transition:border-color .15s,box-shadow .15s}
  .form-input:focus{border-color:#15803d;box-shadow:0 0 0 2px rgba(21,128,61,0.2)}
  .form-grid{display:grid;grid-template-columns:1fr 1fr;gap:0.75rem}
  .img-thumb{width:3rem;height:3rem;object-fit:cover;border-radius:0.375rem;border:1px solid #e5e7eb}
  @media(max-width:767px){
    #sidebar{position:fixed;top:0;left:0;bottom:0;z-index:30;width:16rem;transform:translateX(-100%);transition:transform .3s ease}
    #sidebar.sidebar-open{transform:translateX(0)}
    #sidebarOverlay{display:none;position:fixed;inset:0;background:rgba(0,0,0,.5);z-index:20}
    #sidebarOverlay.show{display:block}
    .form-grid{grid-template-columns:1fr}
  }
  @media(min-width:768px){#sidebar{position:relative!important;transform:none!important}}
  /* Dark theme */
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
  html.theme-dark .form-input{background:#374151!important;color:#f9fafb!important;border-color:#4b5563!important}
  html.theme-dark select,html.theme-dark textarea{background:#374151!important;color:#f9fafb!important;border-color:#4b5563!important}
  html.theme-dark thead tr{background:#374151!important}
  html.theme-dark tbody tr:hover{background:#374151!important}
  html.theme-dark .modal-box{background:#1f2937!important;color:#f9fafb!important}
  html.theme-dark .tab-btn{background:#374151!important;color:#e5e7eb!important;border-color:#4b5563!important}
  html.theme-dark .tab-btn.active{background:#15803d!important;color:#fff!important;border-color:#15803d!important}
  /* Ocean theme */
  html.theme-ocean body{background:#eff6ff!important}
  html.theme-ocean aside{background:#1e3a8a!important}
  html.theme-ocean .bg-green-600{background:#2563eb!important}
  html.theme-ocean .text-green-400{color:#93c5fd!important}
  html.theme-ocean .bg-green-700{background:#1d4ed8!important}
  html.theme-ocean .sidebar-link:hover,.sidebar-link.active{background:#1d4ed8!important}
</style>
<script>
(function(){var t=localStorage.getItem('ort_medi_theme')||'white';if(t!=='white')document.documentElement.classList.add('theme-'+t);})();
</script>
</head>
<body class="bg-gray-50 text-gray-800">

<!-- ═══ AUTH OVERLAY ════════════════════════════════════════════════════════ -->
<div id="authOverlay" class="fixed inset-0 bg-gradient-to-br from-green-900 to-green-700 flex items-center justify-center z-50 p-4">
  <div class="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-md max-h-[90vh] overflow-y-auto">
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
    <div class="flex gap-2 mb-6">
      <button id="tabLoginBtn" class="tab-btn active flex-1" onclick="switchTab('login')">Sign In</button>
      <button id="tabRegBtn" class="tab-btn flex-1" onclick="switchTab('register')">Register</button>
    </div>

    <!-- Login form -->
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

    <!-- Register form -->
    <form id="registerForm" class="space-y-3 hidden">
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
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Company / Organisation Name *</label>
        <input id="regCompanyName" type="text" required maxlength="255"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
          placeholder="Acme Corp"/>
      </div>
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
            title="Change theme">🎨 Theme
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
        <div class="flex items-center justify-between mb-3">
          <h3 class="font-semibold text-gray-700 text-sm flex items-center gap-2">
            <span class="w-2 h-2 rounded-full bg-green-500 inline-block"></span>Agriculture Listings
          </h3>
          <button onclick="openAgriModal(null)"
            class="bg-green-700 text-white text-xs font-medium px-3 py-1.5 rounded-lg hover:bg-green-800 transition-colors flex items-center gap-1">
            + New Listing
          </button>
        </div>
        <div id="agricultureTable" class="overflow-x-auto">
          <p class="text-gray-400 text-sm">Loading…</p>
        </div>
      </div>

      <!-- Manufacturing -->
      <div class="bg-white rounded-2xl shadow p-5">
        <div class="flex items-center justify-between mb-3">
          <h3 class="font-semibold text-gray-700 text-sm flex items-center gap-2">
            <span class="w-2 h-2 rounded-full bg-blue-500 inline-block"></span>Manufacturing Products
          </h3>
          <button onclick="openManuModal(null)"
            class="bg-blue-700 text-white text-xs font-medium px-3 py-1.5 rounded-lg hover:bg-blue-800 transition-colors flex items-center gap-1">
            + New Product
          </button>
        </div>
        <div id="manufacturingTable" class="overflow-x-auto">
          <p class="text-gray-400 text-sm">Loading…</p>
        </div>
      </div>

      <!-- Services -->
      <div class="bg-white rounded-2xl shadow p-5">
        <div class="flex items-center justify-between mb-3">
          <h3 class="font-semibold text-gray-700 text-sm flex items-center gap-2">
            <span class="w-2 h-2 rounded-full bg-purple-500 inline-block"></span>Service Listings
          </h3>
          <button onclick="openSvcModal(null)"
            class="bg-purple-700 text-white text-xs font-medium px-3 py-1.5 rounded-lg hover:bg-purple-800 transition-colors flex items-center gap-1">
            + New Service
          </button>
        </div>
        <div id="servicesTable" class="overflow-x-auto">
          <p class="text-gray-400 text-sm">Loading…</p>
        </div>
      </div>
    </section>

    <!-- ── Analytics section ──────────────────────────────────────────── -->
    <section id="sec-analytics" class="p-6 space-y-6 hidden">
      <div id="analyticsKpis" class="grid grid-cols-2 md:grid-cols-4 gap-4"></div>
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
      <div class="bg-white rounded-2xl shadow p-5">
        <h3 class="font-semibold text-gray-700 mb-3 text-sm">Listings by Country / Region</h3>
        <canvas id="geoChart" height="120"></canvas>
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

<!-- ═══ Agriculture Modal ═══════════════════════════════════════════════════ -->
<div id="agriModal" class="hidden modal-backdrop">
  <div class="modal-box">
    <div class="flex items-center justify-between mb-4">
      <h3 id="agriModalTitle" class="font-semibold text-gray-800 text-lg">New Agriculture Listing</h3>
      <button onclick="closeAgriModal()" class="text-gray-400 hover:text-gray-600 text-xl leading-none">&times;</button>
    </div>
    <form id="agriForm" class="space-y-4">
      <input type="hidden" id="agriId"/>

      <!-- Row 1 -->
      <div>
        <label class="form-label">Title *</label>
        <input id="agriTitle" class="form-input" type="text" required maxlength="255" placeholder="e.g. Premium White Maize"/>
      </div>

      <div class="form-grid">
        <div>
          <label class="form-label">Category</label>
          <select id="agriCategory" class="form-input">
            <option value="">Select…</option>
            <option value="grains">Grains &amp; Cereals</option>
            <option value="livestock">Livestock</option>
            <option value="produce">Fresh Produce</option>
            <option value="dairy">Dairy &amp; Eggs</option>
            <option value="fruits">Fruits</option>
            <option value="vegetables">Vegetables</option>
            <option value="spices">Spices &amp; Herbs</option>
            <option value="seafood">Seafood</option>
            <option value="other">Other</option>
          </select>
        </div>
        <div>
          <label class="form-label">Commodity Type</label>
          <input id="agriCommodity" class="form-input" type="text" placeholder="e.g. Wheat, Maize, Cattle"/>
        </div>
      </div>

      <div class="form-grid">
        <div>
          <label class="form-label">Price per Unit *</label>
          <input id="agriPrice" class="form-input" type="number" step="0.01" min="0.01" required placeholder="0.00"/>
        </div>
        <div>
          <label class="form-label">Currency</label>
          <select id="agriCurrency" class="form-input">
            <option value="USD">USD</option>
            <option value="EUR">EUR</option>
            <option value="GBP">GBP</option>
            <option value="NGN">NGN</option>
            <option value="KES">KES</option>
            <option value="GHS">GHS</option>
            <option value="ZAR">ZAR</option>
            <option value="TZS">TZS</option>
            <option value="UGX">UGX</option>
          </select>
        </div>
      </div>

      <div class="form-grid">
        <div>
          <label class="form-label">Quantity Available</label>
          <input id="agriQty" class="form-input" type="number" step="0.01" min="0" placeholder="0"/>
        </div>
        <div>
          <label class="form-label">Unit</label>
          <select id="agriUnit" class="form-input">
            <option value="">Select…</option>
            <option value="kg">kg</option>
            <option value="tons">tons</option>
            <option value="litres">litres</option>
            <option value="units">units</option>
            <option value="bags">bags</option>
            <option value="crates">crates</option>
          </select>
        </div>
      </div>

      <div class="form-grid">
        <div>
          <label class="form-label">Location</label>
          <input id="agriLocation" class="form-input" type="text" placeholder="City, Country"/>
        </div>
        <div>
          <label class="form-label">Quality Grade</label>
          <input id="agriGrade" class="form-input" type="text" placeholder="e.g. Grade A, Premium"/>
        </div>
      </div>

      <div>
        <label class="form-label">📍 Google Maps Link</label>
        <input id="agriMapLink" class="form-input" type="url"
          placeholder="https://maps.app.goo.gl/... or https://www.google.com/maps?q=..."/>
        <p class="text-xs text-gray-400 mt-1">Paste a Google Maps link to tag the exact location of your produce.</p>
      </div>

      <div>
        <label class="form-label">Description</label>
        <textarea id="agriDesc" class="form-input" rows="2" placeholder="Describe your produce…"></textarea>
      </div>

      <div class="form-grid">
        <div>
          <label class="form-label">Certification</label>
          <input id="agriCert" class="form-input" type="text" placeholder="e.g. Organic, GAP"/>
        </div>
        <div>
          <label class="form-label">Status</label>
          <select id="agriStatus" class="form-input">
            <option value="available">Available</option>
            <option value="sold_out">Sold Out</option>
            <option value="reserved">Reserved</option>
            <option value="expired">Expired</option>
          </select>
        </div>
      </div>

      <div class="form-grid">
        <div>
          <label class="form-label">Harvest Date</label>
          <input id="agriHarvest" class="form-input" type="date"/>
        </div>
        <div>
          <label class="form-label">Expiry Date</label>
          <input id="agriExpiry" class="form-input" type="date"/>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <input id="agriPerishable" type="checkbox" class="rounded"/>
        <label for="agriPerishable" class="text-sm text-gray-700">Perishable item</label>
      </div>

      <!-- Image upload -->
      <div>
        <label class="form-label">Images</label>
        <div class="flex flex-wrap gap-2 mb-2" id="agriImgPreview"></div>
        <label class="cursor-pointer inline-flex items-center gap-2 text-sm text-green-700 font-medium border border-green-300 rounded-lg px-3 py-1.5 hover:bg-green-50 transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"/>
          </svg>
          Upload Images
          <input type="file" id="agriImgInput" accept="image/*" multiple class="hidden" onchange="handleAgriImages(this)"/>
        </label>
        <p class="text-xs text-gray-400 mt-1">Max 10 MB per image. JPG, PNG, WebP.</p>
      </div>

      <p id="agriFormError" class="text-red-500 text-xs hidden"></p>

      <div class="flex gap-3 pt-2">
        <button type="submit"
          class="flex-1 bg-green-700 hover:bg-green-800 text-white font-medium py-2.5 rounded-lg text-sm transition-colors">
          Save Listing
        </button>
        <button type="button" onclick="closeAgriModal()"
          class="flex-1 border border-gray-300 hover:bg-gray-50 font-medium py-2.5 rounded-lg text-sm transition-colors">
          Cancel
        </button>
      </div>
    </form>
  </div>
</div>

<!-- ═══ Manufacturing Modal ══════════════════════════════════════════════════ -->
<div id="manuModal" class="hidden modal-backdrop">
  <div class="modal-box">
    <div class="flex items-center justify-between mb-4">
      <h3 id="manuModalTitle" class="font-semibold text-gray-800 text-lg">New Manufacturing Product</h3>
      <button onclick="closeManuModal()" class="text-gray-400 hover:text-gray-600 text-xl leading-none">&times;</button>
    </div>
    <form id="manuForm" class="space-y-4">
      <input type="hidden" id="manuId"/>

      <div>
        <label class="form-label">Title *</label>
        <input id="manuTitle" class="form-input" type="text" required maxlength="255" placeholder="e.g. Hand-woven Kente Cloth"/>
      </div>

      <div class="form-grid">
        <div>
          <label class="form-label">Category</label>
          <select id="manuCategory" class="form-input">
            <option value="">Select…</option>
            <option value="textiles">Textiles &amp; Fabrics</option>
            <option value="crafts">Crafts &amp; Artisanry</option>
            <option value="processed_foods">Processed Foods</option>
            <option value="electronics">Electronics</option>
            <option value="furniture">Furniture</option>
            <option value="chemicals">Chemicals</option>
            <option value="building_materials">Building Materials</option>
            <option value="machinery">Machinery</option>
            <option value="other">Other</option>
          </select>
        </div>
        <div>
          <label class="form-label">SKU</label>
          <input id="manuSku" class="form-input" type="text" placeholder="Stock Keeping Unit"/>
        </div>
      </div>

      <div class="form-grid">
        <div>
          <label class="form-label">Wholesale Price *</label>
          <input id="manuPrice" class="form-input" type="number" step="0.01" min="0.01" required placeholder="0.00"/>
        </div>
        <div>
          <label class="form-label">Currency</label>
          <select id="manuCurrency" class="form-input">
            <option value="USD">USD</option>
            <option value="EUR">EUR</option>
            <option value="GBP">GBP</option>
            <option value="NGN">NGN</option>
            <option value="KES">KES</option>
            <option value="GHS">GHS</option>
            <option value="ZAR">ZAR</option>
            <option value="TZS">TZS</option>
            <option value="UGX">UGX</option>
          </select>
        </div>
      </div>

      <div class="form-grid">
        <div>
          <label class="form-label">Quantity Available</label>
          <input id="manuQty" class="form-input" type="number" min="0" placeholder="0"/>
        </div>
        <div>
          <label class="form-label">Unit</label>
          <select id="manuUnit" class="form-input">
            <option value="">Select…</option>
            <option value="units">units</option>
            <option value="pieces">pieces</option>
            <option value="kg">kg</option>
            <option value="tons">tons</option>
            <option value="metres">metres</option>
            <option value="litres">litres</option>
            <option value="boxes">boxes</option>
          </select>
        </div>
      </div>

      <div class="form-grid">
        <div>
          <label class="form-label">Minimum Order Qty (MOQ)</label>
          <input id="manuMoq" class="form-input" type="number" min="1" placeholder="e.g. 10"/>
        </div>
        <div>
          <label class="form-label">Lead Time (days)</label>
          <input id="manuLead" class="form-input" type="number" min="0" placeholder="e.g. 7"/>
        </div>
      </div>

      <div class="form-grid">
        <div>
          <label class="form-label">Location</label>
          <input id="manuLocation" class="form-input" type="text" placeholder="City, Country"/>
        </div>
        <div>
          <label class="form-label">Country of Origin</label>
          <input id="manuOrigin" class="form-input" type="text" placeholder="e.g. Ghana"/>
        </div>
      </div>

      <div>
        <label class="form-label">📍 Google Maps Link</label>
        <input id="manuMapLink" class="form-input" type="url"
          placeholder="https://maps.app.goo.gl/... or https://www.google.com/maps?q=..."/>
        <p class="text-xs text-gray-400 mt-1">Paste a Google Maps link to tag your factory / warehouse location.</p>
      </div>

      <div>
        <label class="form-label">Description</label>
        <textarea id="manuDesc" class="form-input" rows="2" placeholder="Describe your product…"></textarea>
      </div>

      <div class="form-grid">
        <div>
          <label class="form-label">Certifications (comma-separated)</label>
          <input id="manuCerts" class="form-input" type="text" placeholder="e.g. ISO 9001, NAFDAC"/>
        </div>
        <div>
          <label class="form-label">Status</label>
          <select id="manuStatus" class="form-input">
            <option value="available">Available</option>
            <option value="out_of_stock">Out of Stock</option>
            <option value="discontinued">Discontinued</option>
          </select>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <input id="manuLocally" type="checkbox" class="rounded" checked/>
        <label for="manuLocally" class="text-sm text-gray-700">Locally made</label>
      </div>

      <!-- Image upload -->
      <div>
        <label class="form-label">Images</label>
        <div class="flex flex-wrap gap-2 mb-2" id="manuImgPreview"></div>
        <label class="cursor-pointer inline-flex items-center gap-2 text-sm text-blue-700 font-medium border border-blue-300 rounded-lg px-3 py-1.5 hover:bg-blue-50 transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"/>
          </svg>
          Upload Images
          <input type="file" id="manuImgInput" accept="image/*" multiple class="hidden" onchange="handleManuImages(this)"/>
        </label>
        <p class="text-xs text-gray-400 mt-1">Max 10 MB per image. JPG, PNG, WebP.</p>
      </div>

      <p id="manuFormError" class="text-red-500 text-xs hidden"></p>

      <div class="flex gap-3 pt-2">
        <button type="submit"
          class="flex-1 bg-blue-700 hover:bg-blue-800 text-white font-medium py-2.5 rounded-lg text-sm transition-colors">
          Save Product
        </button>
        <button type="button" onclick="closeManuModal()"
          class="flex-1 border border-gray-300 hover:bg-gray-50 font-medium py-2.5 rounded-lg text-sm transition-colors">
          Cancel
        </button>
      </div>
    </form>
  </div>
</div>

<!-- ═══ Services Modal ════════════════════════════════════════════════════════ -->
<div id="svcModal" class="hidden modal-backdrop">
  <div class="modal-box">
    <div class="flex items-center justify-between mb-5">
      <h2 id="svcModalTitle" class="text-lg font-bold text-gray-800">New Service</h2>
      <button onclick="closeSvcModal()" class="text-gray-400 hover:text-gray-600 text-2xl leading-none">&times;</button>
    </div>
    <form onsubmit="saveSvc(); return false;" class="space-y-4">
      <div class="form-grid">
        <div>
          <label class="form-label">Service Title *</label>
          <input id="svcTitle" class="form-input" type="text" placeholder="e.g. Legal Consulting, IT Support"/>
        </div>
        <div>
          <label class="form-label">Category *</label>
          <input id="svcCategory" class="form-input" type="text" placeholder="e.g. Legal, IT, Transport, Health"/>
        </div>
      </div>
      <div class="form-grid">
        <div>
          <label class="form-label">Sub-category</label>
          <input id="svcSubCategory" class="form-input" type="text" placeholder="e.g. Corporate Law, Web Dev"/>
        </div>
        <div>
          <label class="form-label">Service Mode</label>
          <select id="svcMode" class="form-input">
            <option value="onsite">On-site</option>
            <option value="remote">Remote</option>
            <option value="hybrid">Hybrid</option>
          </select>
        </div>
      </div>
      <div class="form-grid">
        <div>
          <label class="form-label">Pricing Type</label>
          <select id="svcPricingType" class="form-input">
            <option value="negotiable">Negotiable</option>
            <option value="fixed">Fixed</option>
            <option value="hourly">Hourly</option>
            <option value="per_day">Per Day</option>
            <option value="per_project">Per Project</option>
          </select>
        </div>
        <div>
          <label class="form-label">Price</label>
          <input id="svcPrice" class="form-input" type="number" min="0" step="0.01" placeholder="Leave blank if negotiable"/>
        </div>
      </div>
      <div class="form-grid">
        <div>
          <label class="form-label">Currency</label>
          <select id="svcCurrency" class="form-input">
            <option value="UGX">UGX – Ugandan Shilling</option>
            <option value="KES">KES – Kenyan Shilling</option>
            <option value="TZS">TZS – Tanzanian Shilling</option>
            <option value="RWF">RWF – Rwandan Franc</option>
            <option value="NGN">NGN – Nigerian Naira</option>
            <option value="GHS">GHS – Ghanaian Cedi</option>
            <option value="USD">USD – US Dollar</option>
          </select>
        </div>
        <div>
          <label class="form-label">Country</label>
          <input id="svcCountry" class="form-input" type="text" placeholder="e.g. Uganda"/>
        </div>
      </div>
      <div class="form-grid">
        <div>
          <label class="form-label">City</label>
          <input id="svcCity" class="form-input" type="text" placeholder="e.g. Kampala"/>
        </div>
        <div>
          <label class="form-label">WhatsApp Number</label>
          <input id="svcWhatsapp" class="form-input" type="text" placeholder="+256 700 000000"/>
        </div>
      </div>
      <div>
        <label class="form-label">Description</label>
        <textarea id="svcDesc" class="form-input" rows="3" placeholder="Describe your service, qualifications, experience…"></textarea>
      </div>
      <div>
        <label class="form-label">Status</label>
        <select id="svcStatus" class="form-input">
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
          <option value="pending_review">Pending Review</option>
        </select>
      </div>
      <div class="flex gap-3 pt-2">
        <button type="submit"
          class="flex-1 bg-purple-700 hover:bg-purple-800 text-white font-medium py-2.5 rounded-lg text-sm transition-colors">
          Save Service
        </button>
        <button type="button" onclick="closeSvcModal()"
          class="flex-1 border border-gray-300 hover:bg-gray-50 font-medium py-2.5 rounded-lg text-sm transition-colors">
          Cancel
        </button>
      </div>
    </form>
  </div>
</div>

<script>
const API = '__API_BASE__';
let token = localStorage.getItem('medi_token') || '';
let currentUser = null;
let myTenantId = null;
let agriData = [];
let manuData = [];
let agriImgUrls = [];
let manuImgUrls = [];
let agriChartInst = null;
let manuChartInst = null;
let geoChartInst = null;

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

async function enterPortal() {
  document.getElementById('authOverlay').classList.add('hidden');
  document.getElementById('app').classList.remove('hidden');
  if (currentUser) {
    document.getElementById('portalEmail').textContent =
      currentUser.email || currentUser.company_name || '';
  }
  await findMyTenant();
  showSection('postings');
}

async function findMyTenant() {
  if (!currentUser) return;
  try {
    const r = await fetch(`${API}/tenants/?limit=500`, { headers: authHeaders() });
    if (!r.ok) return;
    const tenants = await r.json();
    const mine = (Array.isArray(tenants) ? tenants : []).find(t => t.owner_user_id === currentUser.id);
    if (mine) myTenantId = mine.id;
  } catch { /* silently ignore */ }
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
  if (accountType === 'organization') payload.org_type = document.getElementById('regOrgType').value;
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
  myTenantId = null;
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
  await Promise.all([loadAgriculture(), loadManufacturing(), loadServices()]);
}

async function loadAgriculture() {
  const el = document.getElementById('agricultureTable');
  el.innerHTML = '<p class="text-gray-400 text-sm">Loading…</p>';
  try {
    let url = `${API}/agriculture/?limit=200`;
    if (myTenantId) url += `&tenant_id=${myTenantId}`;
    const r = await fetch(url, { headers: authHeaders() });
    const data = await r.json();
    agriData = Array.isArray(data) ? data : (data.listings || data.items || []);
    renderAgriTable(agriData);
  } catch { el.innerHTML = '<p class="text-red-500 text-sm">Failed to load listings.</p>'; }
}

function renderAgriTable(items) {
  const el = document.getElementById('agricultureTable');
  if (!items.length) {
    el.innerHTML = '<p class="text-gray-400 text-sm py-2">No agriculture listings yet. Click "+ New Listing" to add one.</p>';
    return;
  }
  el.innerHTML = `<table class="min-w-full text-sm">
    <thead class="bg-gray-50 border-b"><tr>
      <th class="px-3 py-2 text-left font-semibold text-gray-600 w-12">Img</th>
      <th class="px-3 py-2 text-left font-semibold text-gray-600">Title</th>
      <th class="px-3 py-2 text-left font-semibold text-gray-600">Category</th>
      <th class="px-3 py-2 text-left font-semibold text-gray-600">Status</th>
      <th class="px-3 py-2 text-left font-semibold text-gray-600">Price/Unit</th>
      <th class="px-3 py-2 text-left font-semibold text-gray-600">Location</th>
      <th class="px-3 py-2 text-left font-semibold text-gray-600">Actions</th>
    </tr></thead>
    <tbody class="divide-y divide-gray-100">
      ${items.map(i => `<tr class="hover:bg-gray-50">
        <td class="px-3 py-2">${imgThumb(i.images)}</td>
        <td class="px-3 py-2 font-medium max-w-xs truncate">${esc(i.title)}</td>
        <td class="px-3 py-2 text-gray-500">${esc(i.category||'—')}</td>
        <td class="px-3 py-2"><span class="badge ${statusColor(i.status)}">${esc(i.status||'')}</span></td>
        <td class="px-3 py-2">${i.price_per_unit!=null?Number(i.price_per_unit).toFixed(2)+' '+(i.currency||'USD'):'—'}</td>
        <td class="px-3 py-2 text-gray-500">${i.map_link && isSafeUrl(i.map_link)
          ? `<a href="${esc(i.map_link)}" target="_blank" rel="noopener noreferrer" class="text-green-700 underline text-xs">📍 Map</a>${i.location ? ' · '+esc(i.location) : ''}`
          : esc(i.location||'—')}</td>
        <td class="px-3 py-2">
          <button onclick="openAgriModal(agriData.find(x=>x.id===${i.id}))" class="text-blue-600 hover:text-blue-800 text-xs font-medium mr-2">Edit</button>
          <button onclick="deleteAgri(${i.id})" class="text-red-500 hover:text-red-700 text-xs font-medium">Delete</button>
        </td>
      </tr>`).join('')}
    </tbody></table>`;
}

async function loadManufacturing() {
  const el = document.getElementById('manufacturingTable');
  el.innerHTML = '<p class="text-gray-400 text-sm">Loading…</p>';
  try {
    let url = `${API}/manufacturing/?limit=200`;
    if (myTenantId) url += `&tenant_id=${myTenantId}`;
    const r = await fetch(url, { headers: authHeaders() });
    const data = await r.json();
    manuData = Array.isArray(data) ? data : (data.products || data.items || []);
    renderManuTable(manuData);
  } catch { el.innerHTML = '<p class="text-red-500 text-sm">Failed to load products.</p>'; }
}

function renderManuTable(items) {
  const el = document.getElementById('manufacturingTable');
  if (!items.length) {
    el.innerHTML = '<p class="text-gray-400 text-sm py-2">No manufacturing products yet. Click "+ New Product" to add one.</p>';
    return;
  }
  el.innerHTML = `<table class="min-w-full text-sm">
    <thead class="bg-gray-50 border-b"><tr>
      <th class="px-3 py-2 text-left font-semibold text-gray-600 w-12">Img</th>
      <th class="px-3 py-2 text-left font-semibold text-gray-600">Title</th>
      <th class="px-3 py-2 text-left font-semibold text-gray-600">Category</th>
      <th class="px-3 py-2 text-left font-semibold text-gray-600">Status</th>
      <th class="px-3 py-2 text-left font-semibold text-gray-600">Wholesale Price</th>
      <th class="px-3 py-2 text-left font-semibold text-gray-600">Location</th>
      <th class="px-3 py-2 text-left font-semibold text-gray-600">Actions</th>
    </tr></thead>
    <tbody class="divide-y divide-gray-100">
      ${items.map(i => `<tr class="hover:bg-gray-50">
        <td class="px-3 py-2">${imgThumb(i.images)}</td>
        <td class="px-3 py-2 font-medium max-w-xs truncate">${esc(i.title)}</td>
        <td class="px-3 py-2 text-gray-500">${esc(i.category||'—')}</td>
        <td class="px-3 py-2"><span class="badge ${statusColor(i.status)}">${esc(i.status||'')}</span></td>
        <td class="px-3 py-2">${i.wholesale_price!=null?Number(i.wholesale_price).toFixed(2)+' '+(i.currency||'USD'):'—'}</td>
        <td class="px-3 py-2 text-gray-500">${i.map_link && isSafeUrl(i.map_link)
          ? `<a href="${esc(i.map_link)}" target="_blank" rel="noopener noreferrer" class="text-blue-700 underline text-xs">📍 Map</a>${i.location ? ' · '+esc(i.location) : ''}`
          : esc(i.location||'—')}</td>
        <td class="px-3 py-2">
          <button onclick="openManuModal(manuData.find(x=>x.id===${i.id}))" class="text-blue-600 hover:text-blue-800 text-xs font-medium mr-2">Edit</button>
          <button onclick="deleteManu(${i.id})" class="text-red-500 hover:text-red-700 text-xs font-medium">Delete</button>
        </td>
      </tr>`).join('')}
    </tbody></table>`;
}

// ── Image upload helper ─────────────────────────────────────────────────────
async function uploadImages(files) {
  const urls = [];
  for (const file of files) {
    const fd = new FormData();
    fd.append('file', file);
    try {
      const r = await fetch(`${API}/upload/image`, { method: 'POST', body: fd });
      if (r.ok) {
        const d = await r.json();
        if (d.url) urls.push(d.url);
      } else {
        showToast('Image upload failed: ' + file.name, true);
      }
    } catch { showToast('Network error uploading: ' + file.name, true); }
  }
  return urls;
}

function renderImgPreview(containerId, urls) {
  const isAgri = containerId === 'agriImgPreview';
  const el = document.getElementById(containerId);
  el.innerHTML = urls.map((u, i) =>
    `<div class="relative group">
       <img src="${esc(u)}" class="img-thumb" onerror="this.src='data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 40 40%22><rect width=%2240%22 height=%2240%22 fill=%22%23e5e7eb%22/><text x=%2250%25%22 y=%2255%25%22 dominant-baseline=%22middle%22 text-anchor=%22middle%22 font-size=%2212%22>?</text></svg>'"/>
       <button type="button" onclick="${isAgri ? 'removeAgriImg' : 'removeManuImg'}(this)" data-idx="${i}"
         class="hidden group-hover:flex absolute -top-1 -right-1 w-4 h-4 bg-red-500 text-white rounded-full text-xs items-center justify-center leading-none">×</button>
     </div>`
  ).join('');
}

function removeAgriImg(btn) {
  const idx = parseInt(btn.dataset.idx);
  agriImgUrls.splice(idx, 1);
  renderImgPreview('agriImgPreview', agriImgUrls);
}

function removeManuImg(btn) {
  const idx = parseInt(btn.dataset.idx);
  manuImgUrls.splice(idx, 1);
  renderImgPreview('manuImgPreview', manuImgUrls);
}

async function handleAgriImages(input) {
  if (!input.files.length) return;
  showToast('Uploading images…');
  const urls = await uploadImages(Array.from(input.files));
  agriImgUrls = [...agriImgUrls, ...urls];
  renderImgPreview('agriImgPreview', agriImgUrls);
  input.value = '';
}

async function handleManuImages(input) {
  if (!input.files.length) return;
  showToast('Uploading images…');
  const urls = await uploadImages(Array.from(input.files));
  manuImgUrls = [...manuImgUrls, ...urls];
  renderImgPreview('manuImgPreview', manuImgUrls);
  input.value = '';
}

// ── Agriculture CRUD ──────────────────────────────────────────────────────
function openAgriModal(item) {
  agriImgUrls = item?.images ? [...item.images] : [];
  renderImgPreview('agriImgPreview', agriImgUrls);

  document.getElementById('agriId').value = item?.id || '';
  document.getElementById('agriModalTitle').textContent = item ? 'Edit Agriculture Listing' : 'New Agriculture Listing';
  document.getElementById('agriTitle').value = item?.title || '';
  document.getElementById('agriCategory').value = item?.category || '';
  document.getElementById('agriCommodity').value = item?.commodity_type || '';
  document.getElementById('agriPrice').value = item?.price_per_unit != null ? Number(item.price_per_unit) : '';
  document.getElementById('agriCurrency').value = item?.currency || 'USD';
  document.getElementById('agriQty').value = item?.quantity_available ?? '';
  document.getElementById('agriUnit').value = item?.unit || '';
  document.getElementById('agriLocation').value = item?.location || '';
  document.getElementById('agriGrade').value = item?.quality_grade || '';
  document.getElementById('agriMapLink').value = item?.map_link || '';
  document.getElementById('agriDesc').value = item?.description || '';
  document.getElementById('agriCert').value = item?.certification || '';
  document.getElementById('agriStatus').value = item?.status || 'available';
  document.getElementById('agriHarvest').value = item?.harvest_date ? item.harvest_date.slice(0,10) : '';
  document.getElementById('agriExpiry').value = item?.expiry_date ? item.expiry_date.slice(0,10) : '';
  document.getElementById('agriPerishable').checked = item?.is_perishable || false;
  document.getElementById('agriFormError').classList.add('hidden');
  document.getElementById('agriModal').classList.remove('hidden');
}

function closeAgriModal() { document.getElementById('agriModal').classList.add('hidden'); }

document.getElementById('agriForm').addEventListener('submit', async e => {
  e.preventDefault();
  const errEl = document.getElementById('agriFormError');
  errEl.classList.add('hidden');
  const id = document.getElementById('agriId').value;

  const payload = {
    title: document.getElementById('agriTitle').value.trim(),
    category: document.getElementById('agriCategory').value || null,
    commodity_type: document.getElementById('agriCommodity').value.trim() || null,
    price_per_unit: parseFloat(document.getElementById('agriPrice').value),
    currency: document.getElementById('agriCurrency').value,
    quantity_available: document.getElementById('agriQty').value ? parseFloat(document.getElementById('agriQty').value) : null,
    unit: document.getElementById('agriUnit').value || null,
    location: document.getElementById('agriLocation').value.trim() || null,
    quality_grade: document.getElementById('agriGrade').value.trim() || null,
    map_link: document.getElementById('agriMapLink').value.trim() || null,
    description: document.getElementById('agriDesc').value.trim() || null,
    certification: document.getElementById('agriCert').value.trim() || null,
    status: document.getElementById('agriStatus').value,
    harvest_date: document.getElementById('agriHarvest').value || null,
    expiry_date: document.getElementById('agriExpiry').value || null,
    is_perishable: document.getElementById('agriPerishable').checked,
    images: agriImgUrls.length ? agriImgUrls : null,
  };

  if (!id && myTenantId) payload.tenant_id = myTenantId;

  try {
    const method = id ? 'PUT' : 'POST';
    const url = id ? `${API}/agriculture/${id}` : `${API}/agriculture/`;
    const r = await fetch(url, {
      method,
      headers: authHeaders(),
      body: JSON.stringify(payload),
    });
    const data = await r.json();
    if (!r.ok) { errEl.textContent = data.detail || 'Save failed'; errEl.classList.remove('hidden'); return; }
    showToast(id ? 'Listing updated!' : 'Listing created!');
    closeAgriModal();
    await loadAgriculture();
  } catch { errEl.textContent = 'Network error. Please try again.'; errEl.classList.remove('hidden'); }
});

async function deleteAgri(id) {
  if (!confirm('Delete this agriculture listing?')) return;
  try {
    const r = await fetch(`${API}/agriculture/${id}`, { method: 'DELETE', headers: authHeaders() });
    if (r.ok || r.status === 404) { showToast('Listing deleted.'); await loadAgriculture(); }
    else { const d = await r.json(); showToast(d.detail || 'Delete failed', true); }
  } catch { showToast('Network error.', true); }
}

// ── Manufacturing CRUD ─────────────────────────────────────────────────────
function openManuModal(item) {
  manuImgUrls = item?.images ? [...item.images] : [];
  renderImgPreview('manuImgPreview', manuImgUrls);

  document.getElementById('manuId').value = item?.id || '';
  document.getElementById('manuModalTitle').textContent = item ? 'Edit Manufacturing Product' : 'New Manufacturing Product';
  document.getElementById('manuTitle').value = item?.title || '';
  document.getElementById('manuCategory').value = item?.category || '';
  document.getElementById('manuSku').value = item?.sku || '';
  document.getElementById('manuPrice').value = item?.wholesale_price != null ? Number(item.wholesale_price) : '';
  document.getElementById('manuCurrency').value = item?.currency || 'USD';
  document.getElementById('manuQty').value = item?.quantity_available ?? '';
  document.getElementById('manuUnit').value = item?.unit || '';
  document.getElementById('manuMoq').value = item?.moq ?? '';
  document.getElementById('manuLead').value = item?.lead_time_days ?? '';
  document.getElementById('manuLocation').value = item?.location || '';
  document.getElementById('manuOrigin').value = item?.country_of_origin || '';
  document.getElementById('manuMapLink').value = item?.map_link || '';
  document.getElementById('manuDesc').value = item?.description || '';
  document.getElementById('manuCerts').value = item?.certifications ? item.certifications.join(', ') : '';
  document.getElementById('manuStatus').value = item?.status || 'available';
  document.getElementById('manuLocally').checked = item?.is_locally_made !== false;
  document.getElementById('manuFormError').classList.add('hidden');
  document.getElementById('manuModal').classList.remove('hidden');
}

function closeManuModal() { document.getElementById('manuModal').classList.add('hidden'); }

document.getElementById('manuForm').addEventListener('submit', async e => {
  e.preventDefault();
  const errEl = document.getElementById('manuFormError');
  errEl.classList.add('hidden');
  const id = document.getElementById('manuId').value;

  const certStr = document.getElementById('manuCerts').value.trim();
  const certifications = certStr ? certStr.split(',').map(c => c.trim()).filter(Boolean) : null;

  const payload = {
    title: document.getElementById('manuTitle').value.trim(),
    category: document.getElementById('manuCategory').value || null,
    sku: document.getElementById('manuSku').value.trim() || null,
    wholesale_price: parseFloat(document.getElementById('manuPrice').value),
    currency: document.getElementById('manuCurrency').value,
    quantity_available: document.getElementById('manuQty').value ? parseInt(document.getElementById('manuQty').value) : null,
    unit: document.getElementById('manuUnit').value || null,
    moq: document.getElementById('manuMoq').value ? parseInt(document.getElementById('manuMoq').value) : null,
    lead_time_days: document.getElementById('manuLead').value ? parseInt(document.getElementById('manuLead').value) : null,
    location: document.getElementById('manuLocation').value.trim() || null,
    country_of_origin: document.getElementById('manuOrigin').value.trim() || null,
    map_link: document.getElementById('manuMapLink').value.trim() || null,
    description: document.getElementById('manuDesc').value.trim() || null,
    certifications,
    status: document.getElementById('manuStatus').value,
    is_locally_made: document.getElementById('manuLocally').checked,
    images: manuImgUrls.length ? manuImgUrls : null,
  };

  if (!id && myTenantId) payload.tenant_id = myTenantId;

  try {
    const method = id ? 'PUT' : 'POST';
    const url = id ? `${API}/manufacturing/${id}` : `${API}/manufacturing/`;
    const r = await fetch(url, {
      method,
      headers: authHeaders(),
      body: JSON.stringify(payload),
    });
    const data = await r.json();
    if (!r.ok) { errEl.textContent = data.detail || 'Save failed'; errEl.classList.remove('hidden'); return; }
    showToast(id ? 'Product updated!' : 'Product created!');
    closeManuModal();
    await loadManufacturing();
  } catch { errEl.textContent = 'Network error. Please try again.'; errEl.classList.remove('hidden'); }
});

async function deleteManu(id) {
  if (!confirm('Delete this manufacturing product?')) return;
  try {
    const r = await fetch(`${API}/manufacturing/${id}`, { method: 'DELETE', headers: authHeaders() });
    if (r.ok || r.status === 404) { showToast('Product deleted.'); await loadManufacturing(); }
    else { const d = await r.json(); showToast(d.detail || 'Delete failed', true); }
  } catch { showToast('Network error.', true); }
}

// ── Analytics ──────────────────────────────────────────────────────────────
async function loadAnalytics() {
  if (!agriData.length && !manuData.length) await loadPostings();
  renderAnalyticsKPIs();
  renderStatusChart('agriChart', agriData, agriChartInst, c => agriChartInst = c);
  renderStatusChart('manuChart', manuData, manuChartInst, c => manuChartInst = c);
  renderGeoChart();
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

function renderAnalyticsKPIs() {
  const allListings = [...agriData, ...manuData];
  const totalListings = allListings.length;
  const summary = allListings.reduce((acc, item) => {
    if (item.status === 'available') acc.available += 1;
    const country = inferCountry(item);
    if (country) acc.countries.add(country);
    return acc;
  }, { available: 0, countries: new Set() });
  const availableListings = summary.available;
  const uniqueCountries = summary.countries.size;
  const kpis = [
    {label:'Total Listings', value:totalListings, color:'text-green-700'},
    {label:'Available Listings', value:availableListings, color:'text-blue-700'},
    {label:'Availability Rate', value: totalListings ? `${Math.round((availableListings/totalListings)*100)}%` : '0%', color:'text-purple-700'},
    {label:'Countries/Regions', value:uniqueCountries, color:'text-orange-700'},
  ];
  document.getElementById('analyticsKpis').innerHTML = kpis.map(k => `
    <div class="bg-white rounded-2xl shadow p-4">
      <div class="text-xl font-bold ${k.color}">${esc(String(k.value))}</div>
      <div class="text-xs text-gray-500 mt-1">${k.label}</div>
    </div>
  `).join('');
}

function inferCountry(item) {
  // Keep country parsing aligned with backend location-country extraction.
  const explicit = item?.country_of_origin || item?.country;
  if (explicit) return String(explicit).trim();
  const location = item?.location;
  if (!location) return null;
  const parts = String(location).split(',').map(p => p.trim()).filter(Boolean);
  if (!parts.length) return null;
  return parts[parts.length - 1];
}

function renderGeoChart() {
  const countryCounts = {};
  [...agriData, ...manuData].forEach(item => {
    const country = inferCountry(item);
    if (!country) return;
    countryCounts[country] = (countryCounts[country] || 0) + 1;
  });
  const sorted = Object.entries(countryCounts).sort((a,b) => b[1]-a[1]).slice(0, 10);
  if (geoChartInst) geoChartInst.destroy();
  const ctx = document.getElementById('geoChart');
  if (!ctx) return;
  geoChartInst = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: sorted.map(([country]) => country),
      datasets: [{ label: 'Listings', data: sorted.map(([,count]) => count), backgroundColor: '#0ea5e9' }],
    },
    options: { responsive: true, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } },
  });
}

// ── Profile ────────────────────────────────────────────────────────────────
function loadProfile() {
  if (!currentUser) return;
  const el = document.getElementById('profileDetails');
  const fields = [
    ['Name', `${currentUser.first_name||''} ${currentUser.last_name||''}`.trim()],
    ['Email', currentUser.email],
    ['Role', currentUser.role],
    ['Business Email', currentUser.business_email],
    ['Business Phone', currentUser.business_phone],
    ['Address', currentUser.address],
    ['Country', currentUser.country],
    ['Tenant ID', myTenantId],
  ].filter(([,v]) => v);
  el.innerHTML = fields.map(([k,v]) =>
    `<div class="flex gap-3"><span class="font-medium text-gray-700 w-32 shrink-0">${esc(String(k))}</span><span>${esc(String(v))}</span></div>`
  ).join('');
}

// ── Utilities ──────────────────────────────────────────────────────────────
function isSafeUrl(url) {
  try {
    const u = new URL(url);
    return u.protocol === 'https:' || u.protocol === 'http:';
  } catch { return false; }
}

function imgThumb(images) {
  if (!images || !images.length) return '<span class="text-gray-300 text-lg">🖼</span>';
  return `<img src="${esc(images[0])}" class="img-thumb" onerror="this.style.display='none'" loading="lazy"/>`;
}

function statusColor(s) {
  const map = {
    available:'bg-green-100 text-green-800',
    sold_out:'bg-red-100 text-red-800',
    reserved:'bg-yellow-100 text-yellow-800',
    expired:'bg-gray-100 text-gray-600',
    out_of_stock:'bg-red-100 text-red-800',
    discontinued:'bg-gray-100 text-gray-600',
    pending:'bg-yellow-100 text-yellow-800',
    inactive:'bg-gray-100 text-gray-600',
  };
  return map[s] || 'bg-gray-100 text-gray-600';
}

function esc(s) {
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
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

// Close modals on backdrop click
document.getElementById('agriModal').addEventListener('click', function(e) {
  if (e.target === this) closeAgriModal();
});
document.getElementById('manuModal').addEventListener('click', function(e) {
  if (e.target === this) closeManuModal();
});
document.getElementById('svcModal')?.addEventListener('click', function(e) {
  if (e.target === this) closeSvcModal();
});

// ── Services CRUD ────────────────────────────────────────────────────────────
async function loadServices() {
  const el = document.getElementById('servicesTable');
  if (!el) return;
  try {
    let url = `${API}/services/?limit=200`;
    const uid = _currentUser?.id;
    if (uid) url += `&posted_by_user_id=${uid}`;
    const r = await fetch(url, { headers: authHeaders() });
    if (!r.ok) { renderServicesTable(el, []); return; }
    const data = await r.json();
    const items = Array.isArray(data) ? data : (data.items || data.services || []);
    renderServicesTable(el, items);
  } catch { renderServicesTable(el, []); }
}

function renderServicesTable(el, items) {
  if (!items.length) {
    el.innerHTML = '<p class="text-gray-400 text-sm py-2">No service listings yet. Click "+ New Service" to add one.</p>';
    return;
  }
  el.innerHTML = `<table class="min-w-full text-xs text-gray-700">
    <thead><tr class="bg-gray-50 text-gray-500 uppercase text-xs">
      <th class="px-3 py-2 text-left">Image</th>
      <th class="px-3 py-2 text-left">Title</th>
      <th class="px-3 py-2 text-left">Category</th>
      <th class="px-3 py-2 text-left">Price</th>
      <th class="px-3 py-2 text-left">Country</th>
      <th class="px-3 py-2 text-left">Status</th>
      <th class="px-3 py-2 text-left">Actions</th>
    </tr></thead>
    <tbody>${items.map(i=>`
    <tr class="border-b hover:bg-gray-50">
      <td class="px-3 py-2">${imgThumb(i.images)}</td>
      <td class="px-3 py-2 font-medium max-w-[140px] truncate">${esc(i.title||'')}</td>
      <td class="px-3 py-2">${esc(i.category||'')}</td>
      <td class="px-3 py-2">${i.price ? (i.price_currency||'UGX')+' '+Number(i.price).toLocaleString() : i.pricing_type||'Negotiable'}</td>
      <td class="px-3 py-2">${esc(i.country||'')}</td>
      <td class="px-3 py-2"><span class="badge ${statusColor(i.status)}">${esc(i.status||'')}</span></td>
      <td class="px-3 py-2 flex gap-1">
        <button onclick="openSvcModal(${JSON.stringify(i).replace(/"/g,'&quot;')})" class="text-purple-600 hover:underline">Edit</button>
        <button onclick="deleteSvc(${i.id})" class="text-red-500 hover:underline ml-1">Del</button>
      </td>
    </tr>`).join('')}</tbody>
  </table>`;
}

let _svcEditId = null;
function openSvcModal(item) {
  _svcEditId = item?.id || null;
  const m = document.getElementById('svcModal');
  if (!m) return;
  document.getElementById('svcTitle').value = item?.title||'';
  document.getElementById('svcCategory').value = item?.category||'';
  document.getElementById('svcSubCategory').value = item?.sub_category||'';
  document.getElementById('svcMode').value = item?.service_mode||'onsite';
  document.getElementById('svcPricingType').value = item?.pricing_type||'negotiable';
  document.getElementById('svcPrice').value = item?.price||'';
  document.getElementById('svcCurrency').value = item?.price_currency||'UGX';
  document.getElementById('svcCountry').value = item?.country||'Uganda';
  document.getElementById('svcCity').value = item?.city||'';
  document.getElementById('svcWhatsapp').value = item?.whatsapp_number||'';
  document.getElementById('svcDesc').value = item?.description||'';
  document.getElementById('svcStatus').value = item?.status||'active';
  document.getElementById('svcModalTitle').textContent = _svcEditId ? 'Edit Service' : 'New Service';
  m.classList.remove('hidden');
}
function closeSvcModal() {
  document.getElementById('svcModal')?.classList.add('hidden');
  _svcEditId = null;
}
async function saveSvc() {
  const payload = {
    title: document.getElementById('svcTitle').value.trim(),
    category: document.getElementById('svcCategory').value.trim(),
    sub_category: document.getElementById('svcSubCategory').value.trim()||null,
    service_mode: document.getElementById('svcMode').value||null,
    pricing_type: document.getElementById('svcPricingType').value,
    price: parseFloat(document.getElementById('svcPrice').value)||null,
    price_currency: document.getElementById('svcCurrency').value||'UGX',
    country: document.getElementById('svcCountry').value.trim()||null,
    city: document.getElementById('svcCity').value.trim()||null,
    whatsapp_number: document.getElementById('svcWhatsapp').value.trim()||null,
    description: document.getElementById('svcDesc').value.trim()||null,
    status: document.getElementById('svcStatus').value,
  };
  if (!payload.title) { showToast('Title is required', true); return; }
  if (!payload.category) { showToast('Category is required', true); return; }
  try {
    const url = _svcEditId ? `${API}/services/${_svcEditId}` : `${API}/services/`;
    const method = _svcEditId ? 'PUT' : 'POST';
    const r = await fetch(url, { method, headers: {...authHeaders(),'Content-Type':'application/json'}, body: JSON.stringify(payload) });
    if (!r.ok) { const e=await r.json(); showToast(e.detail||'Save failed', true); return; }
    showToast(_svcEditId ? 'Service updated' : 'Service created');
    closeSvcModal();
    loadServices();
  } catch { showToast('Network error', true); }
}
async function deleteSvc(id) {
  if (!confirm('Delete this service listing?')) return;
  try {
    const r = await fetch(`${API}/services/${id}`, { method: 'DELETE', headers: authHeaders() });
    if (!r.ok) { showToast('Delete failed', true); return; }
    showToast('Service deleted');
    loadServices();
  } catch { showToast('Network error', true); }
}

// Also call at init if postings section is active
if (document.getElementById('servicesTable')) loadServices();
</script>
</body>
</html>"""

_HTML = _HTML.replace('__API_BASE__', _API_BASE)


@router.get("/medi", response_class=HTMLResponse, include_in_schema=False)
def medi_portal():
    return HTMLResponse(content=_HTML)
