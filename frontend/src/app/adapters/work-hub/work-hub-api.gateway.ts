import { Injectable } from '@angular/core';
import { map, Observable } from 'rxjs';
import { ApiService } from '../../services/api.service';
import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';
import { WorkHubGateway } from '../../usecase/work-hub/work-hub-gateway';

interface WorkHubFarmApiRow {
  farm_id: number;
  farm_name: string;
  field_count: number;
  total_area: number;
  has_valid_fields: boolean;
  plan_id: number | null;
}

@Injectable()
export class WorkHubApiGateway implements WorkHubGateway {
  constructor(private readonly apiClient: ApiService) {}

  listHubFarms(): Observable<WorkHubFarmRow[]> {
    return this.apiClient.get<WorkHubFarmApiRow[]>('/api/v1/work/hub').pipe(
      map((rows) =>
        rows.map((row) => ({
          farmId: row.farm_id,
          farmName: row.farm_name,
          fieldCount: row.field_count,
          totalArea: row.total_area,
          hasValidFields: row.has_valid_fields,
          planId: row.plan_id
        }))
      )
    );
  }
}
