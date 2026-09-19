import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import en from './locales/en.json';

export const defaultNS = 'translation';
export const resources = {
  en: { translation: en },
} as const;

/**
 * Initialised for its side effect — `src/app/providers/appProvider.tsx`
 * imports this module before rendering so `useTranslation` has a ready i18n
 * instance on the first frame.
 *
 * Only English ships today. `fallbackLng` means a missing key in a future
 * locale renders the English string rather than the raw key.
 */
i18n
  .use(initReactI18next)
  .init({
    resources,
    lng: 'en',
    fallbackLng: 'en',
    defaultNS,
    interpolation: {
      // React already escapes interpolated values.
      escapeValue: false,
    },
    returnNull: false,
  })
  .catch(error => {
    console.error('[i18n] Failed to initialise', error);
  });

export default i18n;
