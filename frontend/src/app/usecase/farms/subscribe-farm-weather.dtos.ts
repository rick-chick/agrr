import { Channel } from 'actioncable';

export interface FarmWeatherUpdateDto {
  id?: number;
  weather_data_status?: string;
  weather_data_progress?: number;
  weather_data_fetched_years?: number;
  weather_data_total_years?: number;
}

export interface SubscribeFarmWeatherInputDto {
  farmId: number;
  onSubscribed?: (channel: Channel) => void;
}
