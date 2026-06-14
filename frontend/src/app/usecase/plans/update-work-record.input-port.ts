import { UpdateWorkRecordInputDto } from './update-work-record.dtos';

export interface UpdateWorkRecordInputPort {
  execute(dto: UpdateWorkRecordInputDto): void;
}
