export interface CropSetupProposalBody {
  stages: unknown[];
  agricultural_tasks: unknown[];
  task_schedule_blueprints: unknown[];
}

export interface CropSetupProposalValidationErrorItem {
  path: string;
  message: string;
}

export interface CropSetupProposalDryRunResponse {
  mode: 'dry_run';
  valid: boolean;
  normalized?: CropSetupProposalBody;
  errors?: CropSetupProposalValidationErrorItem[];
}

export type CropSetupProposalApplyResponse =
  | {
      mode: 'apply';
      valid: true;
      normalized: CropSetupProposalBody;
      result: {
        stage_ids: number[];
        agricultural_task_ids: number[];
        blueprint_ids: number[];
      };
    }
  | {
      mode: 'apply';
      valid: false;
      errors: CropSetupProposalValidationErrorItem[];
    };
