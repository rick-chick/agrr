import {
  ClimateGddPoint,
  ClimateTemperaturePoint
} from '../plans/field-cultivation-climate-data';

export interface WorkRecordClimateSnapshot {
  gddAtActual: number | null;
  weatherSnapshot: ClimateTemperaturePoint | null;
}

export function climatePreviewGddDelta(
  gddAtActual: number | null,
  plannedGdd: number | null
): number | null {
  if (gddAtActual == null || plannedGdd == null) {
    return null;
  }
  return Math.round((gddAtActual - plannedGdd) * 10) / 10;
}

export function snapshotClimateForDate(
  gddData: ClimateGddPoint[],
  weatherData: ClimateTemperaturePoint[],
  actualDate: string
): WorkRecordClimateSnapshot {
  return {
    gddAtActual: gddForDate(gddData, actualDate),
    weatherSnapshot: weatherRowForDate(weatherData, actualDate)
  };
}

function gddForDate(gddData: ClimateGddPoint[], actualDate: string): number | null {
  let last: number | null = null;
  for (const datum of gddData) {
    if (datum.date > actualDate) {
      break;
    }
    if (datum.cumulative_gdd != null) {
      last = datum.cumulative_gdd;
    }
    if (datum.date === actualDate) {
      return last;
    }
  }
  return last;
}

function weatherRowForDate(
  weatherData: ClimateTemperaturePoint[],
  actualDate: string
): ClimateTemperaturePoint | null {
  return weatherData.find((datum) => datum.date === actualDate) ?? null;
}
