"""
Backend-rendered admin dashboard served at /const.

Authentication is handled entirely in JavaScript via the existing
/api/v1/auth/login endpoint.  The JWT is kept in localStorage and
attached to every admin-API call.  No Flutter required.
"""
import os
from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["admin-ui"])

_API_BASE = os.getenv("API_BASE_URL", "/api/v1")

_HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Ort Admin Console</title>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"
        integrity="sha256-oFMFVRpPnlzr3h4TpMCoLHpRSdVTnLMBSPdqvEK2oiU="
        crossorigin="anonymous"></script>
<style>
  body{font-family:'Inter',system-ui,sans-serif}
  .sidebar-link{display:flex;align-items:center;gap:0.75rem;padding:0.625rem 1rem;border-radius:0.5rem;color:#d1d5db;transition:background-color 0.15s,color 0.15s;cursor:pointer;font-size:0.875rem;font-weight:500;background:none;border:none;width:100%;text-align:left}
  .sidebar-link:hover{background-color:#15803d;color:#fff}
  .badge{display:inline-block;padding:0.125rem 0.5rem;border-radius:9999px;font-size:0.75rem;font-weight:600}
  #toast{transition:opacity .3s}
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
  /* ── Ocean theme ────────────────────────────────────────────────────────── */
  html.theme-ocean body{background:#eff6ff!important}
  html.theme-ocean aside{background:#1e3a8a!important}
  html.theme-ocean .border-green-800{border-color:#1d4ed8!important}
  html.theme-ocean .bg-green-600{background:#2563eb!important}
  html.theme-ocean .text-green-400{color:#93c5fd!important}
  html.theme-ocean .text-green-700{color:#1d4ed8!important}
  html.theme-ocean .bg-green-700{background:#1d4ed8!important}
  html.theme-ocean .border-green-200{border-color:#bfdbfe!important}
  html.theme-ocean .sidebar-link:hover{background:#1d4ed8!important}
  html.theme-ocean .bg-green-50{background:#eff6ff!important}
</style>
<script>
(function(){var t=localStorage.getItem('ort_admin_theme')||'white';if(t!=='white')document.documentElement.classList.add('theme-'+t);})();
</script>
</head>
<body class="bg-gray-50 text-gray-800">

<!-- ═══ LOGIN OVERLAY ═══════════════════════════════════════════════════════ -->
<div id="loginOverlay" class="fixed inset-0 bg-gradient-to-br from-green-900 to-green-700 flex items-center justify-center z-50">
  <div class="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-sm">
    <div class="flex flex-col items-center mb-6">
      <div class="w-14 h-14 rounded-full bg-green-100 flex items-center justify-center mb-3">
        <svg class="w-8 h-8 text-green-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/>
        </svg>
      </div>
      <h1 class="text-2xl font-bold text-gray-900">Ort Admin Console</h1>
      <p id="loginSubtitle" class="text-gray-400 text-sm mt-1">Sign in with admin credentials</p>
    </div>
    <!-- Login form -->
    <form id="loginForm" class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Username / Email</label>
        <input id="loginUsername" type="text" required autocomplete="username"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
          placeholder="admin or admin@example.com"/>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Password</label>
        <input id="loginPassword" type="password" required autocomplete="current-password"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
          placeholder="••••••••"/>
      </div>
      <p id="loginError" class="text-red-500 text-xs hidden"></p>
      <button type="submit"
        class="w-full bg-green-700 hover:bg-green-800 text-white font-semibold py-2.5 rounded-lg transition-colors text-sm">
        Sign In
      </button>
    </form>
    <!-- One-time setup form (shown when no admin is configured) -->
    <form id="setupForm" class="space-y-4 hidden">
      <div class="rounded-lg bg-amber-50 border border-amber-200 px-3 py-2 text-xs text-amber-800 mb-2">
        ⚠️ No admin account is configured. Create the one-time admin account below.
        This form is only available once.
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Choose Username</label>
        <input id="setupUsername" type="text" required autocomplete="username"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
          placeholder="admin or admin@example.com"/>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Choose Password <span class="text-gray-400 font-normal">(min 8 chars)</span></label>
        <input id="setupPassword" type="password" required autocomplete="new-password" minlength="8"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
          placeholder="••••••••"/>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Confirm Password</label>
        <input id="setupPasswordConfirm" type="password" required autocomplete="new-password"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
          placeholder="••••••••"/>
      </div>
      <p id="setupError" class="text-red-500 text-xs hidden"></p>
      <button type="submit"
        class="w-full bg-green-700 hover:bg-green-800 text-white font-semibold py-2.5 rounded-lg transition-colors text-sm">
        Create Admin Account
      </button>
      <button type="button" onclick="showLoginForm()"
        class="w-full text-green-700 text-xs text-center hover:underline mt-1">
        ← Back to Sign In
      </button>
    </form>
  </div>
</div>

<!-- ═══ MAIN LAYOUT ══════════════════════════════════════════════════════════ -->
<div id="app" class="hidden min-h-screen flex">

  <!-- Sidebar -->
  <aside class="w-64 bg-green-900 text-white flex flex-col shrink-0">
    <div class="px-5 py-5 border-b border-green-800">
      <div class="flex items-center gap-3">
        <div class="w-9 h-9 rounded-full bg-green-600 flex items-center justify-center">
          <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/>
          </svg>
        </div>
        <div>
          <div class="font-bold text-white text-sm">Ort Console</div>
          <div id="adminEmail" class="text-green-400 text-xs truncate max-w-[140px]"></div>
        </div>
      </div>
    </div>
    <nav class="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
      <button class="sidebar-link" onclick="showSection('dashboard')" aria-label="Dashboard">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>
        </svg>Dashboard</button>
      <button class="sidebar-link" onclick="showSection('users')" aria-label="Users">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/>
        </svg>Users</button>
      <button class="sidebar-link" onclick="showSection('content')" aria-label="Content">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>Content</button>
      <button class="sidebar-link" onclick="showSection('reports')" aria-label="Reports">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
        </svg>Reports</button>
      <button class="sidebar-link" onclick="showSection('tickets')" aria-label="Tickets">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M15 5v2m0 4v2m0 4v2M5 5a2 2 0 00-2 2v3a2 2 0 110 4v3a2 2 0 002 2h14a2 2 0 002-2v-3a2 2 0 110-4V7a2 2 0 00-2-2H5z"/>
        </svg>Tickets</button>
      <button class="sidebar-link" onclick="showSection('logs')" aria-label="Audit Logs">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>Audit Logs</button>
      <button class="sidebar-link" onclick="showSection('broadcast')" aria-label="Broadcast">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z"/>
        </svg>Broadcast</button>
      <button class="sidebar-link" onclick="showSection('deleted')" aria-label="Deleted Items">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
        </svg>Deleted Items</button>
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
    <!-- Top bar -->
    <header class="bg-white border-b px-6 py-3 flex items-center justify-between sticky top-0 z-10 shadow-sm">
      <h2 id="pageTitle" class="text-lg font-semibold text-gray-800">Dashboard</h2>
      <div class="flex items-center gap-3">
        <span id="lastRefresh" class="text-xs text-gray-400"></span>
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

    <!-- Toast notification -->
    <div id="toast" class="hidden fixed top-4 right-4 z-50 px-4 py-3 rounded-xl shadow-lg text-white text-sm font-medium max-w-xs"></div>

    <!-- ── Dashboard section ──────────────────────────────────────────── -->
    <section id="sec-dashboard" class="p-6 space-y-6">
      <div id="statsGrid" class="grid grid-cols-2 md:grid-cols-4 gap-4"></div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="bg-white rounded-2xl shadow p-5">
          <h3 class="font-semibold text-gray-700 mb-3 text-sm">Users by Role</h3>
          <canvas id="roleChart" height="180"></canvas>
        </div>
        <div class="bg-white rounded-2xl shadow p-5">
          <h3 class="font-semibold text-gray-700 mb-3 text-sm">Orders by Status</h3>
          <canvas id="orderChart" height="180"></canvas>
        </div>
      </div>
      <div class="bg-white rounded-2xl shadow p-5">
        <h3 class="font-semibold text-gray-700 mb-3 text-sm">Activity — Last 30 Days</h3>
        <canvas id="activityChart" height="100"></canvas>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="bg-white rounded-2xl shadow p-5">
          <h3 class="font-semibold text-gray-700 mb-3 text-sm">Tracking by Country</h3>
          <canvas id="countryChart" height="180"></canvas>
        </div>
        <div class="bg-white rounded-2xl shadow p-5">
          <h3 class="font-semibold text-gray-700 mb-3 text-sm">Top Tracking Locations</h3>
          <canvas id="locationChart" height="180"></canvas>
        </div>
      </div>
      <div class="bg-white rounded-2xl shadow p-5">
        <h3 class="font-semibold text-gray-700 mb-3 text-sm">Tracking Status Transition Graph</h3>
        <canvas id="transitionChart" height="110"></canvas>
      </div>
      <div class="bg-white rounded-2xl shadow p-5">
        <h3 class="font-semibold text-gray-700 mb-3 text-sm">Top Listing Countries</h3>
        <div id="listingCountrySummary" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3"></div>
      </div>
    </section>

    <!-- ── Users section ──────────────────────────────────────────────── -->
    <section id="sec-users" class="p-6 space-y-4 hidden">
      <div class="flex flex-wrap gap-3">
        <input id="userSearch" type="text" placeholder="Search name or email…"
          class="border border-gray-300 rounded-lg px-3 py-2 text-sm w-64 focus:outline-none focus:ring-2 focus:ring-green-500"/>
        <select id="userRoleFilter"
          class="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
          <option value="">All Roles</option>
          <option value="admin">Admin</option>
          <option value="agent">Agent</option>
          <option value="company">Company</option>
          <option value="organization">Organization</option>
          <option value="user">User</option>
        </select>
        <button onclick="loadUsers()"
          class="bg-green-700 text-white px-4 py-2 rounded-lg text-sm hover:bg-green-800 transition-colors">Search</button>
      </div>
      <div class="bg-white rounded-2xl shadow overflow-hidden">
        <table class="min-w-full text-sm">
          <thead class="bg-gray-50 border-b">
            <tr>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">ID</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Name</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Email</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Role</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Joined</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Actions</th>
            </tr>
          </thead>
          <tbody id="usersTable" class="divide-y"></tbody>
        </table>
        <div id="usersPager" class="px-4 py-3 flex gap-2 items-center text-xs text-gray-500 border-t"></div>
      </div>
    </section>

    <!-- ── Content section ────────────────────────────────────────────── -->
    <section id="sec-content" class="p-6 space-y-4 hidden">
      <div class="flex gap-2 mb-4">
        <button onclick="loadContent('agriculture')"
          class="px-4 py-2 bg-green-700 text-white rounded-lg text-sm hover:bg-green-800 transition-colors">Agriculture</button>
        <button onclick="loadContent('manufacturing')"
          class="px-4 py-2 bg-blue-700 text-white rounded-lg text-sm hover:bg-blue-800 transition-colors">Manufacturing</button>
        <button onclick="loadContent('services')"
          class="px-4 py-2 bg-purple-700 text-white rounded-lg text-sm hover:bg-purple-800 transition-colors">Services</button>
        <button onclick="loadContent('agriculture')"
          class="px-4 py-2 bg-green-100 text-green-800 rounded-lg text-sm hover:bg-green-200 transition-colors">Agriculture</button>
        <button onclick="loadContent('manufacturing')"
          class="px-4 py-2 bg-green-100 text-green-800 rounded-lg text-sm hover:bg-green-200 transition-colors">Manufacturing</button>
      </div>
      <div class="bg-white rounded-2xl shadow overflow-hidden">
        <table class="min-w-full text-sm">
          <thead class="bg-gray-50 border-b">
            <tr>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">ID</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Title</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Status</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Created</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Actions</th>
            </tr>
          </thead>
          <tbody id="contentTable" class="divide-y"></tbody>
        </table>
        <div id="contentPager" class="px-4 py-3 flex gap-2 items-center text-xs text-gray-500 border-t"></div>
      </div>
    </section>

    <!-- ── Reports section ────────────────────────────────────────────── -->
    <section id="sec-reports" class="p-6 space-y-4 hidden">
      <div class="flex items-center gap-3 mb-2">
        <label class="text-sm font-medium text-gray-700">Period:</label>
        <select id="reportDays"
          class="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
          <option value="7">Last 7 days</option>
          <option value="30" selected>Last 30 days</option>
          <option value="90">Last 90 days</option>
          <option value="365">Last year</option>
        </select>
        <button onclick="loadReports()"
          class="bg-green-700 text-white px-4 py-2 rounded-lg text-sm hover:bg-green-800 transition-colors">Load</button>
      </div>
      <div id="reportsOverview" class="grid grid-cols-2 md:grid-cols-3 gap-4"></div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="bg-white rounded-2xl shadow p-5">
          <h3 class="font-semibold text-gray-700 mb-3 text-sm">Registrations by Role</h3>
          <canvas id="regChart" height="200"></canvas>
        </div>
        <div class="bg-white rounded-2xl shadow p-5">
          <h3 class="font-semibold text-gray-700 mb-3 text-sm">Orders by Status</h3>
          <canvas id="ordStatusChart" height="200"></canvas>
        </div>
      </div>
    </section>

    <!-- ── Tickets section ────────────────────────────────────────────── -->
    <section id="sec-tickets" class="p-6 space-y-4 hidden">
      <div class="flex gap-2">
        <select id="ticketStatusFilter"
          class="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500">
          <option value="">All Statuses</option>
          <option value="open">Open</option>
          <option value="in_progress">In Progress</option>
          <option value="closed">Closed</option>
        </select>
        <button onclick="loadTickets()"
          class="bg-green-700 text-white px-4 py-2 rounded-lg text-sm hover:bg-green-800 transition-colors">Filter</button>
      </div>
      <div class="bg-white rounded-2xl shadow overflow-hidden">
        <table class="min-w-full text-sm">
          <thead class="bg-gray-50 border-b">
            <tr>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">ID</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Subject</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Status</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Created</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Actions</th>
            </tr>
          </thead>
          <tbody id="ticketsTable" class="divide-y"></tbody>
        </table>
        <div id="ticketsPager" class="px-4 py-3 flex gap-2 items-center text-xs text-gray-500 border-t"></div>
      </div>
    </section>

    <!-- ── Audit Logs section ─────────────────────────────────────────── -->
    <section id="sec-logs" class="p-6 space-y-4 hidden">
      <div class="bg-white rounded-2xl shadow overflow-hidden">
        <table class="min-w-full text-sm">
          <thead class="bg-gray-50 border-b">
            <tr>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Time</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Admin</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Action</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Target</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Detail</th>
            </tr>
          </thead>
          <tbody id="logsTable" class="divide-y divide-gray-100"></tbody>
        </table>
        <div id="logsPager" class="px-4 py-3 flex gap-2 items-center text-xs text-gray-500 border-t"></div>
      </div>
    </section>

    <!-- ── Broadcast section ──────────────────────────────────────────── -->
    <section id="sec-broadcast" class="p-6 hidden">
      <div class="max-w-lg bg-white rounded-2xl shadow p-6 space-y-4">
        <h3 class="font-semibold text-gray-800">Send Broadcast Notification</h3>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
          <input id="bcTitle" type="text"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
            placeholder="Notification title"/>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Body</label>
          <textarea id="bcBody" rows="3"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
            placeholder="Notification body…"></textarea>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Target Role <span class="text-gray-400">(leave blank for all users)</span></label>
          <select id="bcRole"
            class="border border-gray-300 rounded-lg px-3 py-2 text-sm w-full focus:outline-none focus:ring-2 focus:ring-green-500">
            <option value="">All Users</option>
            <option value="admin">Admin</option>
            <option value="agent">Agent</option>
            <option value="company">Company</option>
            <option value="organization">Organization</option>
            <option value="user">User</option>
          </select>
        </div>
        <button onclick="sendBroadcast()"
          class="bg-green-700 text-white px-5 py-2.5 rounded-lg text-sm font-medium hover:bg-green-800 transition-colors">
          Send Notification
        </button>
      </div>
    </section>

    <!-- ── Deleted Items section ──────────────────────────────────────── -->
    <section id="sec-deleted" class="p-6 space-y-4 hidden">
      <div class="flex gap-2 mb-4">
        <button onclick="loadDeleted('all')"
          class="px-4 py-2 bg-red-700 text-white rounded-lg text-sm hover:bg-red-800 transition-colors">All</button>
        <button onclick="loadDeleted('agriculture')"
          class="px-4 py-2 bg-red-100 text-red-800 rounded-lg text-sm hover:bg-red-200 transition-colors">Agriculture</button>
        <button onclick="loadDeleted('manufacturing')"
          class="px-4 py-2 bg-red-100 text-red-800 rounded-lg text-sm hover:bg-red-200 transition-colors">Manufacturing</button>
        <button onclick="loadDeleted('services')"
          class="px-4 py-2 bg-red-100 text-red-800 rounded-lg text-sm hover:bg-red-200 transition-colors">Services</button>
        <button onclick="loadDeleted('agriculture')"
          class="px-4 py-2 bg-red-100 text-red-800 rounded-lg text-sm hover:bg-red-200 transition-colors">Agriculture</button>
        <button onclick="loadDeleted('manufacturing')"
          class="px-4 py-2 bg-red-100 text-red-800 rounded-lg text-sm hover:bg-red-200 transition-colors">Manufacturing</button>
      </div>
      <p class="text-xs text-gray-500">Items shown here have been soft-deleted. You can restore them or permanently remove them from the database.</p>
      <div class="bg-white rounded-2xl shadow overflow-hidden">
        <table class="min-w-full text-sm">
          <thead class="bg-gray-50 border-b">
            <tr>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">ID</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Type</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Title</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Status</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Created On</th>
              <th class="px-4 py-3 text-left font-semibold text-gray-600">Actions</th>
            </tr>
          </thead>
          <tbody id="deletedTable" class="divide-y"></tbody>
        </table>
        <div id="deletedEmpty" class="hidden px-4 py-8 text-center text-gray-400 text-sm">No deleted items found.</div>
      </div>
    </section>

  </main>
</div>

<!-- ═══ User Edit Modal ═══════════════════════════════════════════════════════ -->
<div id="userModal" class="hidden fixed inset-0 bg-black/40 z-50 flex items-center justify-center">
  <div class="bg-white rounded-2xl shadow-xl p-6 w-full max-w-md">
    <h3 class="font-semibold text-gray-800 mb-4">Edit User</h3>
    <input type="hidden" id="editUserId"/>
    <div class="space-y-3">
      <div>
        <label class="text-sm font-medium text-gray-700">First Name</label>
        <input id="editFirstName" class="w-full border rounded-lg px-3 py-2 text-sm mt-1 focus:outline-none focus:ring-2 focus:ring-green-500"/>
      </div>
      <div>
        <label class="text-sm font-medium text-gray-700">Last Name</label>
        <input id="editLastName" class="w-full border rounded-lg px-3 py-2 text-sm mt-1 focus:outline-none focus:ring-2 focus:ring-green-500"/>
      </div>
      <div>
        <label class="text-sm font-medium text-gray-700">Role</label>
        <select id="editRole" class="w-full border rounded-lg px-3 py-2 text-sm mt-1 focus:outline-none focus:ring-2 focus:ring-green-500">
          <option value="admin">Admin</option>
          <option value="agent">Agent</option>
          <option value="company">Company</option>
          <option value="organization">Organization</option>
          <option value="user">User</option>
        </select>
      </div>
      <div>
        <label class="text-sm font-medium text-gray-700">Phone</label>
        <input id="editPhone" class="w-full border rounded-lg px-3 py-2 text-sm mt-1 focus:outline-none focus:ring-2 focus:ring-green-500"/>
      </div>
    </div>
    <div class="flex gap-3 mt-5">
      <button onclick="saveUser()"
        class="flex-1 bg-green-700 text-white py-2 rounded-lg text-sm font-medium hover:bg-green-800 transition-colors">Save</button>
      <button onclick="closeUserModal()"
        class="flex-1 border border-gray-300 py-2 rounded-lg text-sm font-medium hover:bg-gray-50 transition-colors">Cancel</button>
    </div>
  </div>
</div>

<!-- ═══ Ticket Modal ══════════════════════════════════════════════════════════ -->
<div id="ticketModal" class="hidden fixed inset-0 bg-black/40 z-50 flex items-center justify-center">
  <div class="bg-white rounded-2xl shadow-xl p-6 w-full max-w-lg">
    <h3 class="font-semibold text-gray-800 mb-1">Ticket Details</h3>
    <p id="ticketSubject" class="text-gray-500 text-sm mb-4"></p>
    <p id="ticketBody" class="text-gray-700 text-sm bg-gray-50 rounded-lg p-3 mb-4 max-h-40 overflow-y-auto"></p>
    <input type="hidden" id="editTicketId"/>
    <div class="space-y-3">
      <div>
        <label class="text-sm font-medium text-gray-700">Status</label>
        <select id="editTicketStatus" class="w-full border rounded-lg px-3 py-2 text-sm mt-1 focus:outline-none focus:ring-2 focus:ring-green-500">
          <option value="open">Open</option>
          <option value="in_progress">In Progress</option>
          <option value="closed">Closed</option>
        </select>
      </div>
      <div>
        <label class="text-sm font-medium text-gray-700">Resolution</label>
        <textarea id="editTicketResolution" rows="2"
          class="w-full border rounded-lg px-3 py-2 text-sm mt-1 focus:outline-none focus:ring-2 focus:ring-green-500"
          placeholder="Resolution notes…"></textarea>
      </div>
    </div>
    <div class="flex gap-3 mt-5">
      <button onclick="saveTicket()"
        class="flex-1 bg-green-700 text-white py-2 rounded-lg text-sm font-medium hover:bg-green-800 transition-colors">Update</button>
      <button onclick="closeTicketModal()"
        class="flex-1 border border-gray-300 py-2 rounded-lg text-sm font-medium hover:bg-gray-50 transition-colors">Cancel</button>
    </div>
  </div>
</div>

<script>
const API = '""" + _API_BASE + r"""';
const DASHBOARD_DAYS = 30;
const DASHBOARD_TOP_N_ITEMS = 8;
let token = localStorage.getItem('ort_admin_token');
let currentSection = 'dashboard';
let _usersOffset = 0, _contentOffset = 0, _ticketsOffset = 0, _logsOffset = 0;
let _contentType = 'agriculture';
let _roleChart = null, _orderChart = null, _activityChart = null;
let _regChart = null, _ordStatusChart = null;
let _countryChart = null, _locationChart = null, _transitionChart = null;
let _refreshInterval = null;

// ── Bootstrap ──────────────────────────────────────────────────────────────
window.onload = () => {
  if (token) {
    showApp();
  }
};

// ── Setup / Login form toggle ──────────────────────────────────────────────
function showLoginForm() {
  document.getElementById('loginForm').classList.remove('hidden');
  document.getElementById('setupForm').classList.add('hidden');
  document.getElementById('loginSubtitle').textContent = 'Sign in with admin credentials';
}

function showSetupForm() {
  document.getElementById('loginForm').classList.add('hidden');
  document.getElementById('setupForm').classList.remove('hidden');
  document.getElementById('loginSubtitle').textContent = 'First-time setup';
}

// ── Login ──────────────────────────────────────────────────────────────────
document.getElementById('loginForm').onsubmit = async (e) => {
  e.preventDefault();
  const username = document.getElementById('loginUsername').value.trim();
  const pass  = document.getElementById('loginPassword').value;
  const errEl = document.getElementById('loginError');
  errEl.classList.add('hidden');
  try {
    const r = await fetch(API + '/auth/admin-login', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({username, password: pass})
    });
    const data = await r.json();
    if (!r.ok) {
      if (r.status === 503) {
        showSetupForm();
        return;
      }
      const msg = data.detail || 'Login failed';
      errEl.textContent = msg; errEl.classList.remove('hidden'); return;
    }
    if (data.role !== 'admin') { errEl.textContent = 'Access denied — admin accounts only.'; errEl.classList.remove('hidden'); return; }
    token = data.access_token;
    localStorage.setItem('ort_admin_token', token);
    const adminEmailEl = document.getElementById('adminEmail');
    if (adminEmailEl) adminEmailEl.textContent = username;
    showApp();
  } catch(err) {
    errEl.textContent = 'Network issue. Please try again.';
    errEl.classList.remove('hidden');
  }
};

// ── One-time admin setup ───────────────────────────────────────────────────
document.getElementById('setupForm').onsubmit = async (e) => {
  e.preventDefault();
  const username = document.getElementById('setupUsername').value.trim();
  const pass    = document.getElementById('setupPassword').value;
  const confirm = document.getElementById('setupPasswordConfirm').value;
  const errEl   = document.getElementById('setupError');
  errEl.classList.add('hidden');
  if (pass !== confirm) {
    errEl.textContent = 'Passwords do not match.'; errEl.classList.remove('hidden'); return;
  }
  if (pass.length < 8) {
    errEl.textContent = 'Password must be at least 8 characters.'; errEl.classList.remove('hidden'); return;
  }
  try {
    const r = await fetch(API + '/auth/admin-setup', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({username, password: pass})
    });
    const data = await r.json();
    if (!r.ok) {
      if (r.status === 409) {
        errEl.textContent = data.detail || 'Admin already configured. Please log in.';
        errEl.classList.remove('hidden');
        setTimeout(() => showLoginForm(), 2500);
        return;
      }
      errEl.textContent = data.detail || 'Setup failed.';
      errEl.classList.remove('hidden'); return;
    }
    token = data.access_token;
    localStorage.setItem('ort_admin_token', token);
    const adminEmailEl = document.getElementById('adminEmail');
    if (adminEmailEl) adminEmailEl.textContent = username;
    showApp();
  } catch(err) {
    errEl.textContent = 'Network issue. Please try again.';
    errEl.classList.remove('hidden');
  }
};

function showApp() {
  document.getElementById('loginOverlay').classList.add('hidden');
  document.getElementById('app').classList.remove('hidden');
  showSection('dashboard');
  startAutoRefresh();
}

function logout() {
  localStorage.removeItem('ort_admin_token');
  token = null;
  clearInterval(_refreshInterval);
  document.getElementById('loginOverlay').classList.remove('hidden');
  document.getElementById('app').classList.add('hidden');
  showLoginForm();
}

// ── Auto-refresh ───────────────────────────────────────────────────────────
function startAutoRefresh() {
  clearInterval(_refreshInterval);
  _refreshInterval = setInterval(() => { if (currentSection === 'dashboard') loadDashboard(); }, 30000);
}

function refreshCurrent() {
  if (currentSection === 'dashboard') loadDashboard();
  else if (currentSection === 'users') loadUsers();
  else if (currentSection === 'content') loadContent(_contentType);
  else if (currentSection === 'reports') loadReports();
  else if (currentSection === 'tickets') loadTickets();
  else if (currentSection === 'logs') loadLogs();
}

// ── Section navigation ─────────────────────────────────────────────────────
function showSection(name) {
  currentSection = name;
  document.querySelectorAll('section[id^="sec-"]').forEach(s => s.classList.add('hidden'));
  document.getElementById('sec-' + name).classList.remove('hidden');
  const titles = {
    dashboard:'Dashboard', users:'User Management', content:'Content Moderation',
    reports:'Reports & Analytics', tickets:'Support Tickets', logs:'Audit Logs',
    broadcast:'Broadcast Notification', deleted:'Deleted Items'
  };
  document.getElementById('pageTitle').textContent = titles[name] || name;
  if (name === 'dashboard') loadDashboard();
  else if (name === 'users') { _usersOffset = 0; loadUsers(); }
  else if (name === 'content') { _contentOffset = 0; loadContent('agriculture'); }
  else if (name === 'reports') loadReports();
  else if (name === 'tickets') { _ticketsOffset = 0; loadTickets(); }
  else if (name === 'logs') { _logsOffset = 0; loadLogs(); }
  else if (name === 'deleted') loadDeleted('all');
}

// ── Fetch helper ───────────────────────────────────────────────────────────
async function apiFetch(path, opts={}) {
  const res = await fetch(API + path, {
    ...opts,
    headers: { 'Authorization': 'Bearer ' + token, 'Content-Type':'application/json', ...(opts.headers||{}) }
  });
  if (res.status === 401) { logout(); throw new Error('Session expired'); }
  if (!res.ok) {
    let errMsg = res.statusText;
    try {
      const d = await res.json();
      if (d && d.detail) errMsg = typeof d.detail === 'string' ? d.detail : JSON.stringify(d.detail);
    } catch (parseErr) {
      errMsg = `HTTP ${res.status}: ${res.statusText}`;
    }
    throw new Error(errMsg);
  }
  return res.json();
}

// ── Dashboard ──────────────────────────────────────────────────────────────
async function loadDashboard() {
  try {
    const [stats, report, locationAnalyticsData] = await Promise.all([
      apiFetch('/admin/dashboard/stats'),
      apiFetch(`/admin/reports/overview?days=${DASHBOARD_DAYS}`),
      apiFetch(`/admin/dashboard/location-analytics?days=${DASHBOARD_DAYS}&top_n=${DASHBOARD_TOP_N_ITEMS}`)
    ]);
    renderStats(stats);
    renderRoleChart(stats.users_by_role || {});
    renderOrderChart(report.orders_by_status || {});
    renderActivityChart(report);
    renderCountryChart(locationAnalyticsData.top_tracking_countries || []);
    renderLocationChart(locationAnalyticsData.top_tracking_locations || []);
    renderTransitionChart(locationAnalyticsData.tracking_status_transitions || []);
    renderListingCountrySummary(locationAnalyticsData.top_listing_countries || []);
    document.getElementById('lastRefresh').textContent = 'Refreshed ' + new Date().toLocaleTimeString();
  } catch(e) { showToast('Failed to load dashboard. Please try again.', 'red'); }
}

function renderStats(s) {
  const cards = [
    {icon:'👥', label:'Total Users',       value: s.total_users??0,            color:'bg-green-50 text-green-700'},
    {icon:'🆕', label:'New Users (30d)',   value: s.new_users_last_30_days??0, color:'bg-blue-50 text-blue-700'},
    {icon:'🌾', label:'Agriculture',      value: s.total_agriculture_listings??0, color:'bg-green-50 text-green-700'},
    {icon:'🏭', label:'Manufacturing',    value: s.total_manufacturing_products??0,color:'bg-blue-50 text-blue-700'},
    {icon:'🛠️', label:'Services',          value: s.total_services??0,             color:'bg-purple-50 text-purple-700'},
    {icon:'🏢', label:'Tenants',           value: s.total_tenants??0,          color:'bg-purple-50 text-purple-700'},
    {icon:'📦', label:'Total Orders',      value: s.total_orders??0,           color:'bg-orange-50 text-orange-700'},
    {icon:'⏳', label:'Pending Orders',   value: s.pending_orders??0,         color:'bg-yellow-50 text-yellow-700'},
    {icon:'💬', label:'Messages',          value: s.total_messages??0,         color:'bg-pink-50 text-pink-700'},
    {icon:'🎫', label:'Open Tickets',      value: s.open_support_tickets??0,   color:'bg-red-50 text-red-700'},
  ];
  document.getElementById('statsGrid').innerHTML = cards.map(c=>`
    <div class="bg-white rounded-2xl shadow p-5 flex items-center gap-4">
      <div class="text-3xl">${c.icon}</div>
      <div>
        <div class="text-2xl font-bold ${c.color.split(' ')[1]}">${c.value.toLocaleString()}</div>
        <div class="text-xs text-gray-500 mt-0.5">${c.label}</div>
      </div>
    </div>`).join('');
}

function renderRoleChart(data) {
  const ctx = document.getElementById('roleChart').getContext('2d');
  if (_roleChart) _roleChart.destroy();
  _roleChart = new Chart(ctx, {
    type:'doughnut',
    data:{ labels:Object.keys(data), datasets:[{data:Object.values(data), backgroundColor:['#166534','#15803d','#16a34a','#22c55e','#86efac','#bbf7d0']}] },
    options:{ plugins:{legend:{position:'right'}}, responsive:true }
  });
}

function renderOrderChart(data) {
  const ctx = document.getElementById('orderChart').getContext('2d');
  if (_orderChart) _orderChart.destroy();
  _orderChart = new Chart(ctx, {
    type:'bar',
    data:{ labels:Object.keys(data), datasets:[{label:'Orders', data:Object.values(data), backgroundColor:'#16a34a'}] },
    options:{ plugins:{legend:{display:false}}, responsive:true, scales:{y:{beginAtZero:true}} }
  });
}

function renderActivityChart(r) {
  const ctx = document.getElementById('activityChart').getContext('2d');
  if (_activityChart) _activityChart.destroy();
  const labels = ['New Users','Agriculture','Manufacturing','Services','New Orders','New Messages'];
  const values = [r.new_users??0, r.new_agriculture_listings??0, r.new_manufacturing_products??0, r.new_services??0, r.new_orders??0, r.new_messages??0];
  _activityChart = new Chart(ctx, {
    type:'bar',
    data:{ labels, datasets:[{label:'Last 30 days', data:values, backgroundColor:['#166534','#15803d','#16a34a','#22c55e','#4ade80','#86efac']}] },
    options:{ plugins:{legend:{display:false}}, responsive:true, scales:{y:{beginAtZero:true}} }
  });
}

function renderCountryChart(items) {
  const ctx = document.getElementById('countryChart').getContext('2d');
  if (_countryChart) _countryChart.destroy();
  const labels = items.map(i => i.country);
  const values = items.map(i => i.count);
  _countryChart = new Chart(ctx, {
    type:'bar',
    data:{ labels, datasets:[{label:'Tracking events', data:values, backgroundColor:'#2563eb'}] },
    options:{ plugins:{legend:{display:false}}, responsive:true, scales:{y:{beginAtZero:true}} }
  });
}

function renderLocationChart(items) {
  const ctx = document.getElementById('locationChart').getContext('2d');
  if (_locationChart) _locationChart.destroy();
  const labels = items.map(i => i.location);
  const values = items.map(i => i.count);
  _locationChart = new Chart(ctx, {
    type:'bar',
    data:{ labels, datasets:[{label:'Updates', data:values, backgroundColor:'#0ea5e9'}] },
    options:{
      indexAxis:'y',
      plugins:{legend:{display:false}},
      responsive:true,
      scales:{x:{beginAtZero:true}}
    }
  });
}

function renderTransitionChart(items) {
  const ctx = document.getElementById('transitionChart').getContext('2d');
  if (_transitionChart) _transitionChart.destroy();
  const labels = items.map(i => `${i.from_status} → ${i.to_status}`);
  const values = items.map(i => i.count);
  _transitionChart = new Chart(ctx, {
    type:'line',
    data:{ labels, datasets:[{label:'Transition frequency', data:values, borderColor:'#7c3aed', backgroundColor:'#c4b5fd', tension:0.25, fill:false}] },
    options:{ plugins:{legend:{display:false}}, responsive:true, scales:{y:{beginAtZero:true}} }
  });
}

function renderListingCountrySummary(items) {
  const container = document.getElementById('listingCountrySummary');
  if (!items.length) {
    container.innerHTML = '<div class="text-xs text-gray-500">No listing country data for the selected period.</div>';
    return;
  }
  container.innerHTML = items.map((item) => `
    <div class="rounded-xl border border-gray-200 px-3 py-3 bg-gray-50">
      <div class="text-xs text-gray-500 truncate">${esc(item.country)}</div>
      <div class="text-lg font-semibold text-green-700">${Number(item.count || 0).toLocaleString()}</div>
    </div>
  `).join('');
}

// ── Users ──────────────────────────────────────────────────────────────────
async function loadUsers(offset) {
  if (offset !== undefined) _usersOffset = offset;
  const search = document.getElementById('userSearch').value.trim();
  const role   = document.getElementById('userRoleFilter').value;
  const params = new URLSearchParams({skip:_usersOffset, limit:50});
  if (search) params.set('search', search);
  if (role)   params.set('role', role);
  // Register pager callback
  _pagerCbs['users'] = (o) => loadUsers(o);
  try {
    const data = await apiFetch('/admin/users/?' + params);
    const tbody = document.getElementById('usersTable');
    // Store user data in a map for the edit modal to avoid inline data in onclick
    window._usersData = {};
    (data.users||[]).forEach(u => { window._usersData[u.id] = u; });
    tbody.innerHTML = (data.users||[]).map(u=>`
      <tr class="hover:bg-gray-50 transition-colors">
        <td class="px-4 py-3 text-gray-500">${u.id}</td>
        <td class="px-4 py-3 font-medium">${esc(u.first_name||'')} ${esc(u.last_name||'')}</td>
        <td class="px-4 py-3 text-gray-600">${esc(u.email||'')}</td>
        <td class="px-4 py-3"><span class="badge ${roleBadge(u.role)}">${esc(u.role||'')}</span></td>
        <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(u.created_at)}</td>
        <td class="px-4 py-3">
          <button data-uid="${u.id}" class="edit-user-btn text-blue-600 hover:text-blue-800 text-xs font-medium mr-2">Edit</button>
          <button data-uid="${u.id}" class="del-user-btn text-red-600 hover:text-red-800 text-xs font-medium">Delete</button>
        </td>
      </tr>`).join('');
    // Attach edit/delete handlers via event delegation
    tbody.querySelectorAll('.edit-user-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const u = window._usersData[parseInt(btn.dataset.uid)];
        if (u) openUserModal(u.id, u.first_name||'', u.last_name||'', u.role||'', u.phone||'');
      });
    });
    tbody.querySelectorAll('.del-user-btn').forEach(btn => {
      btn.addEventListener('click', () => deleteUser(parseInt(btn.dataset.uid)));
    });
    renderPager('usersPager', data.total||0, _usersOffset, 50, 'users');
  } catch(e) { showToast('Failed to load users. Please try again.','red'); }
}

function roleBadge(role) {
  const m = {admin:'bg-red-100 text-red-700', agent:'bg-blue-100 text-blue-700', company:'bg-orange-100 text-orange-700', organization:'bg-green-100 text-green-700', user:'bg-gray-100 text-gray-700'};
  return m[role]||'bg-gray-100 text-gray-700';
}

function openUserModal(id,fn,ln,role,phone) {
  document.getElementById('editUserId').value=id;
  document.getElementById('editFirstName').value=fn;
  document.getElementById('editLastName').value=ln;
  document.getElementById('editRole').value=role;
  document.getElementById('editPhone').value=phone;
  document.getElementById('userModal').classList.remove('hidden');
}
function closeUserModal() { document.getElementById('userModal').classList.add('hidden'); }

async function saveUser() {
  const id = document.getElementById('editUserId').value;
  const payload = {
    first_name: document.getElementById('editFirstName').value,
    last_name:  document.getElementById('editLastName').value,
    role:       document.getElementById('editRole').value,
    phone:      document.getElementById('editPhone').value,
  };
  try {
    await apiFetch('/admin/users/'+id, {method:'PATCH', body:JSON.stringify(payload)});
    closeUserModal(); showToast('User updated','green'); loadUsers();
  } catch(e) { showToast('Operation failed. Please try again.','red'); }
}

async function deleteUser(id) {
  if (!confirm('Delete user #'+id+'?')) return;
  try {
    await apiFetch('/admin/users/'+id, {method:'DELETE'});
    showToast('User deleted','green'); loadUsers();
  } catch(e) { showToast('Operation failed. Please try again.','red'); }
}

// ── Content ────────────────────────────────────────────────────────────────
async function loadContent(type, offset) {
  _contentType = type;
  if (offset !== undefined) _contentOffset = offset;
  const params = new URLSearchParams({skip:_contentOffset, limit:50});
  _pagerCbs['content'] = (o) => loadContent(type, o);
  try {
    const data = await apiFetch('/admin/content/' + type + '/?' + params);
    const items = data.properties || data.listings || data.products || data.services || data.items || [];
    const total = data.total||0;
    window._contentData = {};
    items.forEach(i => { window._contentData[i.id] = {type, id:i.id}; });
    document.getElementById('contentTable').innerHTML = items.map(i=>`
      <tr class="hover:bg-gray-50 transition-colors">
        <td class="px-4 py-3 text-gray-500">${i.id}</td>
        <td class="px-4 py-3 font-medium">${esc(i.title||'')}</td>
        <td class="px-4 py-3"><span class="badge ${statusBadge(i.status)}">${esc(i.status||'')}</span></td>
        <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(i.created_at)}</td>
        <td class="px-4 py-3">
          <button data-cid="${i.id}" class="del-content-btn text-red-600 hover:text-red-800 text-xs font-medium">Delete</button>
        </td>
      </tr>`).join('');
    document.getElementById('contentTable').querySelectorAll('.del-content-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const d = window._contentData[parseInt(btn.dataset.cid)];
        if (d) deleteContent(d.type, d.id);
      });
    });
    renderPager('contentPager', total, _contentOffset, 50, 'content');
  } catch(e) { showToast('Failed to load content. Please try again.','red'); }
}

function statusBadge(s) {
  const m = {active:'bg-green-100 text-green-700', pending:'bg-yellow-100 text-yellow-700', sold:'bg-blue-100 text-blue-700', inactive:'bg-gray-100 text-gray-700'};
  return m[s]||'bg-gray-100 text-gray-700';
}

async function deleteContent(type, id) {
  if (!confirm('Delete this '+type+' item?')) return;
  try {
    await apiFetch('/admin/content/'+type+'/'+id, {method:'DELETE'});
    showToast('Deleted','green'); loadContent(type);
  } catch(e) { showToast('Operation failed. Please try again.','red'); }
}

// ── Reports ────────────────────────────────────────────────────────────────
async function loadReports() {
  const days = document.getElementById('reportDays').value;
  try {
    const [overview, users] = await Promise.all([
      apiFetch('/admin/reports/overview?days='+days),
      apiFetch('/admin/reports/users?days='+days)
    ]);
    const cards = [
      {label:'New Users',        value:overview.new_users??0},
      {label:'New Agriculture',   value:overview.new_agriculture_listings??0},
      {label:'New Manufacturing',  value:overview.new_manufacturing_products??0},
      {label:'New Services',       value:overview.new_services??0},
      {label:'New Orders',       value:overview.new_orders??0},
      {label:'New Messages',     value:overview.new_messages??0},
      {label:'New Agri Listings',value:overview.new_agriculture_listings??0},
      {label:'New Products',     value:overview.new_manufacturing_products??0},
    ];
    document.getElementById('reportsOverview').innerHTML = cards.map(c=>`
      <div class="bg-white rounded-2xl shadow p-4">
        <div class="text-2xl font-bold text-green-700">${c.value.toLocaleString()}</div>
        <div class="text-xs text-gray-500 mt-1">${c.label}</div>
      </div>`).join('');

    // Registrations by Role chart
    const rc = document.getElementById('regChart').getContext('2d');
    if (_regChart) _regChart.destroy();
    _regChart = new Chart(rc, {
      type:'doughnut',
      data:{ labels:Object.keys(users.registrations_by_role||{}), datasets:[{data:Object.values(users.registrations_by_role||{}), backgroundColor:['#166534','#15803d','#16a34a','#22c55e','#86efac']}] },
      options:{ plugins:{legend:{position:'right'}}, responsive:true }
    });

    // Orders by Status chart
    const oc = document.getElementById('ordStatusChart').getContext('2d');
    if (_ordStatusChart) _ordStatusChart.destroy();
    _ordStatusChart = new Chart(oc, {
      type:'bar',
      data:{ labels:Object.keys(overview.orders_by_status||{}), datasets:[{label:'Orders', data:Object.values(overview.orders_by_status||{}), backgroundColor:'#22c55e'}] },
      options:{ plugins:{legend:{display:false}}, responsive:true, scales:{y:{beginAtZero:true}} }
    });
  } catch(e) { showToast('Failed to load reports. Please try again.','red'); }
}

// ── Tickets ────────────────────────────────────────────────────────────────
async function loadTickets(offset) {
  if (offset !== undefined) _ticketsOffset = offset;
  const status = document.getElementById('ticketStatusFilter').value;
  const params = new URLSearchParams({skip:_ticketsOffset, limit:50});
  if (status) params.set('status', status);
  _pagerCbs['tickets'] = (o) => loadTickets(o);
  try {
    const data = await apiFetch('/admin/tickets/?' + params);
    const tbody = document.getElementById('ticketsTable');
    tbody.innerHTML = (data.tickets||[]).map(t=>`
      <tr class="hover:bg-gray-50 transition-colors">
        <td class="px-4 py-3 text-gray-500">${t.id}</td>
        <td class="px-4 py-3 font-medium">${esc(t.subject||'')}</td>
        <td class="px-4 py-3"><span class="badge ${ticketBadge(t.status)}">${esc(t.status||'')}</span></td>
        <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(t.created_at)}</td>
        <td class="px-4 py-3">
          <button data-tid="${t.id}" class="view-ticket-btn text-blue-600 hover:text-blue-800 text-xs font-medium">View</button>
        </td>
      </tr>`).join('');
    tbody.querySelectorAll('.view-ticket-btn').forEach(btn => {
      btn.addEventListener('click', () => openTicketModal(parseInt(btn.dataset.tid)));
    });
    renderPager('ticketsPager', data.total||0, _ticketsOffset, 50, 'tickets');
  } catch(e) { showToast('Failed to load tickets. Please try again.','red'); }
}

function ticketBadge(s) {
  return s==='open'?'bg-red-100 text-red-700':s==='in_progress'?'bg-yellow-100 text-yellow-700':'bg-gray-100 text-gray-700';
}

async function openTicketModal(id) {
  try {
    const t = await apiFetch('/admin/tickets/'+id);
    document.getElementById('editTicketId').value=t.id;
    document.getElementById('ticketSubject').textContent='#'+t.id+' — '+t.subject;
    document.getElementById('ticketBody').textContent=t.body||'(no body)';
    document.getElementById('editTicketStatus').value=t.status||'open';
    document.getElementById('editTicketResolution').value=t.resolution||'';
    document.getElementById('ticketModal').classList.remove('hidden');
  } catch(e) { showToast('Operation failed. Please try again.','red'); }
}
function closeTicketModal() { document.getElementById('ticketModal').classList.add('hidden'); }

async function saveTicket() {
  const id = document.getElementById('editTicketId').value;
  const payload = {
    status:     document.getElementById('editTicketStatus').value,
    resolution: document.getElementById('editTicketResolution').value || null,
  };
  try {
    await apiFetch('/admin/tickets/'+id, {method:'PATCH', body:JSON.stringify(payload)});
    closeTicketModal(); showToast('Ticket updated','green'); loadTickets();
  } catch(e) { showToast('Operation failed. Please try again.','red'); }
}

// ── Audit Logs ─────────────────────────────────────────────────────────────
async function loadLogs(offset) {
  if (offset !== undefined) _logsOffset = offset;
  _pagerCbs['logs'] = (o) => loadLogs(o);
  try {
    const data = await apiFetch('/admin/logs/?skip='+_logsOffset+'&limit=50');
    document.getElementById('logsTable').innerHTML = (data.logs||[]).map(l=>`
      <tr class="hover:bg-gray-50 transition-colors">
        <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(l.created_at)}</td>
        <td class="px-4 py-3 text-gray-600">${l.admin_id}</td>
        <td class="px-4 py-3 font-medium">${esc(l.action||'')}</td>
        <td class="px-4 py-3 text-gray-600">${esc(l.target_type||'')} ${l.target_id?'#'+l.target_id:''}</td>
        <td class="px-4 py-3 text-gray-500 text-xs truncate max-w-[200px]">${esc(l.detail||'')}</td>
      </tr>`).join('');
    renderPager('logsPager', data.total||0, _logsOffset, 50, 'logs');
  } catch(e) { showToast('Failed to load logs. Please try again.','red'); }
}

// ── Broadcast ──────────────────────────────────────────────────────────────
// ── Deleted Items ──────────────────────────────────────────────────────────
let _deletedFilter = 'all';
async function loadDeleted(filter) {
  _deletedFilter = filter;
  const table = document.getElementById('deletedTable');
  const emptyEl = document.getElementById('deletedEmpty');
  table.innerHTML = '<tr><td colspan="6" class="px-4 py-6 text-center text-gray-400 text-sm">Loading…</td></tr>';
  emptyEl.classList.add('hidden');
  try {
    const params = filter !== 'all' ? `?content_type=${filter}` : '';
    const data = await apiFetch(`/admin/deleted/${params}`);
    const items = data.items || [];
    if (items.length === 0) {
      table.innerHTML = '';
      emptyEl.classList.remove('hidden');
      return;
    }
    table.innerHTML = items.map(item => `
      <tr class="hover:bg-gray-50">
        <td class="px-4 py-3 text-gray-500">${esc(item.id)}</td>
        <td class="px-4 py-3"><span class="badge bg-red-100 text-red-700">${esc(item.type)}</span></td>
        <td class="px-4 py-3 font-medium">${esc(item.title)}</td>
        <td class="px-4 py-3 text-gray-500">${esc(item.status)}</td>
        <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(item.created_at)}</td>
        <td class="px-4 py-3">
          <button onclick="restoreDeletedItem('${item.type}',${item.id})"
            class="text-xs text-green-700 hover:underline mr-2">Restore</button>
          <button onclick="purgeDeletedItem('${item.type}',${item.id})"
            class="text-xs text-red-600 hover:underline">Purge</button>
        </td>
      </tr>`).join('');
  } catch(e) {
    table.innerHTML = `<tr><td colspan="6" class="px-4 py-6 text-center text-red-500 text-sm">Error: Please try again.</td></tr>`;
  }
}

async function purgeDeletedItem(type, id) {
  if (!confirm(`Permanently delete this ${type} item? This cannot be undone.`)) return;
  try {
    await apiFetch(`/admin/deleted/${type}/${id}`, {method:'DELETE'});
    showToast('Item permanently deleted','green');
    loadDeleted(_deletedFilter);
  } catch(e) { showToast('Delete failed. Please try again.','red'); }
}

async function restoreDeletedItem(type, id) {
  try {
    await apiFetch(`/admin/deleted/${type}/${id}/restore`, {method:'PATCH'});
    showToast('Item restored','green');
    loadDeleted(_deletedFilter);
  } catch(e) { showToast('Restore failed. Please try again.','red'); }
}

async function sendBroadcast() {
  const title = document.getElementById('bcTitle').value.trim();
  const body  = document.getElementById('bcBody').value.trim();
  const role  = document.getElementById('bcRole').value;
  if (!title||!body) { showToast('Title and body are required','red'); return; }
  const payload = {title, body};
  if (role) payload.target_role = role;
  try {
    const res = await apiFetch('/admin/notifications/broadcast', {method:'POST', body:JSON.stringify(payload)});
    showToast(res.message||'Sent!','green');
    document.getElementById('bcTitle').value='';
    document.getElementById('bcBody').value='';
    document.getElementById('bcRole').value='';
  } catch(e) { showToast('Operation failed. Please try again.','red'); }
}

// ── Helpers ────────────────────────────────────────────────────────────────
function esc(s) {
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}

function fmtDate(s) {
  if (!s) return '—';
  try { return new Date(s).toLocaleString(); } catch { return s; }
}

function showToast(msg, color) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  // Use explicit classes (Tailwind JIT requires complete class names at parse time)
  const colorMap = {green: '#16a34a', red: '#dc2626', orange: '#ea580c', blue: '#2563eb'};
  t.style.backgroundColor = colorMap[color] || colorMap.green;
  t.className = 'fixed top-4 right-4 z-50 px-4 py-3 rounded-xl shadow-lg text-white text-sm font-medium max-w-xs';
  t.classList.remove('hidden');
  setTimeout(()=>t.classList.add('hidden'), 3500);
}

// Pagination state per table to avoid function serialization
const _pagerCbs = {};

function renderPager(elId, total, offset, limit, sectionKey) {
  const el = document.getElementById(elId);
  const page = Math.floor(offset/limit)+1;
  const pages = Math.max(1, Math.ceil(total/limit));
  const prevDis = offset === 0;
  const nextDis = offset + limit >= total;
  el.innerHTML = `
    <span>Page ${page} of ${pages} (${total.toLocaleString()} total)</span>
    <button id="${elId}-prev" class="px-3 py-1 rounded border" ${prevDis?'disabled':''}>← Prev</button>
    <button id="${elId}-next" class="px-3 py-1 rounded border" ${nextDis?'disabled':''}>Next →</button>`;
  if (!prevDis) {
    document.getElementById(elId+'-prev').onclick = () => _pagerCbs[sectionKey](Math.max(0, offset-limit));
  }
  if (!nextDis) {
    document.getElementById(elId+'-next').onclick = () => _pagerCbs[sectionKey](offset+limit);
  }
}

// ── Theme switcher ─────────────────────────────────────────────────────────
function setTheme(t) {
  const cl = document.documentElement.classList;
  cl.remove('theme-white','theme-dark','theme-ocean');
  if (t !== 'white') cl.add('theme-'+t);
  localStorage.setItem('ort_admin_theme', t);
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


@router.get("/const", response_class=HTMLResponse, include_in_schema=False)
async def admin_console():
    """Advanced backend-rendered admin dashboard at /const."""
    return HTMLResponse(content=_HTML)
