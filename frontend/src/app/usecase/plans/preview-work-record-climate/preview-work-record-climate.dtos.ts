export interface PreviewWorkRecordClimateInputDto {
  fieldCultivationId: number | null;
  actualDate: string;
  gddTrigger?: string | number | null;
}

export interface PreviewWorkRecordClimateStateDto {
  gddAtActual: number | null;
  weatherDate: string | null;
  temperatureMax: number | null;
  temperatureMin: number | null;
  temperatureMean: number | null;
  plannedGdd: number | null;
  gddDelta: number | null;
  loading: boolean;
}
