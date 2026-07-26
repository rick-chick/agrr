export const AGRR_ORGANIZATION_ID = 'https://agrr.net/#organization';
export const AGRR_WEBSITE_ID = 'https://agrr.net/#website';
export const AGRR_BRAND_NAME = 'AGRR';
export const AGRR_ALTERNATE_NAME = 'Agriculture Resource and Rotation planner';
export const AGRR_SUPPORT_EMAIL = 'support@agrr.net';
export const AGRR_SAME_AS = ['https://github.com/rick-chick/agrr'] as const;

export type JsonLdNode = Record<string, unknown>;

export interface AgrrJsonLdInput {
  baseUrl: string;
  siteDescription: string;
}

function normalizeBaseUrl(baseUrl: string): string {
  return baseUrl.endsWith('/') ? baseUrl : `${baseUrl}/`;
}

export function buildAgrrJsonLdGraph(input: AgrrJsonLdInput): JsonLdNode[] {
  const baseUrl = normalizeBaseUrl(input.baseUrl);

  return [
    {
      '@type': 'Organization',
      '@id': AGRR_ORGANIZATION_ID,
      name: AGRR_BRAND_NAME,
      url: baseUrl,
      email: AGRR_SUPPORT_EMAIL,
      sameAs: [...AGRR_SAME_AS]
    },
    {
      '@type': 'WebSite',
      '@id': AGRR_WEBSITE_ID,
      name: AGRR_BRAND_NAME,
      alternateName: AGRR_ALTERNATE_NAME,
      url: baseUrl,
      description: input.siteDescription,
      publisher: { '@id': AGRR_ORGANIZATION_ID }
    },
    {
      '@type': 'SoftwareApplication',
      name: AGRR_BRAND_NAME,
      alternateName: AGRR_ALTERNATE_NAME,
      applicationCategory: 'BusinessApplication',
      operatingSystem: 'Web',
      url: baseUrl,
      description: input.siteDescription
    }
  ];
}

export function buildAgrrJsonLdDocument(input: AgrrJsonLdInput): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@graph': buildAgrrJsonLdGraph(input)
  };
}
