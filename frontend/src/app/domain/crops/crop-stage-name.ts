import type { Crop } from './crop';

export interface CropStageOrderName {
  order: number;
  name: string;
}

export function stageNameForOrder(
  cropStages: CropStageOrderName[] | undefined,
  stageOrder: number | null
): string | null {
  if (cropStages == null || stageOrder == null) {
    return null;
  }
  return cropStages.find((stage) => stage.order === stageOrder)?.name ?? null;
}

export function cropStageNameForOrder(crop: Crop | null, stageOrder: number | null): string | null {
  if (crop == null || stageOrder == null) {
    return null;
  }
  return stageNameForOrder(crop.crop_stages, stageOrder);
}
