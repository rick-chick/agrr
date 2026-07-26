import { Injectable, inject } from '@angular/core';
import { Meta, Title } from '@angular/platform-browser';
import { TranslateService } from '@ngx-translate/core';
import type { AppLang } from '../app-locale';
import { resolveSeoKeyPrefix } from './route-seo-meta.config';
import { buildSiteStructuredDataDocument } from './site-structured-data';

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

function ogLocale(angularLang: AppLang): string {
  if (angularLang === 'ja') return 'ja_JP';
  if (angularLang === 'en') return 'en_US';
  return 'hi_IN';
}

function isResolvedTranslation(value: string, keyPrefix: string): boolean {
  return Boolean(value) && !value.startsWith(keyPrefix);
}

@Injectable({ providedIn: 'root' })
export class AppSeoMetaService {
  private readonly translate = inject(TranslateService);
  private readonly title = inject(Title);
  private readonly meta = inject(Meta);
  private jsonLdScript: HTMLScriptElement | null = null;

  refreshDefaultMeta(): void {
    const angularLang = (this.translate.currentLang || 'ja') as AppLang;
    if (typeof document !== 'undefined') {
      document.documentElement.lang = documentHtmlLang(angularLang);
    }

    const path = typeof window !== 'undefined' ? (window.location?.pathname ?? '/') : '/';
    const keyPrefix = resolveSeoKeyPrefix(path);

    const title = this.translate.instant(`${keyPrefix}.title`);
    const description = this.translate.instant(`${keyPrefix}.description`);
    const keywords = this.translate.instant('meta.default.keywords');
    let ogDescription = this.translate.instant(`${keyPrefix}.og_description`);
    if (!isResolvedTranslation(ogDescription, `${keyPrefix}.`)) {
      ogDescription = description;
    }

    if (isResolvedTranslation(title, `${keyPrefix}.`)) {
      this.title.setTitle(title);
    }
    if (isResolvedTranslation(description, `${keyPrefix}.`)) {
      this.meta.updateTag({ name: 'description', content: description });
    }
    if (isResolvedTranslation(keywords, 'meta.default.')) {
      this.meta.updateTag({ name: 'keywords', content: keywords });
    }

    const origin = typeof window !== 'undefined' ? window.location.origin : '';
    const ogUrl = buildSelfCanonicalUrl(origin, path);

    this.meta.removeTag('property="og:image"');
    this.meta.removeTag('name="twitter:image"');
    this.meta.removeTag('name="twitter:image:alt"');

    if (isResolvedTranslation(title, `${keyPrefix}.`)) {
      this.meta.updateTag({ property: 'og:title', content: title });
      this.meta.updateTag({ name: 'twitter:title', content: title });
    }
    if (isResolvedTranslation(ogDescription, `${keyPrefix}.`)) {
      this.meta.updateTag({ property: 'og:description', content: ogDescription });
      this.meta.updateTag({ name: 'twitter:description', content: ogDescription });
    }
    if (ogUrl) {
      this.meta.updateTag({ property: 'og:url', content: ogUrl });
      this.meta.updateTag({ rel: 'canonical', href: ogUrl });
    }
    this.meta.updateTag({ property: 'og:type', content: 'website' });
    this.meta.updateTag({ property: 'og:locale', content: ogLocale(angularLang) });
    this.meta.updateTag({ property: 'og:site_name', content: 'AGRR' });
    this.meta.updateTag({ name: 'twitter:card', content: 'summary' });
    this.refreshJsonLd(title, ogDescription, keyPrefix);
  }

  private refreshJsonLd(siteTitle: string, siteDescription: string, keyPrefix: string): void {
    if (typeof document === 'undefined') {
      return;
    }
    this.detachJsonLd();
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
    const script = document.createElement('script');
    script.type = 'application/ld+json';
    script.text = buildSiteStructuredDataDocument({
      baseUrl,
      siteTitle,
      siteDescription
    });
    document.head.appendChild(script);
    this.jsonLdScript = script;
  }

  private detachJsonLd(): void {
    if (typeof document === 'undefined') {
      return;
    }
    if (this.jsonLdScript?.parentNode) {
      this.jsonLdScript.parentNode.removeChild(this.jsonLdScript);
    }
    this.jsonLdScript = null;
  }
}
