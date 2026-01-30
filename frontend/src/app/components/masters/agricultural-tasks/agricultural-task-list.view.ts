import { AgriculturalTask } from '../../../domain/agricultural-tasks/agricultural-task';

export type AgriculturalTaskListViewState = {
  loading: boolean;
  error: string | null;
  tasks: AgriculturalTask[];
};

export interface AgriculturalTaskListView {
  get control(): AgriculturalTaskListViewState;
  set control(value: AgriculturalTaskListViewState);
}
