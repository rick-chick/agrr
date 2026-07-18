import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import {
  CropSetupProposalApplyResponse,
  CropSetupProposalBody,
  CropSetupProposalDryRunResponse
} from '../../domain/crops/crop-setup-proposal';

export interface CropSetupProposalGateway {
  dryRun(cropId: number, body: CropSetupProposalBody): Observable<CropSetupProposalDryRunResponse>;
  apply(cropId: number, body: CropSetupProposalBody): Observable<CropSetupProposalApplyResponse>;
}

export const CROP_SETUP_PROPOSAL_GATEWAY = new InjectionToken<CropSetupProposalGateway>(
  'CROP_SETUP_PROPOSAL_GATEWAY'
);
