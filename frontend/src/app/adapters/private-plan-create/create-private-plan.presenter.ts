import { Injectable } from '@angular/core';
import { CreatePrivatePlanOutputPort } from '../../usecase/private-plan-create/create-private-plan.output-port';
import { CreatePrivatePlanResponseDto } from '../../usecase/private-plan-create/create-private-plan.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FlashMessageService } from '../../services/flash-message.service';
import { TranslateService } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { inject } from '@angular/core';

export interface CreatePrivatePlanView {
  control: {
    loading: boolean;
    error: string | null;
  };
}

@Injectable()
export class CreatePrivatePlanPresenter implements CreatePrivatePlanOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private readonly translate = inject(TranslateService);
  private readonly router = inject(Router);
  private view: CreatePrivatePlanView | null = null;

  setView(view: CreatePrivatePlanView): void {
    this.view = view;
  }

  present(dto: CreatePrivatePlanResponseDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.flashMessage.show({
      type: 'success',
      text: this.translate.instant('adapters.privatePlanCreate.flash.success')
    });
    this.view.control = {
      loading: false,
      error: null
    };
    // 成功時は最適化画面へ遷移
    this.router.navigate(['/plans', dto.id, 'optimizing']);
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.flashMessage.show({ type: 'error', text: dto.message });
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null
    };
  }
}