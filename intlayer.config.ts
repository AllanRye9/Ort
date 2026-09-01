import type { IntlayerConfig } from "intlayer";
import type { Locale } from "@intlayer/types";

// Custom locale codes (ach/lg/nyn/lam/teo) aren't in intlayer's built-in
// `Locale` union — it's a plain string-literal union, not an interface, so
// it can't be extended via module augmentation. `strict: false` below only
// relaxes runtime validation, not this compile-time list, so the cast is
// required for the type-check step to pass. Intlayer itself treats any
// string as a valid locale at runtime. Keep in sync with
// frontend/intlayer.config.ts (the copy that actually governs the build).
const locales = [
  "en",       // English (Default)
  "ach",      // Acoli
  "lg",       // Luganda
  "nyn",      // Runyankole
  "lam",      // Lango
  "teo",      // Ateso
] as unknown as Locale[];

const config: IntlayerConfig = {
  internationalization: {
    // Define your supported languages using standard tags
    locales,
    defaultLocale: "en",
    // "loose" is the current schema's equivalent of the old boolean
    // `strict: false` intent — see frontend/intlayer.config.ts for details.
    strictMode: "loose",
  },
};

export default config;
