import { Inject, Injectable } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { catchError } from 'rxjs/operators';
import { of } from 'rxjs';
import {
  SendContactMessageInputDto,
  SendContactMessageSuccessDto
} from './send-contact-message.dtos';
import { SendContactMessageInputPort } from './send-contact-message.input-port';
import { SendContactMessageOutputPort } from './send-contact-message.output-port';
import { CONTACT_GATEWAY, ContactGateway } from './contact-gateway';
import { ErrorDto } from '../../domain/shared/error.dto';
import { ContactMessageRecord } from '../../domain/contact/contact-message.model';
import { apiErrorCode } from '../../core/api-error-message';

@Injectable()
export class SendContactMessageUseCase implements SendContactMessageInputPort {
  private static readonly validationErrorMessage = 'contact_form.errors.validation_failed';
  private static readonly sendFailedMessage = 'contact_form.errors.send_failed';
  private static readonly captchaFailedMessage = 'contact_form.errors.captcha_failed';
  private static readonly captchaUnavailableMessage = 'contact_form.errors.captcha_unavailable';

  constructor(@Inject(CONTACT_GATEWAY) private readonly gateway: ContactGateway) {}

  execute(dto: SendContactMessageInputDto, outputPort: SendContactMessageOutputPort): void {
    this.gateway
      .postMessage(dto)
      .pipe(
        catchError((err) => {
          outputPort.onError(this.toErrorDto(err));
          return of(null);
        })
      )
      .subscribe((record) => {
        if (!record) return;
        outputPort.onSuccess(this.toSuccessDto(record));
      });
  }

  private toSuccessDto(record: ContactMessageRecord): SendContactMessageSuccessDto {
    return {
      id: record.id,
      status: record.status
    };
  }

  private toErrorDto(error: unknown): ErrorDto {
    const code = apiErrorCode(error);
    if (code === 'captcha_failed') {
      return { message: SendContactMessageUseCase.captchaFailedMessage };
    }
    if (code === 'captcha_unavailable') {
      return { message: SendContactMessageUseCase.captchaUnavailableMessage };
    }
    if (this.isValidationError(error)) {
      return { message: SendContactMessageUseCase.validationErrorMessage };
    }
    return { message: SendContactMessageUseCase.sendFailedMessage };
  }

  private isValidationError(error: unknown): boolean {
    if (error instanceof HttpErrorResponse) {
      return error.status === 422 && apiErrorCode(error) == null;
    }
    const status = (error as { status?: number })?.status;
    return status === 422 && apiErrorCode(error) == null;
  }
}
