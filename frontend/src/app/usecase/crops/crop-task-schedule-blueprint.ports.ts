import { InjectionToken } from '@angular/core';
import { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadCropTaskScheduleBlueprintsInputDto {
  cropId: number;
}

export interface LoadCropTaskScheduleBlueprintsDataDto {
  blueprints: CropTaskScheduleBlueprint[];
}

export interface LoadCropTaskScheduleBlueprintsInputPort {
  execute(dto: LoadCropTaskScheduleBlueprintsInputDto): void;
}

export interface LoadCropTaskScheduleBlueprintsOutputPort {
  present(dto: LoadCropTaskScheduleBlueprintsDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT =
  new InjectionToken<LoadCropTaskScheduleBlueprintsOutputPort>(
    'LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT'
  );

export interface RegenerateCropTaskScheduleBlueprintsInputDto {
  cropId: number;
}

export interface RegenerateCropTaskScheduleBlueprintsDataDto {
  blueprints: CropTaskScheduleBlueprint[];
}

export interface RegenerateCropTaskScheduleBlueprintsInputPort {
  execute(dto: RegenerateCropTaskScheduleBlueprintsInputDto): void;
}

export interface RegenerateCropTaskScheduleBlueprintsOutputPort {
  onRegenerateStarted(): void;
  present(dto: RegenerateCropTaskScheduleBlueprintsDataDto): void;
  onError(dto: ErrorDto): void;
}

export const REGENERATE_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT =
  new InjectionToken<RegenerateCropTaskScheduleBlueprintsOutputPort>(
    'REGENERATE_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT'
  );

export interface CropStageOrderName {
  order: number;
  name: string;
}

export interface UpdateCropTaskScheduleBlueprintInputDto {
  cropId: number;
  blueprintId: number;
  gddTrigger?: number;
  stageOrder?: number | null;
  cropStages?: CropStageOrderName[];
}

export interface ApplyBlueprintDropInputDto {
  cropId: number;
  dragged: CropTaskScheduleBlueprint;
  targetStageOrder: number | null;
  laneBlueprints: ReadonlyArray<CropTaskScheduleBlueprint>;
  dropIndex: number;
  cropStages?: CropStageOrderName[];
}

export interface UpdateCropTaskScheduleBlueprintDataDto {
  blueprint: CropTaskScheduleBlueprint;
}

export interface UpdateCropTaskScheduleBlueprintInputPort {
  execute(dto: UpdateCropTaskScheduleBlueprintInputDto): void;
  executeDrop(dto: ApplyBlueprintDropInputDto): void;
}

export interface UpdateCropTaskScheduleBlueprintOutputPort {
  onUpdateStarted(blueprintId: number): void;
  present(dto: UpdateCropTaskScheduleBlueprintDataDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT =
  new InjectionToken<UpdateCropTaskScheduleBlueprintOutputPort>(
    'UPDATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT'
  );

export interface DeleteCropTaskScheduleBlueprintInputDto {
  cropId: number;
  blueprintId: number;
}

export interface DeleteCropTaskScheduleBlueprintDataDto {
  blueprintId: number;
}

export interface DeleteCropTaskScheduleBlueprintInputPort {
  execute(dto: DeleteCropTaskScheduleBlueprintInputDto): void;
}

export interface DeleteCropTaskScheduleBlueprintOutputPort {
  present(dto: DeleteCropTaskScheduleBlueprintDataDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT =
  new InjectionToken<DeleteCropTaskScheduleBlueprintOutputPort>(
    'DELETE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT'
  );

export interface CreateCropTaskScheduleBlueprintInputDto {
  cropId: number;
  agriculturalTaskId: number;
  stageOrder?: number | null;
  stageName?: string | null;
  gddTrigger?: number | null;
}

export interface CreateCropTaskScheduleBlueprintDataDto {
  blueprint: CropTaskScheduleBlueprint;
}

export interface CreateCropTaskScheduleBlueprintInputPort {
  execute(dto: CreateCropTaskScheduleBlueprintInputDto): void;
}

export interface CreateCropTaskScheduleBlueprintOutputPort {
  present(dto: CreateCropTaskScheduleBlueprintDataDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT =
  new InjectionToken<CreateCropTaskScheduleBlueprintOutputPort>(
    'CREATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT'
  );
