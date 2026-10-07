import { ContactMessagePayload, ContactMessageRecord } from '../../domain/contact/contact-message.model';

export type SendContactMessageInputDto = ContactMessagePayload;

export interface SendContactMessageSuccessDto {
  id: number;
  status: ContactMessageRecord['status'];
}
