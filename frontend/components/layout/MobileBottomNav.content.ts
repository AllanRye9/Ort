import { t, type Dictionary } from 'intlayer';

/**
 * TRANSLATION QUALITY NOTE: `en` and `lg` (Luganda) are reasonably reliable.
 * `ach` (Acoli), `nyn` (Runyankole), `lam` (Lango), and `teo` (Ateso) are
 * AI best-effort — these are low-resource languages with limited training
 * data, and these four in particular should be reviewed by a native
 * speaker before shipping to real users. Ship `en`/`lg` with confidence;
 * treat the other four as a draft to be corrected, not a finished
 * translation.
 */
const content = {
  key: 'mobileBottomNav',
  content: {
    home: t({
      en: 'Home',
      lg: 'Awaka',
      ach: 'Paco',
      nyn: 'Aha',
      lam: 'Ot',
      teo: 'Ekek',
    }),
    browse: t({
      en: 'Browse',
      lg: 'Noonya',
      ach: 'Nong',
      nyn: 'Shaba',
      lam: 'Yeny',
      teo: 'Aginakin',
    }),
    sell: t({
      en: 'Sell',
      lg: 'Tunda',
      ach: 'Cato',
      nyn: 'Gurisa',
      lam: 'Cato',
      teo: 'Ajok',
    }),
    account: t({
      en: 'Account',
      lg: 'Akawunti',
      ach: 'Akaunti',
      nyn: 'Akaunti',
      lam: 'Akaunti',
      teo: 'Akaunti',
    }),
  },
} satisfies Dictionary;

export default content;
