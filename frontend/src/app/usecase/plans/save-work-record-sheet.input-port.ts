import { SaveWorkRecordSheetInputDto } from './save-work-record-sheet.dtos';

export interface SaveWorkRecordSheetInputPort {
  execute(dto: SaveWorkRecordSheetInputDto): void;
}
