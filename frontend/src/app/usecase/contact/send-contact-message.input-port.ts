import { SendContactMessageInputDto } from './send-contact-message.dtos';
import { SendContactMessageOutputPort } from './send-contact-message.output-port';

export interface SendContactMessageInputPort {
  execute(dto: SendContactMessageInputDto, outputPort: SendContactMessageOutputPort): void;
}

