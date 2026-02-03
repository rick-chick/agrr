export type BrowserRegion = 'jp' | 'us' | 'in';

const DEFAULT_BROWSER_REGION: BrowserRegion = 'jp';
const LOCALE_TO_REGION: Record<string, BrowserRegion> = {
  ja: 'jp',
  jp: 'jp',
  en: 'us',
  us: 'us',
  in: 'in'
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
  for (let index = localeParts.length - 1; index >= 0; index -= 1) {
    const part = localeParts[index];
    const region = LOCALE_TO_REGION[part];
    if (region) {
      return region;
    }
  }

  return undefined;
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
