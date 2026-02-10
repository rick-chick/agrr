import { Channel } from 'actioncable';

export interface SubscribePlanOptimizationInputDto {
  planId: number;
  onSubscribed?: (channel: Channel) => void;
}

export interface PlanOptimizationMessageDto {
  status?: string;
  progress?: number;
  message_key?: string;
}
