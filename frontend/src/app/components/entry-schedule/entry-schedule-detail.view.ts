import { EntryScheduleCropShowResponse } from '../../domain/entry-schedule/entry-schedule';

export interface EntryScheduleDetailViewState {
  loading: boolean;
  errorKey: string | null;
  data: EntryScheduleCropShowResponse | null;
}

export interface EntryScheduleDetailView {
  get control(): EntryScheduleDetailViewState;
  set control(value: EntryScheduleDetailViewState);
  onCropLoaded(cropId: number, cropName: string): void;
  onCropLoadFailed(): void;
}
