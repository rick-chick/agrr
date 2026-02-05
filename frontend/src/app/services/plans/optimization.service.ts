import { Injectable, OnDestroy } from '@angular/core';
import * as ActionCable from 'actioncable';
import { getApiBaseUrl } from '../../core/api-base-url';

export interface ActionCableMessage {
  [key: string]: any;
}

export type ActionCableCallback = (data: ActionCableMessage) => void;

@Injectable({ providedIn: 'root' })
export class OptimizationService implements OnDestroy {
  private consumer: ActionCable.Cable | null = null;

  private getConsumer(): ActionCable.Cable {
    if (!this.consumer) {
      const baseUrl = getApiBaseUrl() || window.location.origin;
      const wsUrl = `${baseUrl.replace(/^http/, 'ws')}/cable`;
      console.debug('[OptimizationService] Creating consumer', wsUrl);
      // actioncable の createConsumer は IIFE の this に依存するため、Consumer を直接 new する
      this.consumer = new (ActionCable as any).Consumer(wsUrl);
    }
    return this.consumer as ActionCable.Cable;
  }

  subscribe(channel: string, params: Record<string, unknown>, callbacks: {
    received: ActionCableCallback;
    connected?: () => void;
    disconnected?: () => void;
    rejected?: () => void;
  }): ActionCable.Channel {
    const consumer = this.getConsumer();
    console.debug('[OptimizationService] Subscribing', { channel, params });
    const subscriptionTag = `[OptimizationChannel][${channel}]`;
    const { received, connected, disconnected, rejected } = callbacks;
    return consumer.subscriptions.create(
      { channel, ...params },
      {
        received: payload => {
          console.debug(`${subscriptionTag} received`, payload);
          received(payload);
        },
        connected: () => {
          console.debug(`${subscriptionTag} connected`);
          connected?.();
        },
        disconnected: () => {
          console.warn(`${subscriptionTag} disconnected`);
          disconnected?.();
        },
        rejected: () => {
          console.error(`${subscriptionTag} rejected`);
          rejected?.();
        }
      }
    );
  }

  ngOnDestroy(): void {
    if (this.consumer) {
      this.consumer.disconnect();
    }
  }
}
