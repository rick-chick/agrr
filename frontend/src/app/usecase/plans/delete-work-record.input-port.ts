import { DeleteWorkRecordInputDto } from './delete-work-record.dtos';

export interface DeleteWorkRecordInputPort {
  execute(dto: DeleteWorkRecordInputDto): void;
}
