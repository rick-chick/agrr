import { ContactMessagePayload, ContactMessageRecord } from '../../domain/contact/contact-message.model';

export type SendContactMessageInputDto = ContactMessagePayload;

export interface SendContactMessageSuccessDto {
  id: number;
  status: ContactMessageRecord['status'];
  created_at: string;
  sent_at?: string | null;
}

