import { describe, expect, it } from 'vitest';

import { buildAgrrJsonLdGraph, AGRR_ORGANIZATION_ID } from './site-json-ld';

describe('buildAgrrJsonLdGraph', () => {
  it('includes Organization with email and sameAs', () => {
    const graph = buildAgrrJsonLdGraph({
      baseUrl: 'https://agrr.net',
      siteDescription: 'Agricultural planning support'
    });

    const organization = graph.find((node) => node['@type'] === 'Organization');
    expect(organization).toMatchObject({
      '@id': AGRR_ORGANIZATION_ID,
      name: 'AGRR',
      url: 'https://agrr.net/',
      email: 'support@agrr.net',
      sameAs: ['https://github.com/rick-chick/agrr']
    });
  });

  it('links WebSite.publisher to Organization and unifies brand names', () => {
    const graph = buildAgrrJsonLdGraph({
      baseUrl: 'https://agrr.net',
      siteDescription: 'Agricultural planning support'
    });

    const website = graph.find((node) => node['@type'] === 'WebSite');
    const software = graph.find((node) => node['@type'] === 'SoftwareApplication');

    expect(website).toMatchObject({
      name: 'AGRR',
      alternateName: 'Agriculture Resource and Rotation planner',
      publisher: { '@id': AGRR_ORGANIZATION_ID }
    });
    expect(software).toMatchObject({
      name: 'AGRR',
      alternateName: 'Agriculture Resource and Rotation planner'
    });
  });
});
