import { Provider } from '@angular/core';
import { CONTACT_GATEWAY_PROVIDER } from '../../adapters/contact/http-contact-gateway.service';
import { SendContactMessageUseCase } from './send-contact-message.usecase';

export const CONTACT_FORM_PROVIDERS: readonly Provider[] = [
  SendContactMessageUseCase,
  CONTACT_GATEWAY_PROVIDER
];
