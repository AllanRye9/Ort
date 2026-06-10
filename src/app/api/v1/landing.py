"""
Public landing page served at / (root).
Provides app download links (APK / IPA / TestFlight),
"Coming Soon" store badges, and links to the three services.
"""
import os
from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["landing"])

_APK_URL  = os.getenv("APK_DOWNLOAD_URL", "#apk-coming-soon")
_IPA_URL  = os.getenv("IPA_DOWNLOAD_URL", "#ios-coming-soon")
_TF_URL   = os.getenv("TESTFLIGHT_URL",   "#testflight-coming-soon")

_SITE_URL = os.getenv("SITE_URL", "https://piitrade.com")

_HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Ort Marketplace – Agric · Manufacturing · Services | piitrade.com</title>
<meta name="description" content="Africa's commerce platform. Buy and sell Agricultural produce, Manufacturing goods, and Professional services. Based in Uganda, built for all of Africa."/>
<link rel="canonical" href="https://piitrade.com/"/>
<script src="https://cdn.tailwindcss.com"></script>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap');
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:'Inter',system-ui,sans-serif;background:#0a0f1a;color:#f0f4f8;overflow-x:hidden}

  /* hero gradient */
  .hero-bg{background:linear-gradient(135deg,#0d3320 0%,#0a0f1a 50%,#0d1f33 100%)}
  .glow{box-shadow:0 0 60px rgba(21,163,74,0.3),0 0 120px rgba(21,163,74,0.1)}
  .glow-blue{box-shadow:0 0 40px rgba(59,130,246,0.25)}

  /* gradient text */
  .grad-text{background:linear-gradient(135deg,#4ade80,#22d3ee);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}

  /* download button */
  .dl-btn{display:inline-flex;align-items:center;gap:0.75rem;padding:1rem 2rem;border-radius:1rem;font-weight:700;font-size:1rem;transition:all .25s;cursor:pointer;text-decoration:none;border:none}
  .dl-btn-primary{background:linear-gradient(135deg,#16a34a,#059669);color:#fff}
  .dl-btn-primary:hover{transform:translateY(-3px);box-shadow:0 12px 40px rgba(21,163,74,0.4)}
  .dl-btn-secondary{background:rgba(255,255,255,0.07);color:#e5e7eb;border:1px solid rgba(255,255,255,0.15);backdrop-filter:blur(8px)}
  .dl-btn-secondary:hover{background:rgba(255,255,255,0.13);transform:translateY(-2px)}

  /* coming soon badge */
  .cs-badge{display:inline-flex;align-items:center;gap:0.4rem;padding:0.5rem 1.1rem;border-radius:2rem;font-size:0.78rem;font-weight:600;background:rgba(255,255,255,0.06);color:#9ca3af;border:1px solid rgba(255,255,255,0.1);backdrop-filter:blur(8px)}
  .cs-dot{width:6px;height:6px;border-radius:50%;background:#f59e0b;animation:pulse 2s infinite}

  /* service cards */
  .svc-card{background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.08);border-radius:1.25rem;padding:2rem;transition:all .3s;backdrop-filter:blur(12px)}
  .svc-card:hover{background:rgba(255,255,255,0.07);border-color:rgba(74,222,128,0.3);transform:translateY(-6px);box-shadow:0 20px 60px rgba(0,0,0,0.4)}

  /* phone mockup */
  .phone-frame{background:linear-gradient(145deg,#1a2a1a,#0d1a0d);border:2px solid rgba(74,222,128,0.2);border-radius:2.5rem;width:240px;height:480px;position:relative;overflow:hidden;box-shadow:0 40px 100px rgba(0,0,0,0.6),0 0 0 1px rgba(255,255,255,0.05)}
  .phone-screen{position:absolute;inset:12px;border-radius:2rem;background:linear-gradient(180deg,#0f1f0f,#0a150a);overflow:hidden}
  .phone-notch{width:80px;height:16px;background:#000;border-radius:0 0 10px 10px;position:absolute;top:0;left:50%;transform:translateX(-50%)}

  /* stat cards */
  .stat-card{background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.08);border-radius:1rem;padding:1.25rem 1.5rem;text-align:center}

  /* nav */
  nav{position:sticky;top:0;z-index:50;background:rgba(10,15,26,0.85);backdrop-filter:blur(20px);border-bottom:1px solid rgba(255,255,255,0.07)}

  /* footer */
  footer{background:#050810;border-top:1px solid rgba(255,255,255,0.06)}

  @keyframes pulse{0%,100%{opacity:1}50%{opacity:0.4}}
  @keyframes float{0%,100%{transform:translateY(0)}50%{transform:translateY(-12px)}}
  .float-anim{animation:float 4s ease-in-out infinite}

  @media(max-width:768px){
    .hero-grid{grid-template-columns:1fr!important}
    .phone-frame{width:180px;height:360px}
    .dl-btn{padding:.75rem 1.25rem;font-size:.9rem}
  }
</style>
</head>
<body>

<!-- ═══ NAVBAR ═══════════════════════════════════════════════════════════════ -->
<nav class="px-6 py-4">
  <div class="max-w-7xl mx-auto flex items-center justify-between">
    <div class="flex items-center gap-3">
      <div class="w-9 h-9 rounded-xl bg-green-600 flex items-center justify-center font-black text-white text-lg">O</div>
      <span class="font-bold text-xl tracking-tight">Ort Marketplace</span>
    </div>
    <div class="hidden md:flex items-center gap-6 text-sm text-gray-400">
      <a href="#services" class="hover:text-white transition-colors">Services</a>
      <a href="#download" class="hover:text-white transition-colors">Download</a>
      <a href="#about" class="hover:text-white transition-colors">About</a>
      <a href="/web" class="text-green-400 hover:text-green-300 font-semibold transition-colors">Browse Marketplace →</a>
    </div>
    <div class="md:hidden">
      <a href="/web" class="text-sm text-green-400 font-semibold">Browse →</a>
    </div>
  </div>
</nav>

<!-- ═══ HERO ══════════════════════════════════════════════════════════════════ -->
<section class="hero-bg min-h-screen flex items-center px-6 py-24">
  <div class="max-w-7xl mx-auto w-full">
    <div class="grid hero-grid gap-16 items-center" style="grid-template-columns:1fr auto">

      <!-- left: copy -->
      <div>
        <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-green-900/30 border border-green-700/40 text-green-400 text-sm font-semibold mb-8">
          <span class="cs-dot"></span>
          Built for African Markets · Priced in UGX
        </div>

        <h1 class="text-5xl md:text-7xl font-black leading-tight mb-6">
          Africa's<br/>
          <span class="grad-text">Commerce</span><br/>
          Platform
        </h1>

        <p class="text-gray-400 text-lg md:text-xl max-w-xl mb-10 leading-relaxed">
          One app for <strong class="text-green-400">Agricultural produce</strong>,
          <strong class="text-blue-400">Manufacturing goods</strong>, and
          <strong class="text-purple-400">Professional services</strong>.
          Connect buyers and sellers across Uganda and the continent.
        </p>

        <!-- download buttons -->
        <div id="download" class="flex flex-wrap gap-4 mb-8">

          <!-- Android APK -->
          <a href="__APK_URL__" id="apkBtn"
             class="dl-btn dl-btn-primary glow"
             onclick="trackDownload('android')">
            <svg class="w-6 h-6" viewBox="0 0 24 24" fill="currentColor">
              <path d="M17.523 15.341A5.993 5.993 0 0 0 18 12c0-1.226-.37-2.367-1.003-3.316L19.2 6.48a.75.75 0 0 0-1.06-1.06l-2.204 2.204A5.97 5.97 0 0 0 12 6a5.97 5.97 0 0 0-3.936 1.624L5.86 5.42a.75.75 0 1 0-1.06 1.06l2.203 2.204A5.993 5.993 0 0 0 6 12c0 3.314 2.686 6 6 6a5.997 5.997 0 0 0 5.523-3.659zM9 12a1 1 0 1 1 2 0 1 1 0 0 1-2 0zm4 0a1 1 0 1 1 2 0 1 1 0 0 1-2 0z"/>
            </svg>
            Download for Android (APK)
          </a>

          <!-- iOS / TestFlight -->
          <a href="__IPA_URL__" id="iosBtn"
             class="dl-btn dl-btn-secondary"
             onclick="trackDownload('ios')">
            <svg class="w-6 h-6" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09z"/>
            </svg>
            Download for iOS
          </a>
        </div>

        <!-- coming soon store badges (no fake images) -->
        <div class="flex flex-wrap gap-3">
          <span class="cs-badge">
            <svg class="w-4 h-4 text-gray-500" viewBox="0 0 24 24" fill="currentColor">
              <path d="M3.609 1.814L13.792 12 3.61 22.186a.996.996 0 0 1-.61-.92V2.734a1 1 0 0 1 .609-.92zm10.89 10.893l2.302 2.302-10.937 6.333 8.635-8.635zm3.199-1.233l2.302 2.302a1 1 0 0 1 0 1.448l-2.302 2.302L15.396 12l2.302-2.526zM5.864 2.658L16.8 8.99l-2.302 2.302-8.635-8.635z"/>
            </svg>
            Play Store – Coming Soon
          </span>
          <span class="cs-badge">
            <svg class="w-4 h-4 text-gray-500" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09z"/>
            </svg>
            App Store – Coming Soon
          </span>
        </div>
      </div>

      <!-- right: phone mockup -->
      <div class="float-anim hidden md:flex justify-center">
        <div class="phone-frame glow">
          <div class="phone-notch"></div>
          <div class="phone-screen flex flex-col items-center justify-center gap-4 p-4">
            <!-- mini app UI in the phone -->
            <div class="text-center">
              <div class="w-12 h-12 rounded-2xl bg-green-700 flex items-center justify-center font-black text-white text-2xl mx-auto mb-2">O</div>
              <p class="text-green-400 font-bold text-sm">Ort</p>
              <p class="text-gray-500 text-xs">v2.0</p>
            </div>
            <div class="w-full space-y-2 mt-2">
              <div class="bg-green-900/40 border border-green-800/50 rounded-lg px-3 py-2 text-xs text-green-300">🌾 Agric</div>
              <div class="bg-blue-900/40 border border-blue-800/50 rounded-lg px-3 py-2 text-xs text-blue-300">🏭 Manufacturing</div>
              <div class="bg-purple-900/40 border border-purple-800/50 rounded-lg px-3 py-2 text-xs text-purple-300">🛠️ Services</div>
            </div>
            <div class="w-full mt-2">
              <div class="bg-green-600 rounded-lg py-2 text-center text-xs font-bold text-white">Browse Listings</div>
            </div>
          </div>
        </div>
      </div>

    </div>
  </div>
</section>

<!-- ═══ STATS ══════════════════════════════════════════════════════════════ -->
<section class="py-16 px-6 border-t border-white/5">
  <div class="max-w-5xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-4">
    <div class="stat-card">
      <div class="text-3xl font-black text-green-400 mb-1">3</div>
      <div class="text-sm text-gray-500">Service Categories</div>
    </div>
    <div class="stat-card">
      <div class="text-3xl font-black text-blue-400 mb-1">UGX</div>
      <div class="text-sm text-gray-500">Base Currency</div>
    </div>
    <div class="stat-card">
      <div class="text-3xl font-black text-purple-400 mb-1">54+</div>
      <div class="text-sm text-gray-500">African Countries</div>
    </div>
    <div class="stat-card">
      <div class="text-3xl font-black text-yellow-400 mb-1">100%</div>
      <div class="text-sm text-gray-500">African-focused</div>
    </div>
  </div>
</section>

<!-- ═══ THREE SERVICES ════════════════════════════════════════════════════ -->
<section id="services" class="py-24 px-6">
  <div class="max-w-7xl mx-auto">
    <div class="text-center mb-16">
      <h2 class="text-4xl md:text-5xl font-black mb-4">Three Independent <span class="grad-text">Modules</span></h2>
      <p class="text-gray-400 text-lg max-w-2xl mx-auto">Each service is a complete standalone marketplace — separate listings, separate logic, separate flows.</p>
    </div>

    <div class="grid md:grid-cols-3 gap-8">

      <!-- Agric -->
      <div class="svc-card group">
        <div class="w-14 h-14 rounded-2xl bg-green-900/50 border border-green-700/30 flex items-center justify-center text-3xl mb-6">🌾</div>
        <h3 class="text-2xl font-bold text-green-400 mb-3">Agric</h3>
        <p class="text-gray-400 leading-relaxed mb-6">
          Agricultural products, farm inputs, equipment, and fresh produce. Connect farmers directly with buyers, exporters, and cooperatives across Africa.
        </p>
        <ul class="space-y-2 text-sm text-gray-500 mb-6">
          <li class="flex items-center gap-2"><span class="text-green-500">✓</span> Farm produce & commodities</li>
          <li class="flex items-center gap-2"><span class="text-green-500">✓</span> Agricultural inputs & chemicals</li>
          <li class="flex items-center gap-2"><span class="text-green-500">✓</span> Farm equipment & machinery</li>
          <li class="flex items-center gap-2"><span class="text-green-500">✓</span> Livestock & aquaculture</li>
        </ul>
        <a href="/web?tab=agriculture" class="inline-flex items-center gap-2 text-green-400 font-semibold text-sm hover:text-green-300 transition-colors">Browse Agric Listings <span>→</span></a>
      </div>

      <!-- Manufacturing -->
      <div class="svc-card group">
        <div class="w-14 h-14 rounded-2xl bg-blue-900/50 border border-blue-700/30 flex items-center justify-center text-3xl mb-6">🏭</div>
        <h3 class="text-2xl font-bold text-blue-400 mb-3">Manufacturing</h3>
        <p class="text-gray-400 leading-relaxed mb-6">
          Made goods, production services, and industrial raw materials. Connect manufacturers with distributors, retailers, and B2B buyers.
        </p>
        <ul class="space-y-2 text-sm text-gray-500 mb-6">
          <li class="flex items-center gap-2"><span class="text-blue-500">✓</span> Finished manufactured goods</li>
          <li class="flex items-center gap-2"><span class="text-blue-500">✓</span> Raw materials & inputs</li>
          <li class="flex items-center gap-2"><span class="text-blue-500">✓</span> Production & processing services</li>
          <li class="flex items-center gap-2"><span class="text-blue-500">✓</span> Industrial equipment</li>
        </ul>
        <a href="/web?tab=manufacturing" class="inline-flex items-center gap-2 text-blue-400 font-semibold text-sm hover:text-blue-300 transition-colors">Browse Manufacturing <span>→</span></a>
      </div>

      <!-- Services -->
      <div class="svc-card group">
        <div class="w-14 h-14 rounded-2xl bg-purple-900/50 border border-purple-700/30 flex items-center justify-center text-3xl mb-6">🛠️</div>
        <h3 class="text-2xl font-bold text-purple-400 mb-3">Services</h3>
        <p class="text-gray-400 leading-relaxed mb-6">
          Professional, technical, and general services. From consulting and legal to transport and IT — your service marketplace for Africa.
        </p>
        <ul class="space-y-2 text-sm text-gray-500 mb-6">
          <li class="flex items-center gap-2"><span class="text-purple-500">✓</span> Professional consulting</li>
          <li class="flex items-center gap-2"><span class="text-purple-500">✓</span> Technical & IT services</li>
          <li class="flex items-center gap-2"><span class="text-purple-500">✓</span> Transport & logistics</li>
          <li class="flex items-center gap-2"><span class="text-purple-500">✓</span> Health, legal & financial</li>
        </ul>
        <a href="/web?tab=services" class="inline-flex items-center gap-2 text-purple-400 font-semibold text-sm hover:text-purple-300 transition-colors">Browse Services <span>→</span></a>
      </div>

    </div>
  </div>
</section>

<!-- ═══ HOW IT WORKS ═══════════════════════════════════════════════════════ -->
<section class="py-20 px-6 border-t border-white/5">
  <div class="max-w-5xl mx-auto">
    <h2 class="text-3xl md:text-4xl font-black text-center mb-14">How It <span class="grad-text">Works</span></h2>
    <div class="grid md:grid-cols-3 gap-8">
      <div class="text-center">
        <div class="w-16 h-16 rounded-full bg-green-900/40 border border-green-700/30 flex items-center justify-center text-2xl mx-auto mb-4">1️⃣</div>
        <h3 class="font-bold text-lg mb-2">Download the App</h3>
        <p class="text-gray-500 text-sm">Get the Ort app for Android or iOS and register in under 2 minutes.</p>
      </div>
      <div class="text-center">
        <div class="w-16 h-16 rounded-full bg-blue-900/40 border border-blue-700/30 flex items-center justify-center text-2xl mx-auto mb-4">2️⃣</div>
        <h3 class="font-bold text-lg mb-2">List or Browse</h3>
        <p class="text-gray-500 text-sm">Post your products or services, or browse thousands of African market listings.</p>
      </div>
      <div class="text-center">
        <div class="w-16 h-16 rounded-full bg-purple-900/40 border border-purple-700/30 flex items-center justify-center text-2xl mx-auto mb-4">3️⃣</div>
        <h3 class="font-bold text-lg mb-2">Connect & Trade</h3>
        <p class="text-gray-500 text-sm">Message sellers, request quotes, place orders, and track deliveries — all in one place.</p>
      </div>
    </div>
  </div>
</section>

<!-- ═══ ABOUT / CURRENCY ════════════════════════════════════════════════ -->
<section id="about" class="py-20 px-6 border-t border-white/5">
  <div class="max-w-5xl mx-auto grid md:grid-cols-2 gap-16 items-center">
    <div>
      <h2 class="text-3xl md:text-4xl font-black mb-6">Built for <span class="grad-text">Africa</span></h2>
      <p class="text-gray-400 leading-relaxed mb-6">
        Ort is anchored in Uganda with <strong class="text-white">Ugandan Shillings (UGX)</strong> as the base currency.
        All other users see prices automatically converted to their local currency based on their device location —
        with real-time exchange rates where possible.
      </p>
      <p class="text-gray-400 leading-relaxed mb-6">
        From Kampala to Nairobi, Lagos to Accra — Ort is built for local use and cross-border African trade.
      </p>
      <div class="flex flex-wrap gap-3">
        <span class="px-3 py-1 rounded-full bg-yellow-900/30 border border-yellow-700/30 text-yellow-400 text-sm font-medium">🇺🇬 Uganda (HQ)</span>
        <span class="px-3 py-1 rounded-full bg-green-900/30 border border-green-700/30 text-green-400 text-sm font-medium">East Africa</span>
        <span class="px-3 py-1 rounded-full bg-blue-900/30 border border-blue-700/30 text-blue-400 text-sm font-medium">Pan-Africa</span>
      </div>
    </div>
    <div class="space-y-4">
      <div class="bg-white/5 border border-white/8 rounded-xl p-4 flex items-center gap-4">
        <div class="text-2xl">💱</div>
        <div>
          <div class="font-semibold text-sm">Multi-currency Support</div>
          <div class="text-xs text-gray-500">Base: UGX · Auto-converts by device locale</div>
        </div>
      </div>
      <div class="bg-white/5 border border-white/8 rounded-xl p-4 flex items-center gap-4">
        <div class="text-2xl">📍</div>
        <div>
          <div class="font-semibold text-sm">Location-aware</div>
          <div class="text-xs text-gray-500">Country switching · Geolocation search</div>
        </div>
      </div>
      <div class="bg-white/5 border border-white/8 rounded-xl p-4 flex items-center gap-4">
        <div class="text-2xl">🔒</div>
        <div>
          <div class="font-semibold text-sm">Secure & Verified</div>
          <div class="text-xs text-gray-500">Verified businesses · Role-based access</div>
        </div>
      </div>
      <div class="bg-white/5 border border-white/8 rounded-xl p-4 flex items-center gap-4">
        <div class="text-2xl">⚡</div>
        <div>
          <div class="font-semibold text-sm">Flash Deals & Today's Deals</div>
          <div class="text-xs text-gray-500">Admin-managed · Max 100 flash listings</div>
        </div>
      </div>
    </div>
  </div>
</section>

<!-- ═══ PORTALS ═══════════════════════════════════════════════════════════ -->
<section class="py-20 px-6 border-t border-white/5">
  <div class="max-w-5xl mx-auto text-center mb-12">
    <h2 class="text-3xl font-black mb-4">Access <span class="grad-text">All Portals</span></h2>
    <p class="text-gray-400">Log in or register on any interface — accounts are unified across all portals.</p>
  </div>
  <div class="max-w-5xl mx-auto grid md:grid-cols-3 gap-6">
    <a href="https://piitrade.com/web" class="svc-card text-center group hover:border-green-500/40 block">
      <div class="text-3xl mb-3">🛒</div>
      <h3 class="font-bold text-lg mb-2 text-green-400">Marketplace</h3>
      <p class="text-gray-500 text-sm">Browse all listings publicly</p>
      <div class="mt-4 text-green-400 text-sm font-semibold group-hover:underline">piitrade.com/web →</div>
    </a>
    <a href="https://piitrade.com/medi" class="svc-card text-center group hover:border-blue-500/40 block">
      <div class="text-3xl mb-3">🏢</div>
      <h3 class="font-bold text-lg mb-2 text-blue-400">Companies & Agents</h3>
      <p class="text-gray-500 text-sm">Register company, org, or agent</p>
      <div class="mt-4 text-blue-400 text-sm font-semibold group-hover:underline">piitrade.com/medi →</div>
    </a>
    <a href="https://piitrade.com/const" class="svc-card text-center group hover:border-purple-500/40 block">
      <div class="text-3xl mb-3">⚙️</div>
      <h3 class="font-bold text-lg mb-2 text-purple-400">Admin Console</h3>
      <p class="text-gray-500 text-sm">Admin-only management panel</p>
      <div class="mt-4 text-purple-400 text-sm font-semibold group-hover:underline">piitrade.com/const →</div>
    </a>
  </div>
</section>

<!-- ═══ DOWNLOAD CTA ═══════════════════════════════════════════════════ -->
<section class="py-24 px-6 border-t border-white/5">
  <div class="max-w-3xl mx-auto text-center">
    <h2 class="text-4xl md:text-5xl font-black mb-6">Get the App <span class="grad-text">Today</span></h2>
    <p class="text-gray-400 text-lg mb-10">Download directly — no app store required yet.</p>
    <div class="flex flex-wrap justify-center gap-4 mb-8">
      <a href="__APK_URL__" class="dl-btn dl-btn-primary glow" onclick="trackDownload('android-cta')">
        <svg class="w-6 h-6" viewBox="0 0 24 24" fill="currentColor">
          <path d="M17.523 15.341A5.993 5.993 0 0 0 18 12c0-1.226-.37-2.367-1.003-3.316L19.2 6.48a.75.75 0 0 0-1.06-1.06l-2.204 2.204A5.97 5.97 0 0 0 12 6a5.97 5.97 0 0 0-3.936 1.624L5.86 5.42a.75.75 0 1 0-1.06 1.06l2.203 2.204A5.993 5.993 0 0 0 6 12c0 3.314 2.686 6 6 6a5.997 5.997 0 0 0 5.523-3.659zM9 12a1 1 0 1 1 2 0 1 1 0 0 1-2 0zm4 0a1 1 0 1 1 2 0 1 1 0 0 1-2 0z"/>
        </svg>
        Android APK Download
      </a>
      <a href="__IPA_URL__" class="dl-btn dl-btn-secondary glow-blue">
        <svg class="w-6 h-6" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09z"/>
        </svg>
        iOS Download / TestFlight
      </a>
    </div>
    <div class="flex flex-wrap justify-center gap-3">
      <span class="cs-badge"><span class="cs-dot"></span>Google Play Store – Coming Soon</span>
      <span class="cs-badge"><span class="cs-dot"></span>Apple App Store – Coming Soon</span>
    </div>
  </div>
</section>

<!-- ═══ FOOTER ═══════════════════════════════════════════════════════════ -->
<footer class="py-12 px-6">
  <div class="max-w-7xl mx-auto">
    <div class="grid md:grid-cols-4 gap-8 mb-10">
      <div>
        <div class="flex items-center gap-2 mb-4">
          <div class="w-8 h-8 rounded-lg bg-green-600 flex items-center justify-center font-black text-white">O</div>
          <span class="font-bold">Ort Marketplace</span>
        </div>
        <p class="text-gray-600 text-sm">Africa's commerce platform for Agric, Manufacturing &amp; Services.</p>
      </div>
      <div>
        <h4 class="font-semibold text-gray-300 mb-3 text-sm">Services</h4>
        <ul class="space-y-2 text-sm text-gray-600">
          <li><a href="/web?tab=agriculture" class="hover:text-gray-400">Agriculture</a></li>
          <li><a href="/web?tab=manufacturing" class="hover:text-gray-400">Manufacturing</a></li>
          <li><a href="/web?tab=services" class="hover:text-gray-400">Services</a></li>
        </ul>
      </div>
      <div>
        <h4 class="font-semibold text-gray-300 mb-3 text-sm">Portals</h4>
        <ul class="space-y-2 text-sm text-gray-600">
          <li><a href="/web" class="hover:text-gray-400">Marketplace</a></li>
          <li><a href="/medi" class="hover:text-gray-400">Companies &amp; Agents</a></li>
          <li><a href="/const" class="hover:text-gray-400">Admin Console</a></li>
        </ul>
      </div>
      <div>
        <h4 class="font-semibold text-gray-300 mb-3 text-sm">Download</h4>
        <ul class="space-y-2 text-sm text-gray-600">
          <li><a href="__APK_URL__" class="hover:text-gray-400">Android APK</a></li>
          <li><a href="__IPA_URL__" class="hover:text-gray-400">iOS / TestFlight</a></li>
          <li class="text-gray-700">Play Store (soon)</li>
          <li class="text-gray-700">App Store (soon)</li>
        </ul>
      </div>
    </div>
    <div class="border-t border-white/5 pt-6 flex flex-wrap justify-between items-center gap-4 text-sm text-gray-700">
      <span>© 2024 Ort Marketplace. Built for Africa.</span>
      <span>Base currency: UGX · Multi-currency supported</span>
    </div>
  </div>
</footer>

<script>
function trackDownload(platform) {
  console.log('Download clicked:', platform);
  // Analytics hook — replace with your analytics calls
}

// Update download URLs from server (injected via template)
(function() {
  const apkUrl = '""" + _APK_URL + r"""';
  const ipaUrl = '""" + _IPA_URL + r"""';
  document.querySelectorAll('#apkBtn,[href="__APK_URL__"]').forEach(el => {
    if (apkUrl && apkUrl !== '#apk-coming-soon') el.href = apkUrl;
    else el.addEventListener('click', e => {
      e.preventDefault();
      alert('Android APK download coming soon!\n\nSet the APK_DOWNLOAD_URL environment variable to enable direct download.');
    });
  });
  document.querySelectorAll('#iosBtn,[href="__IPA_URL__"]').forEach(el => {
    if (ipaUrl && ipaUrl !== '#ios-coming-soon') el.href = ipaUrl;
    else el.addEventListener('click', e => {
      e.preventDefault();
      alert('iOS download coming soon!\n\nSet the IPA_DOWNLOAD_URL or TESTFLIGHT_URL environment variable to enable iOS download.');
    });
  });
})();
</script>
</body>
</html>"""

_HTML_RENDERED = (
    _HTML
    .replace("__APK_URL__", _APK_URL)
    .replace("__IPA_URL__", _IPA_URL)
)


@router.get("/", response_class=HTMLResponse, include_in_schema=False)
def landing_page():
    return HTMLResponse(content=_HTML_RENDERED)
