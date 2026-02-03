import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiClientService } from '../../services/api-client.service';
import { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';
import { FieldClimateGateway } from '../../usecase/plans/field-climate/field-climate.gateway';
import { FetchFieldClimateDataRequestDto } from '../../usecase/plans/field-climate/load-field-climate.dtos';

@Injectable()
export class FieldClimateApiGateway implements FieldClimateGateway {
  constructor(private readonly apiClient: ApiClientService) {}

  fetchFieldClimateData(
    dto: FetchFieldClimateDataRequestDto
  ): Observable<FieldCultivationClimateData> {
    const basePath =
      dto.planType === 'public' ? '/api/v1/public_plans' : '/api/v1/plans';

    const url = `${basePath}/field_cultivations/${dto.fieldCultivationId}/climate_data`;

    return this.apiClient.get<FieldCultivationClimateData>(url);
  }
}
