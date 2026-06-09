export type BrowserRegion = 'jp' | 'us' | 'in';
export type AppLang = 'ja' | 'en' | 'in';

const DEFAULT_BROWSER_REGION: BrowserRegion = 'jp';
/** BCP 47 language subtags → reference-farm region (checked left-to-right). */
const LANGUAGE_TO_REGION: Record<string, BrowserRegion> = {
  ja: 'jp',
  en: 'us',
  hi: 'in'
};

/** Region subtags when no language subtag matched (checked right-to-left). */
const REGION_SUBTAG_TO_REGION: Record<string, BrowserRegion> = {
  jp: 'jp',
  us: 'us',
  in: 'in'
};

/** Maps Angular app language (navbar / ngx-translate) to reference-farm region. */
export const mapAppLangToBrowserRegion = (lang?: string | null): BrowserRegion | undefined => {
  switch (lang) {
    case 'ja':
      return 'jp';
    case 'en':
      return 'us';
    case 'in':
      return 'in';
    default:
      return undefined;
  }
};

const splitLocaleParts = (locale: string): string[] => {
  return locale
    .toLowerCase()
    .split(/[-_]/)
    .map((segment) => segment.trim())
    .filter(Boolean);
};

export const mapLocaleToBrowserRegion = (locale?: string | null): BrowserRegion | undefined => {
  if (!locale) {
    return undefined;
  }

  const localeParts = splitLocaleParts(locale);

  for (const part of localeParts) {
    const region = LANGUAGE_TO_REGION[part];
    if (region) {
      return region;
    }
  }

  for (let index = localeParts.length - 1; index >= 0; index -= 1) {
    const region = REGION_SUBTAG_TO_REGION[localeParts[index]];
    if (region) {
      return region;
    }
  }

  return undefined;
};

/** Prefer app language, then browser locales (aligned with resolveInitialAppLang). */
export const resolveReferenceFarmRegion = (appLang?: string | null): BrowserRegion => {
  const fromApp = mapAppLangToBrowserRegion(appLang);
  if (fromApp) {
    return fromApp;
  }
  return detectBrowserRegion();
};

export const detectBrowserRegion = (): BrowserRegion => {
  if (typeof navigator === 'undefined') {
    return DEFAULT_BROWSER_REGION;
  }

  const localeCandidates = [
    ...(Array.isArray(navigator.languages) ? navigator.languages : []),
    navigator.language
  ].filter(Boolean);

  for (const candidate of localeCandidates) {
    const region = mapLocaleToBrowserRegion(candidate);
    if (region) {
      return region;
    }
  }

  return DEFAULT_BROWSER_REGION;
};
