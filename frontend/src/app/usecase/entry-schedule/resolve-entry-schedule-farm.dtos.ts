import { Farm } from '../../domain/farms/farm';

export interface ResolveEntryScheduleFarmInputDto {
  region: string;
  farmId: number;
}

export interface ResolveEntryScheduleFarmDataDto {
  farm: Farm;
}
