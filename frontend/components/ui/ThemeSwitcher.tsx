'use client';
/**
 * ThemeSwitcher — allows users to switch the site's primary colour theme.
 * The chosen theme is persisted in localStorage and applied as CSS custom
 * properties on <html> so every page reflects the selection.
 *
 * Props:
 *  compact  – renders a row of colour swatches (default false)
 *  dropdown – renders a named <select> dropdown suitable for the top bar
 */
import { useState, useEffect } from 'react';
import { useAuth } from '@/context/AuthContext';

export type ThemeKey =
  | 'sky'
  | 'white'
  | 'dark'
  | 'emerald'
  | 'violet'
  | 'rose'
  | 'amber'
  | 'indigo'
  | 'navy'
  | 'ocean'
  | 'teal'
  | 'gold'
  | 'midnight'
  | 'forest'
  | 'coral'
  | 'royal';

interface ThemeOption {
  key: ThemeKey;
  label: string;
  bg: string;           // Tailwind/inline bg for the swatch
  primary: string;      // CSS hex for --theme-primary
  primaryDark: string;  // CSS hex for --theme-primary-dark
  bg100: string;        // CSS hex for --theme-bg-light
  textClass: string;    // Tailwind text class for readable label
  textBody: string;     // CSS hex for --theme-text (body text colour)
  textOnPrimary: string; // CSS hex for --theme-text-on-primary
}

const THEMES: ThemeOption[] = [
  {
    key: 'sky',
    label: 'Light Blue',
    bg: '#e0f2fe',
    primary: '#0EA5E9',
    primaryDark: '#0284c7',
    bg100: '#e0f2fe',
    textClass: 'text-sky-700',
    textBody: '#0f172a',
    textOnPrimary: '#ffffff',
  },
  {
    key: 'white',
    label: 'White',
    bg: '#f8fafc',
    primary: '#64748b',
    primaryDark: '#475569',
    bg100: '#f1f5f9',
    textClass: 'text-slate-600',
    textBody: '#111827',
    textOnPrimary: '#ffffff',
  },
  {
    key: 'dark',
    label: 'Dark',
    bg: '#1e293b',
    primary: '#38bdf8',
    primaryDark: '#0ea5e9',
    bg100: '#0f172a',
    textClass: 'text-sky-300',
    textBody: '#e2e8f0',
    textOnPrimary: '#0f172a',
  },
  {
    key: 'emerald',
    label: 'Emerald',
    bg: '#d1fae5',
    primary: '#10b981',
    primaryDark: '#059669',
    bg100: '#ecfdf5',
    textClass: 'text-emerald-700',
    textBody: '#064e3b',
    textOnPrimary: '#ffffff',
  },
  {
    key: 'violet',
    label: 'Violet',
    bg: '#ede9fe',
    primary: '#7c3aed',
    primaryDark: '#6d28d9',
    bg100: '#f5f3ff',
    textClass: 'text-violet-700',
    textBody: '#1e1b4b',
    textOnPrimary: '#ffffff',
  },
  {
    key: 'rose',
    label: 'Rose',
    bg: '#ffe4e6',
    primary: '#f43f5e',
    primaryDark: '#e11d48',
    bg100: '#fff1f2',
    textClass: 'text-rose-700',
    textBody: '#4c0519',
    textOnPrimary: '#ffffff',
  },
  {
    key: 'amber',
    label: 'Amber',
    bg: '#fef3c7',
    primary: '#f59e0b',
    primaryDark: '#d97706',
    bg100: '#fffbeb',
    textClass: 'text-amber-700',
    textBody: '#451a03',
    textOnPrimary: '#1c1917',
  },
  {
    key: 'indigo',
    label: 'Indigo',
    bg: '#e0e7ff',
    primary: '#4f46e5',
    primaryDark: '#4338ca',
    bg100: '#eef2ff',
    textClass: 'text-indigo-700',
    textBody: '#1e1b4b',
    textOnPrimary: '#ffffff',
  },
  {
    key: 'navy',
    label: 'Navy Blue',
    bg: '#dbeafe',
    primary: '#1d4ed8',
    primaryDark: '#1e40af',
    bg100: '#eff6ff',
    textClass: 'text-blue-800',
    textBody: '#1e3a5f',
    textOnPrimary: '#ffffff',
  },
  {
    key: 'ocean',
    label: 'Ocean',
    bg: '#cffafe',
    primary: '#0891b2',
    primaryDark: '#0e7490',
    bg100: '#ecfeff',
    textClass: 'text-cyan-700',
    textBody: '#083344',
    textOnPrimary: '#ffffff',
  },
  {
    key: 'teal',
    label: 'Teal',
    bg: '#ccfbf1',
    primary: '#0d9488',
    primaryDark: '#0f766e',
    bg100: '#f0fdfa',
    textClass: 'text-teal-700',
    textBody: '#042f2e',
    textOnPrimary: '#ffffff',
  },
  {
    key: 'gold',
    label: 'Gold Luxury',
    bg: '#fef9c3',
    primary: '#ca8a04',
    primaryDark: '#a16207',
    bg100: '#fefce8',
    textClass: 'text-yellow-700',
    textBody: '#422006',
    textOnPrimary: '#ffffff',
  },
  {
    key: 'midnight',
    label: 'Midnight',
    bg: '#1e1b4b',
    primary: '#818cf8',
    primaryDark: '#6366f1',
    bg100: '#0f0c29',
    textClass: 'text-indigo-300',
    textBody: '#c7d2fe',
    textOnPrimary: '#0f0c29',
  },
  {
    key: 'forest',
    label: 'Forest',
    bg: '#dcfce7',
    primary: '#16a34a',
    primaryDark: '#15803d',
    bg100: '#f0fdf4',
    textClass: 'text-green-700',
    textBody: '#052e16',
    textOnPrimary: '#ffffff',
  },
  {
    key: 'coral',
    label: 'Coral',
    bg: '#ffe4d6',
    primary: '#ea580c',
    primaryDark: '#c2410c',
    bg100: '#fff7ed',
    textClass: 'text-orange-700',
    textBody: '#431407',
    textOnPrimary: '#ffffff',
  },
  {
    key: 'royal',
    label: 'Royal Purple',
    bg: '#f3e8ff',
    primary: '#9333ea',
    primaryDark: '#7e22ce',
    bg100: '#faf5ff',
    textClass: 'text-purple-700',
    textBody: '#3b0764',
    textOnPrimary: '#ffffff',
  },
];

const GUEST_STORAGE_KEY = '3re-theme:guest';

function applyTheme(theme: ThemeOption, animOrigin?: { x: number; y: number }) {
  const root = document.documentElement;

  // Ripple animation from click origin
  if (animOrigin) {
    const ripple = document.createElement('div');
    ripple.className = 'theme-ripple';
    const size = Math.max(window.innerWidth, window.innerHeight) * 1.5;
    ripple.style.cssText = `
      width: ${size}px; height: ${size}px;
      left: ${animOrigin.x - size / 2}px; top: ${animOrigin.y - size / 2}px;
      background: radial-gradient(circle, ${theme.primary}66, ${theme.primaryDark}33, transparent 70%);
    `;
    document.body.appendChild(ripple);
    setTimeout(() => ripple.remove(), 750);
  }

  // Flash the header/nav elements
  const themeEls = document.querySelectorAll<HTMLElement>('.theme-header-bg, .theme-category-bar, header');
  themeEls.forEach((el) => {
    el.classList.remove('theme-animate');
    void el.offsetWidth; // force reflow
    el.classList.add('theme-animate');
    el.addEventListener('animationend', () => el.classList.remove('theme-animate'), { once: true });
  });

  root.style.setProperty('--theme-primary', theme.primary);
  root.style.setProperty('--theme-primary-dark', theme.primaryDark);
  root.style.setProperty('--theme-bg-light', theme.bg100);
  root.style.setProperty('--theme-text', theme.textBody);
  root.style.setProperty('--theme-text-on-primary', theme.textOnPrimary);
  // Toggle dark mode class
  if (theme.key === 'dark' || theme.key === 'midnight') {
    root.classList.add('theme-dark');
  } else {
    root.classList.remove('theme-dark');
  }
}

export default function ThemeSwitcher({
  compact = false,
  dropdown = false,
  light = false,
}: {
  compact?: boolean;
  dropdown?: boolean;
  /** Set to true when rendered on a light/white background so text stays visible */
  light?: boolean;
}) {
  const { user } = useAuth();
  const [current, setCurrent] = useState<ThemeKey>('sky');
  const storageKey = user?.id ? `3re-theme:user:${user.id}` : GUEST_STORAGE_KEY;

  // Load saved theme on mount
  useEffect(() => {
    if (typeof window === 'undefined') return;
    const saved = localStorage.getItem(storageKey) as ThemeKey | null;
    if (saved && THEMES.find((t) => t.key === saved)) {
      setCurrent(saved);
      const t = THEMES.find((th) => th.key === saved)!;
      applyTheme(t);
      return;
    }
    // Default blue theme for guests/new users and users without a saved preference.
    const defaultTheme = THEMES.find((th) => th.key === 'sky')!;
    setCurrent('sky');
    applyTheme(defaultTheme);
  }, [storageKey]);

  const handleSelect = (themeKey: ThemeKey, event?: React.MouseEvent | React.ChangeEvent) => {
    const theme = THEMES.find((t) => t.key === themeKey);
    if (!theme) return;
    setCurrent(themeKey);
    if (typeof window !== 'undefined') {
      try {
        localStorage.setItem(storageKey, themeKey);
      } catch (err) {
        console.warn('Could not save theme preference:', err);
      }
    }
    let origin: { x: number; y: number } | undefined;
    if (event && 'clientX' in event) {
      origin = { x: (event as React.MouseEvent).clientX, y: (event as React.MouseEvent).clientY };
    }
    applyTheme(theme, origin);
  };

  const currentTheme = THEMES.find((t) => t.key === current);

  return (
    <div className={compact ? 'flex items-center gap-1.5' : 'flex flex-col gap-2'}>
      {dropdown ? (
        /* ── Compact icon-only variant for the header ── */
        <div className="relative">
          <button
            type="button"
            aria-label="Select page theme colour"
            title={`Theme: ${currentTheme?.label ?? 'Default'}`}
            onClick={(e) => {
              // Toggle a small popover by cycling through themes on click
              const nextIndex = (THEMES.findIndex((t) => t.key === current) + 1) % THEMES.length;
              handleSelect(THEMES[nextIndex].key, e);
            }}
            className={`w-5 h-5 rounded-full flex-shrink-0 transition-all duration-300 border-2 hover:scale-110 focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-white/70 ${
              light ? 'border-gray-300' : 'border-white/50'
            }`}
            style={{
              backgroundColor: currentTheme?.primary ?? '#0EA5E9',
              boxShadow: `0 0 8px 2px ${currentTheme?.primary ?? '#0EA5E9'}55`,
            }}
          />
        </div>
      ) : (
        /* ── Swatch variant (original) ── */
        <div className="flex flex-wrap gap-2">
          {THEMES.map((t) => (
            <button
              key={t.key}
              type="button"
              onClick={(e) => handleSelect(t.key, e)}
              title={t.label}
              aria-label={`Switch to ${t.label} theme`}
              className={`relative w-7 h-7 rounded-full border-2 transition-all focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-sky-400 ${
                current === t.key
                  ? 'border-sky-500 scale-110 shadow-md'
                  : 'border-transparent hover:scale-110 hover:border-gray-300'
              }`}
              style={{ backgroundColor: t.primary }}
            >
              {current === t.key && (
                <span className="absolute inset-0 flex items-center justify-center text-white text-[10px] font-bold">✓</span>
              )}
            </button>
          ))}
        </div>
      )}
      {!compact && !dropdown && (
        <p className="text-xs text-gray-400">
          Selected: <span className="font-semibold text-gray-600">{THEMES.find((t) => t.key === current)?.label}</span>
        </p>
      )}
    </div>
  );
}
