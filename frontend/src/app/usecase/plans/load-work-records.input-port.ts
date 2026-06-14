import { LoadWorkRecordsInputDto } from './load-work-records.dtos';

export interface LoadWorkRecordsInputPort {
  execute(dto: LoadWorkRecordsInputDto): void;
}
