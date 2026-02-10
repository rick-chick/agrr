import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { ContactMessagePayload, ContactMessageRecord } from '../../domain/contact/contact-message.model';

export interface ContactGateway {
  postMessage(payload: ContactMessagePayload): Observable<ContactMessageRecord>;
}

export const CONTACT_GATEWAY = new InjectionToken<ContactGateway>('CONTACT_GATEWAY');

