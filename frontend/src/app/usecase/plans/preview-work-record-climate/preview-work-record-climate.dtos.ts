export interface PreviewWorkRecordClimateInputDto {
  fieldCultivationId: number | null;
  actualDate: string;
}

export interface PreviewWorkRecordClimateStateDto {
  gddAtActual: number | null;
  weatherDate: string | null;
  temperatureMax: number | null;
  temperatureMin: number | null;
  temperatureMean: number | null;
  loading: boolean;
}
