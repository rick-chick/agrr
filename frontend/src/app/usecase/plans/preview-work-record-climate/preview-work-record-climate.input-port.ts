import { PreviewWorkRecordClimateInputDto } from './preview-work-record-climate.dtos';

export interface PreviewWorkRecordClimateInputPort {
  execute(dto: PreviewWorkRecordClimateInputDto): void;
}
