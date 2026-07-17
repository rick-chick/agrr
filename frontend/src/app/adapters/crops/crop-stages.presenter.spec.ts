import { TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { CropStagesPresenter } from './crop-stages.presenter';
import { CropStagesView, CropStagesViewState } from '../../components/masters/crops/crop-stages.view';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';
import { LoadCropTaskScheduleBlueprintsDataDto } from '../../usecase/crops/crop-task-schedule-blueprint.ports';
import { CreateCropStageOutputDto } from '../../usecase/crops/create-crop-stage.dtos';
import { CropStage } from '../../domain/crops/crop';
import { defaultBlueprintReadiness } from '../../domain/crops/blueprint-generation-readiness';

describe('CropStagesPresenter', () => {
  let presenter: CropStagesPresenter;
  let view: CropStagesView;
  let lastControl: CropStagesViewState | null;
  let reloadTaskScheduleBlueprintsSpy: ReturnType<typeof vi.fn>;

  const emptyFormData: CropStagesViewState['formData'] = {
    name: '',
    is_reference: false,
    crop_stages: []
  };

  const baseControlState = (
    formData: Partial<CropStagesViewState['formData']> = emptyFormData
  ): CropStagesViewState => ({
    loading: false,
    error: null,
    pendingErrorFlash: null,
    pendingSuccessFlash: null,
    pendingReorderCropStagesSnapshot: null,
    pendingResyncPanelDraft: false,
    taskScheduleBlueprints: [],
    blueprintReadiness: defaultBlueprintReadiness(),
    stageRequirementGaps: [],
    showBlueprintReadinessChecklist: false,
    showNextStepCta: false,
    formData: { ...emptyFormData, ...formData }
  });

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CropStagesPresenter]
    });
    presenter = TestBed.inject(CropStagesPresenter);
    lastControl = null;
    reloadTaskScheduleBlueprintsSpy = vi.fn();
    view = {
      get control(): CropStagesViewState {
        return lastControl ?? {
          loading: true,
          error: null,
          pendingErrorFlash: null,
          pendingSuccessFlash: null,
          pendingReorderCropStagesSnapshot: null,
          pendingResyncPanelDraft: false,
          taskScheduleBlueprints: [],
          blueprintReadiness: defaultBlueprintReadiness(),
          stageRequirementGaps: [],
          showBlueprintReadinessChecklist: false,
          showNextStepCta: false,
          formData: emptyFormData
        };
      },
      set control(value: CropStagesViewState) {
        lastControl = value;
      },
      reloadTaskScheduleBlueprints: reloadTaskScheduleBlueprintsSpy as () => void
    };
    presenter.setView(view);
  });

  describe('LoadCropForEditOutputPort', () => {
    it('updates view.control with crop name and stages on present(dto)', () => {
      const dto: LoadCropForEditDataDto = {
        crop: {
          id: 1,
          name: 'Test Crop',
          variety: null,
          area_per_unit: null,
          revenue_per_area: null,
          region: null,
          groups: [],
          is_reference: false,
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1,
              temperature_requirement: {
                id: 1,
                crop_stage_id: 1,
                base_temperature: 10.0
              }
            }
          ]
        }
      };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.formData.name).toBe('Test Crop');
      expect(lastControl!.formData.is_reference).toBe(false);
      expect(lastControl!.formData.crop_stages).toEqual(dto.crop.crop_stages);
    });

    it('preserves is_reference on present(dto)', () => {
      const dto: LoadCropForEditDataDto = {
        crop: {
          id: 1,
          name: 'Reference Crop',
          variety: null,
          area_per_unit: null,
          revenue_per_area: null,
          region: null,
          groups: [],
          is_reference: true,
          crop_stages: []
        }
      };

      presenter.present(dto);

      expect(lastControl!.formData.is_reference).toBe(true);
    });
  });

  describe('LoadCropTaskScheduleBlueprintsOutputPort', () => {
    it('updates view.control.taskScheduleBlueprints on present(dto)', () => {
      const dto: LoadCropTaskScheduleBlueprintsDataDto = {
        blueprints: [
          {
            id: 1,
            crop_id: 1,
            agricultural_task_id: 1,
            source_agricultural_task_id: null,
            stage_order: 1,
            stage_name: 'Stage 1',
            gdd_trigger: 0,
            gdd_tolerance: null,
            task_type: 'general',
            source: 'manual',
            priority: 1,
            amount: null,
            amount_unit: null,
            description: null,
            weather_dependency: null,
            time_per_sqm: null
          }
        ]
      };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.taskScheduleBlueprints).toEqual(dto.blueprints);
    });
  });

  describe('CreateCropStageOutputPort', () => {
    it('adds new stage to formData.crop_stages on present(dto)', () => {
      lastControl = baseControlState({
          name: 'Test Crop',
          crop_stages: [{ id: 1, crop_id: 1, name: 'Stage 1', order: 1 }]
      });

      const newStage: CropStage = {
        id: 2,
        crop_id: 1,
        name: 'Stage 2',
        order: 2
      };
      const dto: CreateCropStageOutputDto = { stage: newStage };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages).toHaveLength(2);
      expect(lastControl!.formData.crop_stages[1]).toEqual(newStage);
      expect(lastControl!.pendingSuccessFlash).toEqual({ type: 'success', text: 'crops.flash.stage_created' });
    });
  });

  describe('ReorderCropStagesOutputPort', () => {
    it('reloads blueprints after a successful reorder', () => {
      lastControl = baseControlState({
        name: 'Test Crop',
        crop_stages: [
          { id: 1, crop_id: 1, name: 'Stage 1', order: 1 },
          { id: 2, crop_id: 1, name: 'Stage 2', order: 2 }
        ]
      });

      presenter.present({
        stages: [
          { id: 2, crop_id: 1, name: 'Stage 2', order: 1 },
          { id: 1, crop_id: 1, name: 'Stage 1', order: 2 }
        ]
      });

      expect(reloadTaskScheduleBlueprintsSpy).toHaveBeenCalled();
    });

    it('restores crop stage order on onError when reorder snapshot exists', () => {
      const originalStages: CropStage[] = [
        { id: 1, crop_id: 1, name: 'Stage 1', order: 1 },
        { id: 2, crop_id: 1, name: 'Stage 2', order: 2 }
      ];
      const reorderedStages: CropStage[] = [
        { id: 2, crop_id: 1, name: 'Stage 2', order: 1 },
        { id: 1, crop_id: 1, name: 'Stage 1', order: 2 }
      ];
      lastControl = baseControlState({
        name: 'Test Crop',
        crop_stages: reorderedStages
      });
      lastControl = {
        ...lastControl!,
        pendingReorderCropStagesSnapshot: originalStages
      };

      presenter.onError({ message: 'common.api_error.network' });

      expect(lastControl!.formData.crop_stages).toEqual(originalStages);
      expect(lastControl!.pendingReorderCropStagesSnapshot).toBeNull();
      expect(lastControl!.pendingErrorFlash).toEqual({
        type: 'error',
        text: 'common.api_error.network'
      });
    });
  });

  describe('LoadCropForEditOutputPort onError', () => {
    it('sets control.error and clears loading on initial load failure', () => {
      lastControl = {
        ...baseControlState(),
        loading: true
      };

      presenter.onError({ message: 'common.api_error.not_found' });

      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBe('common.api_error.not_found');
      expect(lastControl!.pendingErrorFlash).toBeNull();
    });
  });

  describe('CreateCropStageOutputPort onError', () => {
    it('queues pending error flash with i18n key on onError', () => {
      lastControl = baseControlState({
        name: 'Test Crop',
        is_reference: false,
        crop_stages: [{ id: 1, crop_id: 1, name: 'Stage 1', order: 1 }]
      });

      presenter.onError({ message: 'common.api_error.network' });

      expect(lastControl!.pendingErrorFlash).toEqual({
        type: 'error',
        text: 'common.api_error.network'
      });
    });
  });
});
