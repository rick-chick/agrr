import { Inject, Injectable } from '@angular/core';
import { ErrorDto } from '../../../domain/shared/error.dto';
import { FieldClimateGateway, FIELD_CLIMATE_GATEWAY } from './field-climate.gateway';
import {
  FetchFieldClimateDataRequestDto,
  LoadFieldClimateInputDto
} from './load-field-climate.dtos';
import { LoadFieldClimateInputPort } from './load-field-climate.input-port';
import {
  LoadFieldClimateOutputPort,
  LOAD_FIELD_CLIMATE_OUTPUT_PORT
} from './load-field-climate.output-port';

@Injectable()
export class LoadFieldClimateUseCase implements LoadFieldClimateInputPort {
  constructor(
    @Inject(LOAD_FIELD_CLIMATE_OUTPUT_PORT)
    private readonly outputPort: LoadFieldClimateOutputPort,
    @Inject(FIELD_CLIMATE_GATEWAY)
    private readonly fieldClimateGateway: FieldClimateGateway
  ) {}

  execute(dto: LoadFieldClimateInputDto): void {
    const request: FetchFieldClimateDataRequestDto = {
      fieldCultivationId: dto.fieldCultivationId,
      planType: dto.planType
    };

    this.fieldClimateGateway.fetchFieldClimateData(request).subscribe({
      next: (data) => {
        this.outputPort.present(data);
      },
      error: (err: Error & { error?: { error?: string; errors?: string[] } }) => {
        // Use ErrorDto so presenter can render consistent toasts/fallback UI
        const errorDto: ErrorDto = {
          message:
            err?.error?.error ??
            err?.error?.errors?.join(', ') ??
            err?.message ??
            'Unknown error'
        };

        this.outputPort.onError(errorDto);
      }
    });
  }
}
