import { Provider } from '@angular/core';
import { CropSetupProposalApiGateway } from '../../adapters/crops/crop-setup-proposal-api.gateway';
import { CropSetupProposalImportPresenter } from '../../adapters/crops/crop-setup-proposal-import.presenter';
import { CROP_SETUP_PROPOSAL_GATEWAY } from './crop-setup-proposal-gateway';
import { ApplyCropSetupProposalUseCase } from './apply-crop-setup-proposal.usecase';
import { DryRunCropSetupProposalUseCase } from './dry-run-crop-setup-proposal.usecase';
import {
  APPLY_CROP_SETUP_PROPOSAL_OUTPUT_PORT,
  DRY_RUN_CROP_SETUP_PROPOSAL_OUTPUT_PORT
} from './crop-setup-proposal.ports';
import { LoadCropForEditUseCase } from './load-crop-for-edit.usecase';
import { LOAD_CROP_FOR_EDIT_OUTPUT_PORT } from './load-crop-for-edit.output-port';
import { CROP_GATEWAY } from './crop-gateway';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';

export const CROP_SETUP_PROPOSAL_IMPORT_PROVIDERS: readonly Provider[] = [
  CropSetupProposalImportPresenter,
  LoadCropForEditUseCase,
  DryRunCropSetupProposalUseCase,
  ApplyCropSetupProposalUseCase,
  { provide: LOAD_CROP_FOR_EDIT_OUTPUT_PORT, useExisting: CropSetupProposalImportPresenter },
  { provide: DRY_RUN_CROP_SETUP_PROPOSAL_OUTPUT_PORT, useExisting: CropSetupProposalImportPresenter },
  { provide: APPLY_CROP_SETUP_PROPOSAL_OUTPUT_PORT, useExisting: CropSetupProposalImportPresenter },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: CROP_SETUP_PROPOSAL_GATEWAY, useClass: CropSetupProposalApiGateway }
];

export { CropSetupProposalImportPresenter } from '../../adapters/crops/crop-setup-proposal-import.presenter';
