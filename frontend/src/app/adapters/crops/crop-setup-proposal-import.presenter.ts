import { Injectable } from '@angular/core';
import { CropSetupProposalImportView } from '../../components/masters/crops/crop-setup-proposal-import.view';
import { CropSetupProposalApplyResponse, CropSetupProposalDryRunResponse } from '../../domain/crops/crop-setup-proposal';
import { ErrorDto } from '../../domain/shared/error.dto';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';
import { LoadCropForEditOutputPort } from '../../usecase/crops/load-crop-for-edit.output-port';
import {
  ApplyCropSetupProposalOutputPort,
  DryRunCropSetupProposalOutputPort
} from '../../usecase/crops/crop-setup-proposal.ports';

@Injectable()
export class CropSetupProposalImportPresenter
  implements LoadCropForEditOutputPort, DryRunCropSetupProposalOutputPort, ApplyCropSetupProposalOutputPort
{
  private view: CropSetupProposalImportView | null = null;

  setView(view: CropSetupProposalImportView): void {
    this.view = view;
  }

  present(dto: LoadCropForEditDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      cropName: dto.crop.name
    };
  }

  onDryRunStarted(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      submitting: true,
      error: null,
      phase: 'input',
      validationErrors: [],
      normalizedPreview: null
    };
  }

  onDryRunSuccess(dto: CropSetupProposalDryRunResponse): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.valid) {
      this.view.control = {
        ...this.view.control,
        submitting: false,
        phase: 'preview',
        validationErrors: [],
        normalizedPreview: dto.normalized ?? null
      };
      return;
    }

    this.view.control = {
      ...this.view.control,
      submitting: false,
      phase: 'validation_errors',
      validationErrors: dto.errors ?? [],
      normalizedPreview: null
    };
  }

  onApplyStarted(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      applying: true,
      error: null
    };
  }

  onApplySuccess(dto: CropSetupProposalApplyResponse): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.valid === false) {
      this.view.control = {
        ...this.view.control,
        applying: false,
        phase: 'validation_errors',
        validationErrors: dto.errors,
        normalizedPreview: null
      };
      return;
    }

    this.view.control = {
      ...this.view.control,
      applying: false
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      submitting: false,
      applying: false,
      error: dto.message
    };
  }
}
