'use client';
/**
 * ThemeSwitcher — the site now ships with a single, locked brand colour
 * (Piitrade Orange) so this component no longer offers a colour picker.
 * It still applies the brand CSS custom properties on <html> on mount
 * (some components read --theme-primary / --theme-bg-light etc.), and
 * renders a small static swatch wherever it's embedded so existing pages
 * that reference it don't end up with an empty gap.
 */
import { useEffect } from 'react';

export type ThemeKey = 'orange';

const ORANGE_THEME = {
  key: 'orange' as ThemeKey,
  label: 'Piitrade Orange',
  primary: '#F55906',
  primaryDark: '#E94B00',
  bg100: '#FFE4D1',
  textBody: '#1a1310',
  textOnPrimary: '#ffffff',
};

function applyTheme() {
  const root = document.documentElement;
  root.style.setProperty('--theme-primary', ORANGE_THEME.primary);
  root.style.setProperty('--theme-primary-dark', ORANGE_THEME.primaryDark);
  root.style.setProperty('--theme-bg-light', ORANGE_THEME.bg100);
  root.style.setProperty('--theme-text', ORANGE_THEME.textBody);
  root.style.setProperty('--theme-text-on-primary', ORANGE_THEME.textOnPrimary);
  root.classList.remove('theme-dark');
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
  useEffect(() => {
    applyTheme();
  }, []);

  // The header's top-bar colour picker has been removed entirely — the site
  // now always shows the single Piitrade Orange brand colour.
  if (dropdown) return null;

  return (
    <div className={compact ? 'flex items-center gap-1.5' : 'flex flex-col gap-2'}>
      <span
        aria-label={`Site theme: ${ORANGE_THEME.label}`}
        title={ORANGE_THEME.label}
        className={`w-7 h-7 rounded-full border-2 ${light ? 'border-gray-300' : 'border-white/50'}`}
        style={{ backgroundColor: ORANGE_THEME.primary }}
      />
      {!compact && (
        <p className="text-xs text-gray-400">
          Selected: <span className="font-semibold text-gray-600">{ORANGE_THEME.label}</span>
        </p>
      )}
    </div>
  );
}
