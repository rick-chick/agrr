/** Resolves the deploy-time static asset prefix (e.g. "static" on agrr.net). */
export function resolveStaticPathPrefix(): string {
  if (typeof window !== 'undefined') {
    const fromWindow = (window as { STATIC_PATH_PREFIX?: string }).STATIC_PATH_PREFIX;
    if (fromWindow) {
      return fromWindow;
    }
  }

  if (typeof document === 'undefined') {
    return '';
  }

  const mainScript = document.querySelector(
    'script[type="module"][src*="/main-"]'
  ) as HTMLScriptElement | null;
  const src = mainScript?.getAttribute('src') ?? '';
  const match = src.match(/^\/([^/]+)\/main-/);
  return match?.[1] ?? '';
}
