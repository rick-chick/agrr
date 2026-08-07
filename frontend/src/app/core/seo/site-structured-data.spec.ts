import { describe, expect, it } from 'vitest';

import {
  buildContactFaqPageStructuredDataNode,
  buildSiteStructuredDataGraph
} from './site-structured-data';

describe('buildSiteStructuredDataGraph', () => {
  it('includes Organization with email and sameAs', () => {
    const graph = buildSiteStructuredDataGraph({
      baseUrl: 'https://agrr.net',
      siteTitle: 'AGRR（Agriculture Resource and Rotation planner）- 農業計画支援システム',
      siteDescription: '気象データとAIを活用した農業作付け計画支援システム'
    });

    const organization = graph.find((node) => node['@type'] === 'Organization');
    expect(organization).toMatchObject({
      '@id': 'https://agrr.net/#organization',
      name: 'AGRR',
      url: 'https://agrr.net/',
      email: 'support@agrr.net',
      sameAs: ['https://github.com/rick-chick/agrr']
    });
  });

  it('links WebSite.publisher to Organization and unifies brand names', () => {
    const graph = buildSiteStructuredDataGraph({
      baseUrl: 'https://agrr.net',
      siteTitle: 'AGRR（Agriculture Resource and Rotation planner）- 農業計画支援システム',
      siteDescription: '気象データとAIを活用した農業作付け計画支援システム'
    });

    const website = graph.find((node) => node['@type'] === 'WebSite');
    const software = graph.find((node) => node['@type'] === 'SoftwareApplication');

    expect(website).toMatchObject({
      name: 'AGRR',
      alternateName:
        'AGRR（Agriculture Resource and Rotation planner）- 農業計画支援システム',
      publisher: { '@id': 'https://agrr.net/#organization' }
    });
    expect(software).toMatchObject({
      name: 'AGRR',
      alternateName:
        'AGRR（Agriculture Resource and Rotation planner）- 農業計画支援システム'
    });
  });

  it('includes FAQPage when faqItems are provided', () => {
    const graph = buildSiteStructuredDataGraph({
      baseUrl: 'https://agrr.net',
      siteTitle: 'お問い合わせ',
      siteDescription: 'AGRRへのお問い合わせ',
      pageUrl: 'https://agrr.net/contact',
      faqItems: [
        { question: 'ログインできない', answer: 'Google認証の設定をご確認ください' },
        { question: 'データが保存されない', answer: 'ブラウザのCookieが有効かご確認ください' }
      ]
    });

    const faqPage = graph.find((node) => node['@type'] === 'FAQPage');
    expect(faqPage).toMatchObject({
      '@id': 'https://agrr.net/contact#faq',
      mainEntity: [
        {
          '@type': 'Question',
          name: 'ログインできない',
          acceptedAnswer: { '@type': 'Answer', text: 'Google認証の設定をご確認ください' }
        },
        {
          '@type': 'Question',
          name: 'データが保存されない',
          acceptedAnswer: { '@type': 'Answer', text: 'ブラウザのCookieが有効かご確認ください' }
        }
      ]
    });
  });
});

describe('buildContactFaqPageStructuredDataNode', () => {
  it('builds FAQPage with Question and Answer entities', () => {
    const node = buildContactFaqPageStructuredDataNode(
      [{ question: 'Cannot log in', answer: 'Check Google auth settings' }],
      'https://agrr.net/en/contact'
    );

    expect(node).toMatchObject({
      '@type': 'FAQPage',
      '@id': 'https://agrr.net/en/contact#faq',
      mainEntity: [
        {
          '@type': 'Question',
          name: 'Cannot log in',
          acceptedAnswer: { '@type': 'Answer', text: 'Check Google auth settings' }
        }
      ]
    });
  });
});
