import { Crop } from '../crops/crop';

/** research_reports/{slug}/.../gdd_requirements と参照作物名の対応 */
export const RESEARCH_CROP_SLUG_NAMES: Readonly<Record<string, readonly string[]>> = {
  tomato: ['トマト', 'Tomato'],
  potato: ['じゃがいも', 'Potato'],
  bell_pepper: ['ピーマン', 'Bell Pepper'],
  eggplant: ['ナス', 'Eggplant'],
  cucumber: ['キュウリ', 'Cucumber'],
  pumpkin: ['かぼちゃ', 'Pumpkin'],
  carrot: ['人参', 'Carrot'],
  radish: ['大根', 'Radish'],
  onion: ['玉ねぎ', 'Onion'],
  cabbage: ['キャベツ', 'Cabbage'],
  broccoli: ['ブロッコリー', 'Broccoli'],
  chinese_cabbage: ['白菜', 'Chinese Cabbage'],
  lettuce: ['レタス', 'Lettuce'],
  spinach: ['ほうれん草', 'Spinach'],
  corn: ['トウモロコシ', 'Corn']
};

export function findCropByResearchSlug(crops: Crop[], slug: string): Crop | undefined {
  const aliases = RESEARCH_CROP_SLUG_NAMES[slug];
  if (!aliases?.length) {
    return undefined;
  }
  const normalizedAliases = aliases.map((name) => name.toLowerCase());
  return crops.find((crop) => {
    const cropName = crop.name.trim().toLowerCase();
    return normalizedAliases.some(
      (alias) => cropName === alias || cropName.includes(alias)
    );
  });
}
