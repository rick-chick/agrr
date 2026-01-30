export interface Farm {
  id: number;
  name: string;
  latitude: number;
  longitude: number;
  region: string;
  description?: string | null;
  weather_data_status?: 'pending' | 'fetching' | 'completed' | 'failed';
  weather_data_progress?: number;
  weather_data_fetched_years?: number;
  weather_data_total_years?: number;
  is_reference?: boolean;
}
