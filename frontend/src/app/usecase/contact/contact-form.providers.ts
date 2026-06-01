import { Provider } from '@angular/core';
import { CONTACT_GATEWAY_PROVIDER } from '../../adapters/contact/http-contact-gateway.service';
import { ContactFormPresenter } from '../../adapters/contact/contact-form.presenter';
import { SEND_CONTACT_MESSAGE_OUTPUT_PORT } from './send-contact-message.output-port';
import { SendContactMessageUseCase } from './send-contact-message.usecase';

export const CONTACT_FORM_PROVIDERS: readonly Provider[] = [
  ContactFormPresenter,
  SendContactMessageUseCase,
  { provide: SEND_CONTACT_MESSAGE_OUTPUT_PORT, useExisting: ContactFormPresenter },
  CONTACT_GATEWAY_PROVIDER
];

export { ContactFormPresenter } from '../../adapters/contact/contact-form.presenter';
