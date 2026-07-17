import { TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { CropStageEditPresenter } from './crop-stage-edit.presenter';
import {
  CropStageEditView,
  CropStageEditViewState
} from '../../components/masters/crops/crop-stage-edit.view';
import { CropStage } from '../../domain/crops/crop';

describe('CropStageEditPresenter', () => {
  let presenter: CropStageEditPresenter;
  let view: CropStageEditView;
  let lastControl: CropStageEditViewState | null;
  let reloadTaskScheduleBlueprintsSpy: ReturnType<typeof vi.fn>;

  const emptyFormData: CropStageEditViewState['formData'] = {
    name: '',
    is_reference: false,
    crop_stages: []
  };

  const stageFixture: CropStage = {
    id: 1,
    crop_id: 1,
    name: 'Germination',
    order: 1,
    temperature_requirement: {
      id: 1,
      crop_stage_id: 1,
      base_temperature: 10
    },
    thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 100 }
  };

  const baseControlState = (
    formData: Partial<CropStageEditViewState['formData']> = emptyFormData
  ): CropStageEditViewState => ({
    loading: false,
    error: null,
    pendingErrorFlash: null,
    pendingSuccessFlash: null,
    pendingResyncPanelDraft: false,
    pendingNavigateToList: false,
    taskScheduleBlueprints: [],
    formData: { ...emptyFormData, ...formData }
  });

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CropStageEditPresenter]
    });
    presenter = TestBed.inject(CropStageEditPresenter);
    lastControl = null;
    reloadTaskScheduleBlueprintsSpy = vi.fn();
    view = {
      get control(): CropStageEditViewState {
        return lastControl ?? {
          loading: true,
          error: null,
          pendingErrorFlash: null,
          pendingSuccessFlash: null,
          pendingResyncPanelDraft: false,
          pendingNavigateToList: false,
          taskScheduleBlueprints: [],
          formData: emptyFormData
        };
      },
      set control(value: CropStageEditViewState) {
        lastControl = value;
      },
      reloadTaskScheduleBlueprints: reloadTaskScheduleBlueprintsSpy as () => void
    };
    presenter.setView(view);
  });

  describe('SaveCropStagePanelOutputPort', () => {
    it('updates stage in formData and queues success flash on onSuccess', () => {
      lastControl = baseControlState({
        name: 'Tomato',
        crop_stages: [stageFixture]
      });

      const updatedStage: CropStage = {
        ...stageFixture,
        name: 'Updated Name'
      };
      presenter.onSuccess({ stage: updatedStage });

      expect(lastControl!.formData.crop_stages[0]).toEqual(updatedStage);
      expect(lastControl!.pendingSuccessFlash).toEqual({
        type: 'success',
        text: 'crops.flash.stage_updated'
      });
      expect(lastControl!.pendingResyncPanelDraft).toBe(true);
      expect(lastControl!.pendingNavigateToList).toBe(false);
    });

    it('resyncs crop data and queues error flash on onPanelPartialFailure', () => {
      lastControl = baseControlState({
        name: 'Tomato',
        crop_stages: [stageFixture]
      });

      const serverStage: CropStage = {
        ...stageFixture,
        name: 'Server Name'
      };
      presenter.onPanelPartialFailure({
        crop: {
          id: 1,
          name: 'Tomato',
          variety: null,
          area_per_unit: null,
          revenue_per_area: null,
          region: null,
          groups: [],
          is_reference: false,
          crop_stages: [serverStage]
        },
        stageId: 1
      });

      expect(lastControl!.formData.crop_stages).toEqual([serverStage]);
      expect(lastControl!.pendingErrorFlash).toEqual({
        type: 'error',
        text: 'crops.flash.stage_panel_partial_save_failed'
      });
      expect(lastControl!.pendingResyncPanelDraft).toBe(true);
    });
  });

  describe('SaveCropStageAdvancedDetailsOutputPort', () => {
    it('resyncs crop data and queues error flash on onAdvancedPartialFailure', () => {
      lastControl = baseControlState({
        name: 'Tomato',
        crop_stages: [stageFixture]
      });

      const serverStage: CropStage = {
        ...stageFixture,
        thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 100 }
      };
      presenter.onAdvancedPartialFailure({
        crop: {
          id: 1,
          name: 'Tomato',
          variety: null,
          area_per_unit: null,
          revenue_per_area: null,
          region: null,
          groups: [],
          is_reference: false,
          crop_stages: [serverStage]
        },
        stageId: 1
      });

      expect(lastControl!.formData.crop_stages).toEqual([serverStage]);
      expect(lastControl!.pendingErrorFlash).toEqual({
        type: 'error',
        text: 'crops.flash.stage_advanced_partial_save_failed'
      });
      expect(lastControl!.pendingResyncPanelDraft).toBe(true);
    });
  });

  describe('DeleteCropStageOutputPort', () => {
    it('removes stage, queues success flash, and sets pendingNavigateToList on present', () => {
      const otherStage: CropStage = { id: 2, crop_id: 1, name: 'Stage 2', order: 2 };
      lastControl = baseControlState({
        name: 'Tomato',
        crop_stages: [stageFixture, otherStage]
      });

      presenter.present({ success: true, stageId: 1 });

      expect(lastControl!.formData.crop_stages).toEqual([otherStage]);
      expect(lastControl!.pendingSuccessFlash).toEqual({
        type: 'success',
        text: 'crops.flash.stage_deleted'
      });
      expect(lastControl!.pendingNavigateToList).toBe(true);
      expect(reloadTaskScheduleBlueprintsSpy).toHaveBeenCalled();
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

    it('queues pending error flash on onError after load', () => {
      lastControl = baseControlState({
        name: 'Tomato',
        crop_stages: [stageFixture]
      });

      presenter.onError({ message: 'common.api_error.network' });

      expect(lastControl!.pendingErrorFlash).toEqual({
        type: 'error',
        text: 'common.api_error.network'
      });
      expect(lastControl!.pendingNavigateToList).toBe(false);
    });
  });
});
