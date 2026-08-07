import { Injectable, inject, PLATFORM_ID, REQUEST } from '@angular/core';
import { DOCUMENT, isPlatformServer } from '@angular/common';
import { Meta, Title } from '@angular/platform-browser';
import { Router } from '@angular/router';
import { TranslateService } from '@ngx-translate/core';
import type { AppLang } from '../app-locale';
import type { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { resolveSeoKeyPrefix } from './route-seo-meta.config';
import { buildSiteStructuredDataDocumentWithOptionalFaq, SITE_STRUCTURED_DATA_SCRIPT_ID, type ContactFaqItem } from './site-structured-data';
import {
  buildPublicPlanResultsShareUrl,
  extractPublicPlanResultsSeoLabels
} from './public-plan-results-seo-meta';
import {
  buildEntryScheduleDetailCanonicalUrl,
  buildEntryScheduleDetailSeoLabels
} from './entry-schedule-detail-seo-meta';
import { PRODUCTION_SITE_ORIGIN } from './seo-site-origin';
import { resolveRouteSeoMetaWithTranslator } from './resolve-route-seo-meta';
import { buildSelfCanonicalUrl, DEFAULT_OGP_IMAGE_PATH } from './seo-url';

function documentHtmlLang(angularLang: AppLang): string {
  return angularLang === 'in' ? 'hi' : angularLang;
}

function ogLocale(angularLang: AppLang): string {
  if (angularLang === 'ja') return 'ja_JP';
  if (angularLang === 'en') return 'en_US';
  return 'hi_IN';
}

function isResolvedTranslation(value: string, keyPrefix: string): boolean {
  return Boolean(value) && !value.startsWith(keyPrefix);
}

/** Default OGP image served from `frontend/public/` (1200×630). */
export { DEFAULT_OGP_IMAGE_PATH, buildSelfCanonicalUrl } from './seo-url';

@Injectable({ providedIn: 'root' })
export class AppSeoMetaService {
  private readonly translate = inject(TranslateService);
  private readonly title = inject(Title);
  private readonly meta = inject(Meta);
  private readonly document = inject(DOCUMENT);
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
    const keyPrefix = resolveSeoKeyPrefix(path);
    this.applySeoFromKeyPrefix(keyPrefix, buildSelfCanonicalUrl(this.readOrigin(), path));
  }

  refreshEntryScheduleDetailMeta(cropId: number | null, cropName: string | null): void {
    const angularLang = (this.translate.currentLang || 'ja') as AppLang;
    if (typeof document !== 'undefined') {
      document.documentElement.lang = documentHtmlLang(angularLang);
    }

    if (!cropId || !cropName?.trim()) {
      const path = this.readPathname();
      const keyPrefix = path.startsWith('/entry-schedule/crop/')
        ? 'pages.entry_schedule'
        : resolveSeoKeyPrefix(path);
      this.applySeoFromKeyPrefix(keyPrefix, buildSelfCanonicalUrl(this.readOrigin(), path));
      return;
    }

    const labels = buildEntryScheduleDetailSeoLabels(cropName);
    const params = { cropName: labels.cropName };
    const keyPrefix = 'pages.entry_schedule_detail';
    const title = this.translate.instant(`${keyPrefix}.title`, params);
    const description = this.translate.instant(`${keyPrefix}.description`, params);
    let ogDescription = this.translate.instant(`${keyPrefix}.og_description`, params);
    if (!isResolvedTranslation(ogDescription, `${keyPrefix}.`)) {
      ogDescription = description;
    }

    const ogUrl = buildEntryScheduleDetailCanonicalUrl(this.readOrigin(), cropId);
    this.applyResolvedSeo({ title, description, ogDescription, ogUrl, keyPrefix });
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
      return PRODUCTION_SITE_ORIGIN;
    }
    const requestUrl = this.readRequestUrl();
    if (requestUrl) {
      try {
        return new URL(requestUrl).origin;
      } catch {
        return PRODUCTION_SITE_ORIGIN;
      }
    }
    return PRODUCTION_SITE_ORIGIN;
  }

  private readRequestUrl(): string | undefined {
    const request = this.request as Request | null | undefined;
    return request?.url;
  }

  private updateCanonicalLink(href: string): void {
    if (typeof this.document === 'undefined' || !this.document.head) {
      return;
    }

    let link = this.document.head.querySelector('link[rel="canonical"]');
    if (!(link instanceof HTMLLinkElement)) {
      link = this.document.createElement('link');
      link.setAttribute('rel', 'canonical');
      this.document.head.appendChild(link);
    }
    link.setAttribute('href', href);
  }

  private applySeoFromKeyPrefix(keyPrefix: string, ogUrl: string): void {
    const path = this.readPathname();
    const origin = this.readOrigin() || PRODUCTION_SITE_ORIGIN;
    const resolved = resolveRouteSeoMetaWithTranslator(
      path,
      (key) => this.translate.instant(key),
      origin
    );
    const keywords = this.translate.instant('meta.default.keywords');

    this.applyResolvedSeo({
      title: resolved.title,
      description: resolved.description,
      ogDescription: resolved.ogDescription,
      ogUrl: resolved.canonicalUrl || ogUrl,
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
      this.updateCanonicalLink(ogUrl);
    }
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
        : PRODUCTION_SITE_ORIGIN;
    const faqItems = this.resolveContactFaqItems(keyPrefix);
    const jsonLd = buildSiteStructuredDataDocumentWithOptionalFaq(
      {
        baseUrl,
        siteTitle,
        siteDescription
      },
      faqItems
    );

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

  private resolveContactFaqItems(keyPrefix: string): ContactFaqItem[] | undefined {
    if (keyPrefix !== 'pages.contact') {
      return undefined;
    }

    const raw = this.translate.instant('pages.contact.faq_items');
    if (!Array.isArray(raw)) {
      return undefined;
    }

    const faqItems = raw
      .map((item) => {
        if (item == null || typeof item !== 'object') {
          return null;
        }
        const question = (item as { question?: unknown }).question;
        const answer = (item as { answer?: unknown }).answer;
        if (typeof question !== 'string' || typeof answer !== 'string') {
          return null;
        }
        if (!question.trim() || !answer.trim()) {
          return null;
        }
        return { question, answer };
      })
      .filter((item): item is ContactFaqItem => item !== null);

    return faqItems.length ? faqItems : undefined;
  }
}
