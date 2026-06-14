import { CreateWorkRecordInputDto } from './create-work-record.dtos';

export interface CreateWorkRecordInputPort {
  execute(dto: CreateWorkRecordInputDto): void;
}
