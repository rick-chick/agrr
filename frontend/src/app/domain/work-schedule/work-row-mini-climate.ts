import {
  ClimateGddPoint,
  ClimateTemperaturePoint
} from '../plans/field-cultivation-climate-data';
import { snapshotClimateForDate } from './work-record-climate-snapshot';

const MINI_CLIMATE_DAYS = 7;

export interface WorkRowMiniClimateDailyWeather {
  date: string;
  temperatureMax: number | null;
  temperatureMin: number | null;
  temperatureMean: number | null;
}

export interface WorkRowMiniClimateSummary {
  cumulativeGdd: number | null;
  dailyWeather: WorkRowMiniClimateDailyWeather[];
}

function parseDate(isoDate: string): Date {
  const [y, m, d] = isoDate.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function addDays(isoDate: string, days: number): string {
  const date = parseDate(isoDate);
  date.setDate(date.getDate() + days);
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function computeWorkRowMiniClimateDateRange(today: string): {
  startDate: string;
  endDate: string;
} {
  return {
    startDate: addDays(today, -(MINI_CLIMATE_DAYS - 1)),
    endDate: today
  };
}

function toDailyWeather(point: ClimateTemperaturePoint): WorkRowMiniClimateDailyWeather {
  return {
    date: point.date,
    temperatureMax: point.temperature_max ?? null,
    temperatureMin: point.temperature_min ?? null,
    temperatureMean: point.temperature_mean ?? null
  };
}

export function buildWorkRowMiniClimateSummary(
  gddData: ClimateGddPoint[],
  weatherData: ClimateTemperaturePoint[],
  startDate: string,
  endDate: string
): WorkRowMiniClimateSummary {
  const dailyWeather = weatherData
    .filter((point) => point.date >= startDate && point.date <= endDate)
    .sort((left, right) => left.date.localeCompare(right.date))
    .map(toDailyWeather);

  const snapshot = snapshotClimateForDate(gddData, weatherData, endDate);

  return {
    cumulativeGdd: snapshot.gddAtActual,
    dailyWeather
  };
}
