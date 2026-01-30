import { AgriculturalTask } from '../../../domain/agricultural-tasks/agricultural-task';

export type AgriculturalTaskDetailViewState = {
  loading: boolean;
  error: string | null;
  agriculturalTask: AgriculturalTask | null;
};

export interface AgriculturalTaskDetailView {
  get control(): AgriculturalTaskDetailViewState;
  set control(value: AgriculturalTaskDetailViewState);
}