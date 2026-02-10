import { InjectionToken } from '@angular/core';
import { SendContactMessageSuccessDto } from './send-contact-message.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface SendContactMessageOutputPort {
  onSuccess(dto: SendContactMessageSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const SEND_CONTACT_MESSAGE_OUTPUT_PORT = new InjectionToken<SendContactMessageOutputPort>(
  'SEND_CONTACT_MESSAGE_OUTPUT_PORT'
);

