import { Injectable, inject } from '@angular/core';
import { Meta, Title } from '@angular/platform-browser';
import { TranslateService } from '@ngx-translate/core';
import type { AppLang } from '../app-locale';

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

@Injectable({ providedIn: 'root' })
export class AppSeoMetaService {
  private readonly translate = inject(TranslateService);
  private readonly title = inject(Title);
  private readonly meta = inject(Meta);

  refreshDefaultMeta(): void {
    const angularLang = (this.translate.currentLang || 'ja') as AppLang;
    if (typeof document !== 'undefined') {
      document.documentElement.lang = documentHtmlLang(angularLang);
    }

    const title = this.translate.instant('meta.default.title');
    const description = this.translate.instant('meta.default.description');
    const keywords = this.translate.instant('meta.default.keywords');
    let ogDescription = this.translate.instant('meta.default.og_description');
    if (!isResolvedTranslation(ogDescription, 'meta.default.')) {
      ogDescription = description;
    }

    if (isResolvedTranslation(title, 'meta.default.')) {
      this.title.setTitle(title);
    }
    if (isResolvedTranslation(description, 'meta.default.')) {
      this.meta.updateTag({ name: 'description', content: description });
    }
    if (isResolvedTranslation(keywords, 'meta.default.')) {
      this.meta.updateTag({ name: 'keywords', content: keywords });
    }

    const origin = typeof window !== 'undefined' ? window.location.origin : '';
    const path = typeof window !== 'undefined' ? window.location.pathname : '/';
    const ogUrl = origin ? `${origin}${path.split('?')[0]}` : '';

    this.meta.removeTag('property="og:image"');
    this.meta.removeTag('name="twitter:image"');
    this.meta.removeTag('name="twitter:image:alt"');

    if (isResolvedTranslation(title, 'meta.default.')) {
      this.meta.updateTag({ property: 'og:title', content: title });
      this.meta.updateTag({ name: 'twitter:title', content: title });
    }
    if (isResolvedTranslation(ogDescription, 'meta.default.')) {
      this.meta.updateTag({ property: 'og:description', content: ogDescription });
      this.meta.updateTag({ name: 'twitter:description', content: ogDescription });
    }
    if (ogUrl) {
      this.meta.updateTag({ property: 'og:url', content: ogUrl });
    }
    this.meta.updateTag({ property: 'og:type', content: 'website' });
    this.meta.updateTag({ property: 'og:locale', content: ogLocale(angularLang) });
    this.meta.updateTag({ property: 'og:site_name', content: 'AGRR' });
    this.meta.updateTag({ name: 'twitter:card', content: 'summary' });
  }
}
