import { LoadWorkDayListInputDto } from './load-work-day-list.dtos';

export interface LoadWorkDayListInputPort {
  execute(dto: LoadWorkDayListInputDto): void;
}
