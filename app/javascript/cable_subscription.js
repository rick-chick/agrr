// app/javascript/cable_subscription.js
// Action Cable サブスクリプション管理

import { createConsumer } from "@rails/actioncable"

class CableSubscriptionManager {
  constructor() {
    this.consumer = null;
    this.subscriptions = new Map();
  }

  // コンシューマーを初期化
  getConsumer() {
    if (!this.consumer) {
      // localeスコープを考慮したWebSocket URLを動的に生成
      const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const host = window.location.host;
      const locale = document.documentElement.lang || 'ja';
      const cableUrl = `${protocol}//${host}/${locale}/cable`;
      
      console.log(`📡 [Cable] Connecting to: ${cableUrl}`);
      this.consumer = createConsumer(cableUrl);
    }
    return this.consumer;
  }

  // 最適化チャンネルに接続
  subscribeToOptimization(cultivationPlanId, callbacks, options = {}) {
    const channelName = options.channelName || "OptimizationChannel";
    const subscriptionKey = `optimization_${channelName}_${cultivationPlanId}`;
    
    // 既に購読している場合は何もしない
    if (this.subscriptions.has(subscriptionKey)) {
      console.log(`📡 Already subscribed to optimization channel: plan_id=${cultivationPlanId}`);
      return this.subscriptions.get(subscriptionKey);
    }

    console.log(`📡 Subscribing to optimization channel: channel=${channelName} plan_id=${cultivationPlanId}`);

    // チャンネル名に応じて正しいチャンネル設定を使用
    let channelConfig;
    if (channelName === "PlansOptimizationChannel") {
      channelConfig = {
        channel: "PlansOptimizationChannel",
        cultivation_plan_id: cultivationPlanId
      };
    } else {
      channelConfig = {
        channel: channelName,
        cultivation_plan_id: cultivationPlanId
      };
    }

    const subscription = this.getConsumer().subscriptions.create(
      channelConfig,
      {
        connected() {
          console.log(`✅ Connected to optimization channel: channel=${channelName} plan_id=${cultivationPlanId}`);
          if (callbacks.onConnected) callbacks.onConnected();
        },

        disconnected() {
          console.log(`🔌 Disconnected from optimization channel: channel=${channelName} plan_id=${cultivationPlanId}`);
          if (callbacks.onDisconnected) callbacks.onDisconnected();
        },

        received(data) {
          console.log(`📬 Received data from optimization channel (${channelName}):`, data);
          if (callbacks.onReceived) callbacks.onReceived(data);
        }
      }
    );

    this.subscriptions.set(subscriptionKey, subscription);
    return subscription;
  }

  // 予測チャンネルに接続
  subscribeToPrediction(farmId, callbacks) {
    const subscriptionKey = `prediction_${farmId}`;
    
    // 既に購読している場合は何もしない
    if (this.subscriptions.has(subscriptionKey)) {
      console.log(`📡 Already subscribed to prediction channel: farm_id=${farmId}`);
      return this.subscriptions.get(subscriptionKey);
    }

    console.log(`📡 Subscribing to prediction channel: farm_id=${farmId}`);

    const subscription = this.getConsumer().subscriptions.create(
      {
        channel: "PredictionChannel",
        farm_id: farmId
      },
      {
        connected() {
          console.log(`✅ Connected to prediction channel: farm_id=${farmId}`);
          if (callbacks.onConnected) callbacks.onConnected();
        },

        disconnected() {
          console.log(`🔌 Disconnected from prediction channel: farm_id=${farmId}`);
          if (callbacks.onDisconnected) callbacks.onDisconnected();
        },

        received(data) {
          console.log(`📬 Received data from prediction channel:`, data);
          if (callbacks.onReceived) callbacks.onReceived(data);
        }
      }
    );

    this.subscriptions.set(subscriptionKey, subscription);
    return subscription;
  }

  // 購読を解除
  unsubscribe(cultivationPlanId, options = {}) {
    const channelName = options.channelName || "OptimizationChannel";
    const subscriptionKey = `optimization_${channelName}_${cultivationPlanId}`;
    const subscription = this.subscriptions.get(subscriptionKey);
    
    if (subscription) {
      console.log(`🔌 Unsubscribing from optimization channel: channel=${channelName} plan_id=${cultivationPlanId}`);
      subscription.unsubscribe();
      this.subscriptions.delete(subscriptionKey);
    }
  }

  // 全ての購読を解除
  unsubscribeAll() {
    console.log(`🔌 Unsubscribing from all channels`);
    this.subscriptions.forEach((subscription) => {
      subscription.unsubscribe();
    });
    this.subscriptions.clear();
  }
}

// グローバルなインスタンスを作成
window.CableSubscriptionManager = new CableSubscriptionManager();

export default window.CableSubscriptionManager;

