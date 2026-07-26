import { TestBed } from '@angular/core/testing';
import { Meta, Title } from '@angular/platform-browser';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import { AppSeoMetaService } from './app-seo-meta.service';

describe('AppSeoMetaService', () => {
  let service: AppSeoMetaService;
  let title: Title;
  let meta: Meta;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [TranslateModule.forRoot()],
      providers: [AppSeoMetaService]
    });
    service = TestBed.inject(AppSeoMetaService);
    title = TestBed.inject(Title);
    meta = TestBed.inject(Meta);
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'ja',
      {
        meta: {
          default: {
            title: 'AGRR タイトル',
            description: '説明文',
            keywords: '農業,計画',
            og_description: 'OG説明'
          }
        }
      },
      true
    );
    translate.use('ja');
  });

  it('sets document title and description from default meta keys', () => {
    service.refreshDefaultMeta();
    expect(title.getTitle()).toBe('AGRR タイトル');
    expect(meta.getTag('name="description"')?.content).toBe('説明文');
  });

  it('skips JSON-LD injection when document is unavailable (SSR/prerender)', () => {
    const doc = globalThis.document;
    Object.defineProperty(globalThis, 'document', { value: undefined, configurable: true });
    try {
      expect(() => service.refreshDefaultMeta()).not.toThrow();
    } finally {
      Object.defineProperty(globalThis, 'document', { value: doc, configurable: true });
    }
  });

  it('injects Organization JSON-LD on refreshDefaultMeta', () => {
    service.refreshDefaultMeta();
    const script = document.head.querySelector('script[type="application/ld+json"]');
    expect(script).not.toBeNull();
    const structured = JSON.parse(script?.textContent ?? '{}');
    const graph = structured['@graph'] as Array<Record<string, unknown>>;
    const organization = graph.find((node) => node['@type'] === 'Organization');
    expect(organization).toMatchObject({
      name: 'AGRR',
      email: 'support@agrr.net'
    });
  });
});
