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

  it('injects Organization JSON-LD with WebSite.publisher reference', () => {
    service.refreshDefaultMeta();

    const script = document.head.querySelector(
      'script[type="application/ld+json"]'
    ) as HTMLScriptElement | null;
    expect(script).not.toBeNull();

    const structured = JSON.parse(script?.text ?? '{}') as {
      '@graph': Array<Record<string, unknown>>;
    };
    const organization = structured['@graph'].find(
      (node) => node['@type'] === 'Organization'
    );
    const website = structured['@graph'].find((node) => node['@type'] === 'WebSite');

    expect(organization).toMatchObject({
      name: 'AGRR',
      email: 'support@agrr.net',
      sameAs: ['https://github.com/rick-chick/agrr']
    });
    expect(website).toMatchObject({
      name: 'AGRR',
      alternateName: 'Agriculture Resource and Rotation planner',
      publisher: { '@id': 'https://agrr.net/#organization' }
    });
  });
});
