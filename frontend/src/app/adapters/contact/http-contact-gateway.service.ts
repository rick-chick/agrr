import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { ApiService } from '../../services/api.service';
import {
  ContactMessagePayload,
  ContactMessageRecord,
  ContactMessageStatus
} from '../../domain/contact/contact-message.model';
import { ContactGateway, CONTACT_GATEWAY } from '../../usecase/contact/contact-gateway';

@Injectable()
export class HttpContactGateway implements ContactGateway {
  constructor(private readonly apiClient: ApiService) {}

  postMessage(payload: ContactMessagePayload): Observable<ContactMessageRecord> {
    const { captcha_token, ...rest } = payload;
    const body = {
      ...rest,
      captcha_token
    };
    return this.apiClient.post<{ id: number; status: string }>('/api/v1/contact_messages', body).pipe(
      map((res) => ({
        id: res.id,
        status: res.status as ContactMessageStatus
      }))
    );
  }
}

export const CONTACT_GATEWAY_PROVIDER = {
  provide: CONTACT_GATEWAY,
  useClass: HttpContactGateway
};
