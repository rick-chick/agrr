import { InjectionToken } from '@angular/core';
import { MastersCropTaskTemplate } from '../../domain/crops/masters-crop-task-template';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadCropTaskTemplatesInputDto {
  cropId: number;
}

export interface LoadCropTaskTemplatesDataDto {
  templates: MastersCropTaskTemplate[];
}

export interface LoadCropTaskTemplatesInputPort {
  execute(dto: LoadCropTaskTemplatesInputDto): void;
}

export interface LoadCropTaskTemplatesOutputPort {
  present(dto: LoadCropTaskTemplatesDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_CROP_TASK_TEMPLATES_OUTPUT_PORT = new InjectionToken<LoadCropTaskTemplatesOutputPort>(
  'LOAD_CROP_TASK_TEMPLATES_OUTPUT_PORT'
);

export interface CreateCropTaskTemplateInputDto {
  cropId: number;
  agriculturalTaskId: number;
}

export interface CreateCropTaskTemplateDataDto {
  template: MastersCropTaskTemplate;
}

export interface CreateCropTaskTemplateInputPort {
  execute(dto: CreateCropTaskTemplateInputDto): void;
}

export interface CreateCropTaskTemplateOutputPort {
  present(dto: CreateCropTaskTemplateDataDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_CROP_TASK_TEMPLATE_OUTPUT_PORT = new InjectionToken<CreateCropTaskTemplateOutputPort>(
  'CREATE_CROP_TASK_TEMPLATE_OUTPUT_PORT'
);

export interface DeleteCropTaskTemplateInputDto {
  cropId: number;
  templateId: number;
}

export interface DeleteCropTaskTemplateDataDto {
  templateId: number;
}

export interface DeleteCropTaskTemplateInputPort {
  execute(dto: DeleteCropTaskTemplateInputDto): void;
}

export interface DeleteCropTaskTemplateOutputPort {
  present(dto: DeleteCropTaskTemplateDataDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_CROP_TASK_TEMPLATE_OUTPUT_PORT = new InjectionToken<DeleteCropTaskTemplateOutputPort>(
  'DELETE_CROP_TASK_TEMPLATE_OUTPUT_PORT'
);
