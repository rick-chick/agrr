import { Channel } from 'actioncable';

export interface SubscribePublicPlanOptimizationInputDto {
  planId: number;
  onSubscribed?: (channel: Channel) => void;
}

export interface PublicPlanOptimizationMessageDto {
  status?: string;
  progress?: number;
  phase_message?: string;
  message_key?: string;
}
