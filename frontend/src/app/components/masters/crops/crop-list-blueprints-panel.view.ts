import { Crop } from '../../../domain/crops/crop';
import { BlueprintGenerationReadiness } from '../../../domain/crops/blueprint-generation-readiness';
import type { BlueprintDetailSummary } from '../../../domain/crops/blueprint-detail-summary';

export type CropListBlueprintsPanelViewState = {
  loading: boolean;
  error: string | null;
  crop: Crop | null;
  blueprintsLoading: boolean;
  blueprintCount: number;
  blueprintReadiness: BlueprintGenerationReadiness;
  blueprintSummary: BlueprintDetailSummary | null;
};

export interface CropListBlueprintsPanelView {
  get control(): CropListBlueprintsPanelViewState;
  set control(value: CropListBlueprintsPanelViewState);
}
