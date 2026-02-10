import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { ApiClientService } from '../../services/api-client.service';
import {
  ContactMessagePayload,
  ContactMessageRecord,
  ContactMessageStatus
} from '../../domain/contact/contact-message.model';
import { ContactGateway, CONTACT_GATEWAY } from '../../usecase/contact/contact-gateway';

@Injectable()
export class HttpContactGateway implements ContactGateway {
  constructor(private readonly apiClient: ApiClientService) {}

  postMessage(payload: ContactMessagePayload): Observable<ContactMessageRecord> {
    // POST to API as contract: POST /api/v1/contact_messages with flat JSON body
    return this.apiClient.post<any>('/api/v1/contact_messages', payload).pipe(
      map((res) => {
        const record: ContactMessageRecord = {
          id: res.id,
          name: res.name ?? null,
          email: res.email,
          subject: res.subject ?? null,
          message: res.message,
          source: res.source ?? null,
          status: res.status as ContactMessageStatus,
          created_at: res.created_at,
          sent_at: res.sent_at ?? null
        };
        return record;
      })
    );
  }
}

// Export a provider so callers can register the implementation with the existing token.
export const CONTACT_GATEWAY_PROVIDER = {
  provide: CONTACT_GATEWAY,
  useClass: HttpContactGateway
};

