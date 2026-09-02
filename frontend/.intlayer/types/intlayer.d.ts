import "intlayer";
import _1sv9598mb9v from './locale-switcher.ts';

declare module 'intlayer' {
  interface __DictionaryRegistry {
    "locale-switcher": typeof _1sv9598mb9v;
  }

  interface __DeclaredLocalesRegistry {
    "en": 1;
    "ach": 1;
    "lg": 1;
    "nyn": 1;
    "lam": 1;
    "teo": 1;
  }

  interface __RequiredLocalesRegistry {
    "en": 1;
    "ach": 1;
    "lg": 1;
    "nyn": 1;
    "lam": 1;
    "teo": 1;
  }

  interface __SchemaRegistry {

  }

  interface __StrictModeRegistry { mode: 'loose' }

  interface __EditorRegistry { enabled : false }

  interface __RoutingRegistry { mode: 'no-prefix'; defaultLocale: 'en' }
}
