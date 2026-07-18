import {
  CropSetupProposalBody,
  CropSetupProposalValidationErrorItem
} from '../../../domain/crops/crop-setup-proposal';

type CropSetupProposalImportPhase = 'input' | 'preview' | 'validation_errors';

export interface CropSetupProposalImportViewState {
  loading: boolean;
  submitting: boolean;
  applying: boolean;
  error: string | null;
  cropName: string | null;
  jsonInput: string;
  phase: CropSetupProposalImportPhase;
  validationErrors: CropSetupProposalValidationErrorItem[];
  normalizedPreview: CropSetupProposalBody | null;
  parsedProposal: CropSetupProposalBody | null;
}

export interface CropSetupProposalImportView {
  control: CropSetupProposalImportViewState;
}
