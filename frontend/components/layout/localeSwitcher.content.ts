import { t, type Dictionary } from "intlayer";

// NOTE: translations below for ach/lg/nyn/lam/teo are unverified best-effort
// placeholders meant to demonstrate the content-declaration pattern — have a
// native speaker review them (or run `npx intlayer fill`) before shipping.
// The `en` values are the ones actually reviewed.
const localeSwitcherContent = {
  key: "locale-switcher",
  content: {
    ariaLabel: t({
      en: "Select language",
      ach: "Yer leb",
      lg: "Londa olulimi",
      nyn: "Toranura orurimi",
      lam: "Yer leb",
      teo: "Yer atugoo",
    }),
    regionLabel: t({
      en: "Language",
      ach: "Leb",
      lg: "Olulimi",
      nyn: "Orurimi",
      lam: "Leb",
      teo: "Atugoo",
    }),
  },
} satisfies Dictionary;

export default localeSwitcherContent;
