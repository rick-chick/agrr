import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import {
  CropSetupProposalApplyResponse,
  CropSetupProposalBody,
  CropSetupProposalDryRunResponse
} from '../../domain/crops/crop-setup-proposal';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { CropSetupProposalGateway } from '../../usecase/crops/crop-setup-proposal-gateway';

@Injectable()
export class CropSetupProposalApiGateway implements CropSetupProposalGateway {
  constructor(private readonly client: MastersClientService) {}

  dryRun(cropId: number, body: CropSetupProposalBody): Observable<CropSetupProposalDryRunResponse> {
    return this.client.post<CropSetupProposalDryRunResponse>(
      `/crops/${cropId}/setup_proposal?mode=dry_run`,
      body
    );
  }

  apply(cropId: number, body: CropSetupProposalBody): Observable<CropSetupProposalApplyResponse> {
    return this.client.post<CropSetupProposalApplyResponse>(
      `/crops/${cropId}/setup_proposal?mode=apply`,
      body
    );
  }
}
