import { Injectable, inject, PLATFORM_ID, REQUEST } from '@angular/core';
import { isPlatformServer } from '@angular/common';
import { Meta, Title } from '@angular/platform-browser';
import { TranslateService } from '@ngx-translate/core';
import type { AppLang } from '../app-locale';
import type { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { Router } from '@angular/router';
import { resolveSeoKeyPrefix } from './route-seo-meta.config';
import { buildSiteStructuredDataDocument, SITE_STRUCTURED_DATA_SCRIPT_ID } from './site-structured-data';
import { resolveSpaHreflangUrls } from './spa-hreflang';
import {
  buildPublicPlanResultsShareUrl,
  extractPublicPlanResultsSeoLabels
} from './public-plan-results-seo-meta';

function documentHtmlLang(angularLang: AppLang): string {
  return angularLang === 'in' ? 'hi' : angularLang;
}

/** @internal exported for unit tests */
export function buildSelfCanonicalUrl(origin: string, pathname: string): string {
  if (!origin) {
    return '';
  }
  return `${origin}${pathname.split('?')[0]}`;
}

/** Production origin for build-time prerender canonical / OGP URLs. */
export const PRERENDER_CANONICAL_ORIGIN = 'https://agrr.net';

function ogLocale(angularLang: AppLang): string {
  if (angularLang === 'ja') return 'ja_JP';
  if (angularLang === 'en') return 'en_US';
  return 'hi_IN';
}

function isResolvedTranslation(value: string, keyPrefix: string): boolean {
  return Boolean(value) && !value.startsWith(keyPrefix);
}

/** Default OGP image served from `frontend/public/` (1200×630). */
export const DEFAULT_OGP_IMAGE_PATH = '/og-default.png';

@Injectable({ providedIn: 'root' })
export class AppSeoMetaService {
  private readonly translate = inject(TranslateService);
  private readonly title = inject(Title);
  private readonly meta = inject(Meta);
  private readonly platformId = inject(PLATFORM_ID);
  private readonly request = inject(REQUEST, { optional: true });
  private readonly router = inject(Router, { optional: true });
  private noIndexActive = false;

  applyNoIndexMeta(): void {
    this.meta.updateTag({ name: 'robots', content: 'noindex' });
    this.noIndexActive = true;
  }

  removeNoIndexMeta(): void {
    this.meta.removeTag('name="robots"');
    this.noIndexActive = false;
  }

  refreshDefaultMeta(): void {
    const angularLang = (this.translate.currentLang || 'ja') as AppLang;
    if (typeof document !== 'undefined') {
      document.documentElement.lang = documentHtmlLang(angularLang);
    }

    const path = this.readPathname();
    const origin = this.readOrigin();
    const keyPrefix = resolveSeoKeyPrefix(path);
    const hreflang = resolveSpaHreflangUrls(origin, path);
    const canonical = hreflang?.canonicalUrl ?? buildSelfCanonicalUrl(origin, path);
    this.applySeoFromKeyPrefix(keyPrefix, canonical);
  }

  refreshPublicPlanResultsMeta(planId: number | null, planData: CultivationPlanData | null): void {
    const angularLang = (this.translate.currentLang || 'ja') as AppLang;
    if (typeof document !== 'undefined') {
      document.documentElement.lang = documentHtmlLang(angularLang);
    }

    if (!planId || !planData?.success) {
      const path = this.readPathname();
      const keyPrefix = resolveSeoKeyPrefix(path);
      this.applySeoFromKeyPrefix(keyPrefix, buildSelfCanonicalUrl(this.readOrigin(), path));
      return;
    }

    const labels = extractPublicPlanResultsSeoLabels(planData);
    const params = {
      planLabel: labels.planLabel,
      cropLabels: labels.cropLabels,
      planYear: labels.planYear,
      totalArea: labels.totalArea
    };
    const keyPrefix = 'pages.public_plans_results';
    const title = this.translate.instant(`${keyPrefix}.title`, params);
    const description = this.translate.instant(`${keyPrefix}.description`, params);
    let ogDescription = this.translate.instant(`${keyPrefix}.og_description`, params);
    if (!isResolvedTranslation(ogDescription, `${keyPrefix}.`)) {
      ogDescription = description;
    }

    const ogUrl = buildPublicPlanResultsShareUrl(this.readOrigin(), planId);
    this.applyResolvedSeo({ title, description, ogDescription, ogUrl, keyPrefix });
  }

  private readPathname(): string {
    if (!isPlatformServer(this.platformId) && typeof window !== 'undefined' && window.location?.pathname) {
      return window.location.pathname;
    }
    const requestUrl = this.readRequestUrl();
    if (requestUrl) {
      try {
        return new URL(requestUrl).pathname;
      } catch {
        return '/';
      }
    }
    const routerPath = this.router?.url?.split('?')[0];
    if (routerPath) {
      return routerPath.startsWith('/') ? routerPath : `/${routerPath}`;
    }
    return '/';
  }

  private readOrigin(): string {
    if (!isPlatformServer(this.platformId)) {
      if (typeof window !== 'undefined' && window.location) {
        return window.location.origin ?? '';
      }
      return '';
    }
    const requestUrl = this.readRequestUrl();
    if (requestUrl) {
      try {
        return new URL(requestUrl).origin;
      } catch {
        return PRERENDER_CANONICAL_ORIGIN;
      }
    }
    return PRERENDER_CANONICAL_ORIGIN;
  }

  private readRequestUrl(): string | undefined {
    const request = this.request as Request | null | undefined;
    return request?.url;
  }

  private applySeoFromKeyPrefix(keyPrefix: string, ogUrl: string): void {
    const title = this.translate.instant(`${keyPrefix}.title`);
    const description = this.translate.instant(`${keyPrefix}.description`);
    const keywords = this.translate.instant('meta.default.keywords');
    let ogDescription = this.translate.instant(`${keyPrefix}.og_description`);
    if (!isResolvedTranslation(ogDescription, `${keyPrefix}.`)) {
      ogDescription = description;
    }

    this.applyResolvedSeo({
      title: isResolvedTranslation(title, `${keyPrefix}.`) ? title : '',
      description: isResolvedTranslation(description, `${keyPrefix}.`) ? description : '',
      ogDescription: isResolvedTranslation(ogDescription, `${keyPrefix}.`) ? ogDescription : '',
      ogUrl,
      keyPrefix,
      keywords: isResolvedTranslation(keywords, 'meta.default.') ? keywords : undefined
    });
  }

  private applyResolvedSeo(options: {
    title: string;
    description: string;
    ogDescription: string;
    ogUrl: string;
    keyPrefix: string;
    keywords?: string;
  }): void {
    const { title, description, ogDescription, ogUrl, keyPrefix, keywords } = options;

    if (title) {
      this.title.setTitle(title);
    }
    if (description) {
      this.meta.updateTag({ name: 'description', content: description });
    }
    if (keywords) {
      this.meta.updateTag({ name: 'keywords', content: keywords });
    }

    const ogImageUrl = this.readOrigin() ? `${this.readOrigin()}${DEFAULT_OGP_IMAGE_PATH}` : '';
    const ogImageAlt = this.translate.instant('meta.default.og_image_alt');

    if (title) {
      this.meta.updateTag({ property: 'og:title', content: title });
      this.meta.updateTag({ name: 'twitter:title', content: title });
    }
    if (ogDescription) {
      this.meta.updateTag({ property: 'og:description', content: ogDescription });
      this.meta.updateTag({ name: 'twitter:description', content: ogDescription });
    }
    if (ogUrl) {
      this.meta.updateTag({ property: 'og:url', content: ogUrl });
      this.meta.updateTag({ rel: 'canonical', href: ogUrl }, 'rel="canonical"');
    }
    this.refreshHreflangLinks(ogUrl);
    this.meta.updateTag({ property: 'og:type', content: 'website' });
    const angularLang = (this.translate.currentLang || 'ja') as AppLang;
    this.meta.updateTag({ property: 'og:locale', content: ogLocale(angularLang) });
    this.meta.updateTag({ property: 'og:site_name', content: 'AGRR' });
    if (ogImageUrl) {
      this.meta.updateTag({ property: 'og:image', content: ogImageUrl });
      this.meta.updateTag({ name: 'twitter:image', content: ogImageUrl });
      if (isResolvedTranslation(ogImageAlt, 'meta.default.')) {
        this.meta.updateTag({ name: 'twitter:image:alt', content: ogImageAlt });
      }
      this.meta.updateTag({ name: 'twitter:card', content: 'summary_large_image' });
    } else {
      this.meta.removeTag('property="og:image"');
      this.meta.removeTag('name="twitter:image"');
      this.meta.removeTag('name="twitter:image:alt"');
      this.meta.updateTag({ name: 'twitter:card', content: 'summary' });
    }
    if (this.noIndexActive) {
      this.meta.updateTag({ name: 'robots', content: 'noindex' });
    } else {
      this.meta.removeTag('name="robots"');
    }
    this.refreshJsonLd(title, ogDescription, keyPrefix);
  }

  private refreshHreflangLinks(canonicalUrl: string): void {
    if (typeof document === 'undefined') {
      return;
    }
    const path = this.readPathname();
    const origin = this.readOrigin();
    if (!origin) {
      this.clearHreflangLinks();
      return;
    }
    const hreflang = resolveSpaHreflangUrls(origin, path);
    if (!hreflang) {
      this.clearHreflangLinks();
      return;
    }

    this.upsertHreflangLink('ja', hreflang.jaUrl);
    this.upsertHreflangLink('en', hreflang.enUrl);
    this.upsertHreflangLink('x-default', hreflang.jaUrl);
    if (canonicalUrl !== hreflang.canonicalUrl) {
      this.meta.updateTag(
        { rel: 'canonical', href: hreflang.canonicalUrl },
        'rel="canonical"'
      );
      this.meta.updateTag({ property: 'og:url', content: hreflang.canonicalUrl });
    }
  }

  private upsertHreflangLink(hreflang: string, href: string): void {
    const selector = `link[rel="alternate"][hreflang="${hreflang}"]`;
    const existing = document.head.querySelector(selector);
    const link = existing instanceof HTMLLinkElement ? existing : document.createElement('link');
    if (link !== existing) {
      link.rel = 'alternate';
      link.hreflang = hreflang;
      document.head.appendChild(link);
    }
    link.href = href;
  }

  private clearHreflangLinks(): void {
    document.head.querySelectorAll('link[rel="alternate"][hreflang]').forEach((node) => {
      node.remove();
    });
  }

  private refreshJsonLd(siteTitle: string, siteDescription: string, keyPrefix: string): void {
    if (typeof document === 'undefined') {
      return;
    }
    if (
      !isResolvedTranslation(siteTitle, `${keyPrefix}.`) ||
      !isResolvedTranslation(siteDescription, `${keyPrefix}.`)
    ) {
      return;
    }

    const baseUrl =
      typeof window !== 'undefined' && window.location?.origin
        ? window.location.origin
        : 'https://agrr.net';
    const jsonLd = buildSiteStructuredDataDocument({
      baseUrl,
      siteTitle,
      siteDescription
    });

    const script = this.resolveJsonLdScript();
    script.text = jsonLd;
    this.removeDuplicateJsonLdScripts(script);
  }

  private resolveJsonLdScript(): HTMLScriptElement {
    const existing =
      document.getElementById(SITE_STRUCTURED_DATA_SCRIPT_ID) ??
      document.head.querySelector('script[type="application/ld+json"]');
    if (existing instanceof HTMLScriptElement) {
      existing.id = SITE_STRUCTURED_DATA_SCRIPT_ID;
      existing.type = 'application/ld+json';
      return existing;
    }

    const script = document.createElement('script');
    script.id = SITE_STRUCTURED_DATA_SCRIPT_ID;
    script.type = 'application/ld+json';
    document.head.appendChild(script);
    return script;
  }

  private removeDuplicateJsonLdScripts(keep: HTMLScriptElement): void {
    document.head.querySelectorAll('script[type="application/ld+json"]').forEach((node) => {
      if (node !== keep) {
        node.remove();
      }
    });
  }
}
