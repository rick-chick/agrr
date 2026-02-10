import { Inject, Injectable } from '@angular/core';
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

@Injectable()
export class SendContactMessageUseCase implements SendContactMessageInputPort {
  private static readonly validationErrorMessage = 'contact_form.errors.validation_failed';
  private static readonly sendFailedMessage = 'contact_form.errors.send_failed';

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
        if (record.status === 'failed') {
          outputPort.onError({ message: SendContactMessageUseCase.sendFailedMessage });
          return;
        }
        outputPort.onSuccess(this.toSuccessDto(record));
      });
  }

  private toSuccessDto(record: ContactMessageRecord): SendContactMessageSuccessDto {
    return {
      id: record.id,
      status: record.status,
      created_at: record.created_at,
      sent_at: record.sent_at ?? null
    };
  }

  private toErrorDto(error: any): ErrorDto {
    if (this.isValidationError(error)) {
      return { message: SendContactMessageUseCase.validationErrorMessage };
    }
    return { message: SendContactMessageUseCase.sendFailedMessage };
  }

  private isValidationError(error: any): boolean {
    return error?.status === 422;
  }
}

