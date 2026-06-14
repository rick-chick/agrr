export interface DeleteWorkRecordInputDto {
  planId: number;
  workRecordId: number;
  onSuccess?: () => void;
}
