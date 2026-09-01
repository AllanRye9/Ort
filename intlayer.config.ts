import type { IntlayerConfig } from "intlayer";

const config: IntlayerConfig = {
  internationalization: {
    // Define your supported languages using standard tags
    locales: [
      "en",       // English (Default)
      "ach",      // Acoli
      "lg",       // Luganda
      "nyn",      // Runyankole
      "lam",      // Lango
      "teo",      // Ateso
    ],
    defaultLocale: "en",
    strict: false, // Disables default enum checks to allow custom codes
  },
};

export default config;
