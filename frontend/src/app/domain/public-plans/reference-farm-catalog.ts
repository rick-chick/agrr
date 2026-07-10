/** Coordinate-keyed reference farm slugs for public-plan wizard display. */
export type ReferenceFarmCatalogEntry = {
  coordKey: string;
  slug: string;
  region: string;
  aliases: readonly string[];
};

export const REFERENCE_FARM_CATALOG: readonly ReferenceFarmCatalogEntry[] = [
  { coordKey: '43.0642:141.3469', slug: 'jp_43p0642_141p3469', region: 'jp', aliases: [] },
  { coordKey: '40.8244:140.7400', slug: 'jp_40p8244_140p7400', region: 'jp', aliases: [] },
  { coordKey: '39.7036:141.1527', slug: 'jp_39p7036_141p1527', region: 'jp', aliases: [] },
  { coordKey: '39.7186:140.1028', slug: 'jp_39p7186_140p1028', region: 'jp', aliases: [] },
  { coordKey: '38.2682:140.8720', slug: 'jp_38p2682_140p8720', region: 'jp', aliases: [] },
  { coordKey: '38.2404:140.3633', slug: 'jp_38p2404_140p3633', region: 'jp', aliases: [] },
  { coordKey: '37.9022:139.0233', slug: 'jp_37p9022_139p0233', region: 'jp', aliases: [] },
  { coordKey: '37.7500:140.4673', slug: 'jp_37p7500_140p4673', region: 'jp', aliases: [] },
  { coordKey: '36.6959:137.2137', slug: 'jp_36p6959_137p2137', region: 'jp', aliases: [] },
  { coordKey: '36.6513:138.1811', slug: 'jp_36p6513_138p1811', region: 'jp', aliases: [] },
  { coordKey: '36.5946:136.6256', slug: 'jp_36p5946_136p6256', region: 'jp', aliases: [] },
  { coordKey: '36.5658:139.8836', slug: 'jp_36p5658_139p8836', region: 'jp', aliases: [] },
  { coordKey: '36.3911:139.0608', slug: 'jp_36p3911_139p0608', region: 'jp', aliases: [] },
  { coordKey: '36.3414:140.4467', slug: 'jp_36p3414_140p4467', region: 'jp', aliases: [] },
  { coordKey: '36.0652:136.2216', slug: 'jp_36p0652_136p2216', region: 'jp', aliases: [] },
  { coordKey: '35.8569:139.6489', slug: 'jp_35p8569_139p6489', region: 'jp', aliases: [] },
  { coordKey: '35.6762:139.6503', slug: 'jp_35p6762_139p6503', region: 'jp', aliases: [] },
  { coordKey: '35.6636:138.5684', slug: 'jp_35p6636_138p5684', region: 'jp', aliases: [] },
  { coordKey: '35.6074:140.1061', slug: 'jp_35p6074_140p1061', region: 'jp', aliases: [] },
  { coordKey: '35.5014:134.2350', slug: 'jp_35p5014_134p2350', region: 'jp', aliases: [] },
  { coordKey: '35.4723:133.0505', slug: 'jp_35p4723_133p0505', region: 'jp', aliases: [] },
  { coordKey: '35.4478:139.6425', slug: 'jp_35p4478_139p6425', region: 'jp', aliases: [] },
  { coordKey: '35.3912:136.7223', slug: 'jp_35p3912_136p7223', region: 'jp', aliases: [] },
  { coordKey: '35.1815:136.9066', slug: 'jp_35p1815_136p9066', region: 'jp', aliases: [] },
  { coordKey: '35.0116:135.7681', slug: 'jp_35p0116_135p7681', region: 'jp', aliases: [] },
  { coordKey: '35.0045:135.8686', slug: 'jp_35p0045_135p8686', region: 'jp', aliases: [] },
  { coordKey: '34.9769:138.3831', slug: 'jp_34p9769_138p3831', region: 'jp', aliases: [] },
  { coordKey: '34.7303:136.5086', slug: 'jp_34p7303_136p5086', region: 'jp', aliases: [] },
  { coordKey: '34.6937:135.5023', slug: 'jp_34p6937_135p5023', region: 'jp', aliases: [] },
  { coordKey: '34.6901:135.1955', slug: 'jp_34p6901_135p1955', region: 'jp', aliases: [] },
  { coordKey: '34.6851:135.8329', slug: 'jp_34p6851_135p8329', region: 'jp', aliases: [] },
  { coordKey: '34.6617:133.9350', slug: 'jp_34p6617_133p9350', region: 'jp', aliases: [] },
  { coordKey: '34.3963:132.4596', slug: 'jp_34p3963_132p4596', region: 'jp', aliases: [] },
  { coordKey: '34.2261:135.1675', slug: 'jp_34p2261_135p1675', region: 'jp', aliases: [] },
  { coordKey: '34.1858:131.4706', slug: 'jp_34p1858_131p4706', region: 'jp', aliases: [] },
  { coordKey: '34.0658:134.5594', slug: 'jp_34p0658_134p5594', region: 'jp', aliases: [] },
  { coordKey: '34.3401:134.0434', slug: 'jp_34p3401_134p0434', region: 'jp', aliases: [] },
  { coordKey: '33.8416:132.7657', slug: 'jp_33p8416_132p7657', region: 'jp', aliases: [] },
  { coordKey: '33.5904:130.4017', slug: 'jp_33p5904_130p4017', region: 'jp', aliases: [] },
  { coordKey: '33.5597:133.5311', slug: 'jp_33p5597_133p5311', region: 'jp', aliases: [] },
  { coordKey: '33.2494:130.2989', slug: 'jp_33p2494_130p2989', region: 'jp', aliases: [] },
  { coordKey: '33.2382:131.6126', slug: 'jp_33p2382_131p6126', region: 'jp', aliases: [] },
  { coordKey: '32.7898:130.7417', slug: 'jp_32p7898_130p7417', region: 'jp', aliases: [] },
  { coordKey: '32.7503:129.8779', slug: 'jp_32p7503_129p8779', region: 'jp', aliases: [] },
  { coordKey: '31.9077:131.4202', slug: 'jp_31p9077_131p4202', region: 'jp', aliases: [] },
  { coordKey: '31.5966:130.5571', slug: 'jp_31p5966_130p5571', region: 'jp', aliases: [] },
  { coordKey: '26.2124:127.6809', slug: 'jp_26p2124_127p6809', region: 'jp', aliases: [] },
  { coordKey: '30.9010:75.8573', slug: 'in_30p9010_75p8573', region: 'in', aliases: ["Punjab"] },
  { coordKey: '31.6340:74.8723', slug: 'in_31p6340_74p8723', region: 'in', aliases: [] },
  { coordKey: '31.3260:75.5762', slug: 'in_31p3260_75p5762', region: 'in', aliases: [] },
  { coordKey: '29.6857:76.9905', slug: 'in_29p6857_76p9905', region: 'in', aliases: [] },
  { coordKey: '29.1492:75.7217', slug: 'in_29p1492_75p7217', region: 'in', aliases: [] },
  { coordKey: '28.8955:76.6066', slug: 'in_28p8955_76p6066', region: 'in', aliases: [] },
  { coordKey: '29.0176:77.7065', slug: 'in_29p0176_77p7065', region: 'in', aliases: [] },
  { coordKey: '26.8467:80.9462', slug: 'in_26p8467_80p9462', region: 'in', aliases: [] },
  { coordKey: '26.4499:80.3319', slug: 'in_26p4499_80p3319', region: 'in', aliases: [] },
  { coordKey: '26.7606:83.3732', slug: 'in_26p7606_83p3732', region: 'in', aliases: [] },
  { coordKey: '25.3176:82.9739', slug: 'in_25p3176_82p9739', region: 'in', aliases: [] },
  { coordKey: '25.5941:85.1376', slug: 'in_25p5941_85p1376', region: 'in', aliases: [] },
  { coordKey: '26.1225:85.3906', slug: 'in_26p1225_85p3906', region: 'in', aliases: [] },
  { coordKey: '22.5726:88.3639', slug: 'in_22p5726_88p3639', region: 'in', aliases: [] },
  { coordKey: '23.2324:87.8615', slug: 'in_23p2324_87p8615', region: 'in', aliases: [] },
  { coordKey: '20.2961:85.8245', slug: 'in_20p2961_85p8245', region: 'in', aliases: [] },
  { coordKey: '20.4625:85.8830', slug: 'in_20p4625_85p8830', region: 'in', aliases: [] },
  { coordKey: '26.1445:91.7362', slug: 'in_26p1445_91p7362', region: 'in', aliases: [] },
  { coordKey: '21.2514:81.6296', slug: 'in_21p2514_81p6296', region: 'in', aliases: [] },
  { coordKey: '21.1458:79.0882', slug: 'in_21p1458_79p0882', region: 'in', aliases: [] },
  { coordKey: '19.9975:73.7898', slug: 'in_19p9975_73p7898', region: 'in', aliases: [] },
  { coordKey: '19.8762:75.3433', slug: 'in_19p8762_75p3433', region: 'in', aliases: [] },
  { coordKey: '19.0948:74.7480', slug: 'in_19p0948_74p7480', region: 'in', aliases: [] },
  { coordKey: '23.0225:72.5714', slug: 'in_23p0225_72p5714', region: 'in', aliases: [] },
  { coordKey: '21.1702:72.8311', slug: 'in_21p1702_72p8311', region: 'in', aliases: [] },
  { coordKey: '22.3039:70.8022', slug: 'in_22p3039_70p8022', region: 'in', aliases: [] },
  { coordKey: '22.3072:73.1812', slug: 'in_22p3072_73p1812', region: 'in', aliases: [] },
  { coordKey: '26.9124:75.7873', slug: 'in_26p9124_75p7873', region: 'in', aliases: [] },
  { coordKey: '26.2389:73.0243', slug: 'in_26p2389_73p0243', region: 'in', aliases: [] },
  { coordKey: '25.2138:75.8648', slug: 'in_25p2138_75p8648', region: 'in', aliases: [] },
  { coordKey: '22.7196:75.8577', slug: 'in_22p7196_75p8577', region: 'in', aliases: [] },
  { coordKey: '23.2599:77.4126', slug: 'in_23p2599_77p4126', region: 'in', aliases: [] },
  { coordKey: '23.1815:79.9864', slug: 'in_23p1815_79p9864', region: 'in', aliases: [] },
  { coordKey: '26.2183:78.1828', slug: 'in_26p2183_78p1828', region: 'in', aliases: [] },
  { coordKey: '17.3850:78.4867', slug: 'in_17p3850_78p4867', region: 'in', aliases: [] },
  { coordKey: '17.9784:79.6005', slug: 'in_17p9784_79p6005', region: 'in', aliases: [] },
  { coordKey: '16.5062:80.6480', slug: 'in_16p5062_80p6480', region: 'in', aliases: [] },
  { coordKey: '17.6868:83.2185', slug: 'in_17p6868_83p2185', region: 'in', aliases: [] },
  { coordKey: '16.3067:80.4365', slug: 'in_16p3067_80p4365', region: 'in', aliases: [] },
  { coordKey: '12.9716:77.5946', slug: 'in_12p9716_77p5946', region: 'in', aliases: [] },
  { coordKey: '12.2958:76.6394', slug: 'in_12p2958_76p6394', region: 'in', aliases: [] },
  { coordKey: '12.9141:74.8560', slug: 'in_12p9141_74p8560', region: 'in', aliases: [] },
  { coordKey: '15.3647:75.1240', slug: 'in_15p3647_75p1240', region: 'in', aliases: [] },
  { coordKey: '13.0827:80.2707', slug: 'in_13p0827_80p2707', region: 'in', aliases: [] },
  { coordKey: '9.9252:78.1198', slug: 'in_9p9252_78p1198', region: 'in', aliases: [] },
  { coordKey: '11.0168:76.9558', slug: 'in_11p0168_76p9558', region: 'in', aliases: [] },
  { coordKey: '10.7905:78.7047', slug: 'in_10p7905_78p7047', region: 'in', aliases: [] },
  { coordKey: '11.6643:78.1460', slug: 'in_11p6643_78p1460', region: 'in', aliases: [] },
  { coordKey: '9.9312:76.2673', slug: 'in_9p9312_76p2673', region: 'in', aliases: [] },
] as const;

const COORD_TO_SLUG = new Map<string, string>(
  REFERENCE_FARM_CATALOG.map((entry) => [entry.coordKey, entry.slug])
);

const ALIAS_TO_SLUG = new Map<string, string>();
for (const entry of REFERENCE_FARM_CATALOG) {
  for (const alias of entry.aliases) {
    ALIAS_TO_SLUG.set(`${entry.region}:${alias}`, entry.slug);
  }
}

export function referenceFarmCoordKey(latitude: number, longitude: number): string {
  return `${latitude.toFixed(4)}:${longitude.toFixed(4)}`;
}

export function resolveReferenceFarmSlug(
  farm: { name: string; latitude: number; longitude: number; region?: string | null }
): string | undefined {
  const coordKey = referenceFarmCoordKey(farm.latitude, farm.longitude);
  const byCoord = COORD_TO_SLUG.get(coordKey);
  if (byCoord) return byCoord;
  if (farm.region) {
    return ALIAS_TO_SLUG.get(`${farm.region}:${farm.name}`);
  }
  return undefined;
}
