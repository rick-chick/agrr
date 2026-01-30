import { Injectable, OnDestroy } from '@angular/core';
import { createConsumer, Cable, Channel } from 'actioncable';
import { getApiBaseUrl } from '../../core/api-base-url';

export interface ActionCableMessage {
  [key: string]: any;
}

export type ActionCableCallback = (data: ActionCableMessage) => void;

@Injectable({ providedIn: 'root' })
export class OptimizationService implements OnDestroy {
  private consumer: Cable | null = null;

  private getConsumer(): Cable {
    if (!this.consumer) {
      const baseUrl = getApiBaseUrl() || window.location.origin;
      const wsUrl = `${baseUrl.replace(/^http/, 'ws')}/cable`;
      this.consumer = createConsumer(wsUrl);
    }
    return this.consumer;
  }

  subscribe(channel: string, params: Record<string, unknown>, callbacks: {
    received: ActionCableCallback;
    connected?: () => void;
    disconnected?: () => void;
    rejected?: () => void;
  }): Channel {
    const consumer = this.getConsumer();
    return consumer.subscriptions.create(
      { channel, ...params },
      {
        received: callbacks.received,
        connected: callbacks.connected,
        disconnected: callbacks.disconnected,
        rejected: callbacks.rejected
      }
    );
  }

  ngOnDestroy(): void {
    if (this.consumer) {
      this.consumer.disconnect();
    }
  }
}
