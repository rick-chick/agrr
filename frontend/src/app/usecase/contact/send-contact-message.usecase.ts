import { Inject, Injectable } from '@angular/core';
import { catchError } from 'rxjs/operators';
import { of } from 'rxjs';
import { SendContactMessageInputDto, SendContactMessageSuccessDto } from './send-contact-message.dtos';
import { SendContactMessageInputPort } from './send-contact-message.input-port';
import { SendContactMessageOutputPort } from './send-contact-message.output-port';
import { CONTACT_GATEWAY, ContactGateway } from './contact-gateway';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class SendContactMessageUseCase implements SendContactMessageInputPort {
  constructor(@Inject(CONTACT_GATEWAY) private readonly gateway: ContactGateway) {}

  execute(dto: SendContactMessageInputDto, outputPort: SendContactMessageOutputPort): void {
    // Call gateway and forward responses to output port.
    this.gateway
      .postMessage(dto)
      .pipe(
        catchError((err) => {
          // Normalize common Rails API error shapes
          if (err && err.status === 422 && err.error) {
            // prefer single error message if provided
            const body = err.error;
            const msg =
              typeof body.error === 'string'
                ? body.error
                : body.field_errors
                ? Object.values(body.field_errors)
                    .flat()
                    .join(', ')
                : err.message || 'contact_form.errors.validation_failed';
            outputPort.onError({ message: msg });
            return of(null as any);
          }
          const message = err?.error?.error || err?.message || 'contact_form.errors.send_failed';
          outputPort.onError({ message });
          return of(null as any);
        })
      )
      .subscribe((res) => {
        if (!res) return;
        const successDto: SendContactMessageSuccessDto = {
          id: res.id,
          status: res.status,
          created_at: res.created_at,
          sent_at: res.sent_at ?? null
        };
        outputPort.onSuccess(successDto);
      });
  }
}

