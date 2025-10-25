// app/assets/javascripts/optimizing.js
// 最適化進捗画面の共通WebSocket接続スクリプト
// Plans（認証ユーザー）とPublic Plans（匿名ユーザー）の両方に対応

(function() {
  console.log('🔌 [Optimizing] WebSocket script loading');
  
  let subscription = null;
  let fallbackTimer = null;
  let elapsedTimer = null;
  let startTime = null;
  let currentPlanId = null;
  let cableManagerWaitCount = 0;
  
  function initOptimizingWebSocket() {
    // 最適化画面の要素を確認
    const container = document.querySelector('[data-optimizing-container]');
    
    if (!container) {
      if (window.ClientLogger) {
        window.ClientLogger.log('info', 'ℹ️ [Optimizing] Not on optimizing page, skipping WebSocket connection');
      }
      cleanupSubscription();
      return;
    }
    
    // CableSubscriptionManagerの読み込みを待つ（最大50回、5秒間）
    if (typeof window.CableSubscriptionManager === 'undefined') {
      cableManagerWaitCount++;
      if (cableManagerWaitCount > 50) {
        if (window.ClientLogger) {
          window.ClientLogger.log('error', '❌ [Optimizing] CableSubscriptionManager failed to load after 5 seconds');
        }
        return;
      }
      if (window.ClientLogger) {
        window.ClientLogger.log('info', `⏳ [Optimizing] Waiting for CableSubscriptionManager to load... (${cableManagerWaitCount}/50)`);
      }
      setTimeout(initOptimizingWebSocket, 100);
      return;
    }
    
    // 結果ページでは実行しない（custom_gantt_chart.jsが管理）
    const isResultsPage = window.location.pathname.includes('/results') || 
                          document.querySelector('.gantt-chart-container');
    if (isResultsPage) {
      console.log('ℹ️ [Optimizing] On results page, skipping WebSocket');
      cleanupSubscription();
      return;
    }
    
    // cultivation_plan_id と channel_name を取得
    const cultivationPlanId = container.dataset.cultivationPlanId;
    const channelName = container.dataset.channelName;
    const redirectUrl = container.dataset.redirectUrl;
    
    if (!cultivationPlanId) {
      if (window.ClientLogger) {
        window.ClientLogger.log('error', '❌ [Optimizing] cultivation_plan_id not found');
      }
      return;
    }
    
    if (!redirectUrl) {
      if (window.ClientLogger) {
        window.ClientLogger.log('error', '❌ [Optimizing] redirect_url not found');
      }
      return;
    }

    if (!channelName) {
      if (window.ClientLogger) {
        window.ClientLogger.log('error', '❌ [Optimizing] data-channel-name not found on optimizing container');
      }
      // フォールバックせず即時エラーとし、誤接続を防ぐ
      return;
    }
    
    // 既に同じplan_idで接続している場合はスキップ
    if (currentPlanId === cultivationPlanId && subscription) {
      if (window.ClientLogger) {
        window.ClientLogger.log('info', `ℹ️ [Optimizing] Already connected to plan: ${cultivationPlanId}`);
      }
      return;
    }
    
    if (window.ClientLogger) {
      window.ClientLogger.log('info', `🔌 [Optimizing] Connecting to ${channelName} for plan: ${cultivationPlanId}`);
    }
    currentPlanId = cultivationPlanId;
    
    // 既存の購読があれば解除
    if (subscription && window.CableSubscriptionManager) {
      const oldChannelName = channelName; // 現在のchannelNameを使用
      window.CableSubscriptionManager.unsubscribe(cultivationPlanId, { channelName: oldChannelName });
      subscription = null;
    }
    
    // フォールバックタイマー設定（30秒後にポーリングに戻る）
    setupFallback();
    
    // 経過時間タイマーを開始
    startElapsedTimer();
    
    // CableSubscriptionManagerがグローバルで利用可能であることを確認
    if (typeof window.CableSubscriptionManager === 'undefined') {
      console.error('❌ [Optimizing] CableSubscriptionManager is not loaded');
      return;
    }
    
    // CableSubscriptionManagerを使ってサブスクリプションを作成
    subscription = window.CableSubscriptionManager.subscribeToOptimization(
      cultivationPlanId,
      {
        onConnected: () => {
          if (window.ClientLogger) {
            window.ClientLogger.log('info', `✅ [Optimizing] Connected to ${channelName}`);
          }
          // タイムアウトタイマーをクリア
          if (fallbackTimer) {
            clearTimeout(fallbackTimer);
            fallbackTimer = null;
          }
        },
        
        onDisconnected: () => {
          if (window.ClientLogger) {
            window.ClientLogger.log('warn', `❌ [Optimizing] Disconnected from ${channelName}`);
          }
          // 30秒後にフォールバック
          setupFallback();
        },
        
        onReceived: (data) => {
          // サーバーログ通知機能を使用
          if (window.ClientLogger) {
            window.ClientLogger.log('info', `📨 [Optimizing] Received data: ${JSON.stringify(data, null, 2)}`);
            window.ClientLogger.log('info', `📨 [Optimizing] Data type: ${typeof data}`);
            window.ClientLogger.log('info', `📨 [Optimizing] Data keys: ${Object.keys(data).join(', ')}`);
          }
          
          // リダイレクト通知を処理
          if (data.type === 'redirect') {
            if (window.ClientLogger) {
              window.ClientLogger.log('info', `🔄 [Optimizing] Received redirect notification: ${data.redirect_path}`);
            }
            handleCompleted(data.redirect_path);
            return;
          }
          
          // フェーズメッセージを更新
          if (data.phase_message) {
            if (window.ClientLogger) {
              window.ClientLogger.log('info', `📝 [Optimizing] Updating phase message: ${data.phase_message}`);
            }
            updatePhaseMessage(data.phase_message, data.status === 'failed');
          } else {
            if (window.ClientLogger) {
              window.ClientLogger.log('warn', '⚠️ [Optimizing] No phase_message in data');
            }
          }
          
          // プログレスバーを更新
          if (data.progress !== undefined) {
            if (window.ClientLogger) {
              window.ClientLogger.log('info', `📊 [Optimizing] Updating progress: ${data.progress}`);
            }
            updateProgressBar(data.progress);
          }
          
          // ステータスに応じて処理
          if (data.status === 'completed') {
            handleCompleted(redirectUrl);
          } else if (data.status === 'failed') {
            handleFailed(data);
          } else if (data.status === 'adjusted') {
            // adjusted は結果ページでのみ処理（custom_gantt_chart.js）
            if (window.ClientLogger) {
              window.ClientLogger.log('info', 'ℹ️ [Optimizing] Received adjusted status (ignored on optimizing page)');
            }
          }
        }
      },
      { channelName }
    );
  }
  
  // フェーズメッセージを更新
  function updatePhaseMessage(message, isError = false) {
    // サーバーログ通知機能を使用（フォールバック付き）
    if (window.ClientLogger) {
      window.ClientLogger.log('info', `📝 [Optimizing] updatePhaseMessage called: ${message}, isError: ${isError}`);
    } else {
      console.log(`📝 [Optimizing] updatePhaseMessage called: ${message}, isError: ${isError}`);
    }
    
    // public_plans用
    const phaseMessageElement = document.getElementById('phase-message');
    if (window.ClientLogger) {
      window.ClientLogger.log('info', `📝 [Optimizing] phase-message element: ${phaseMessageElement ? 'found' : 'not found'}`);
    } else {
      console.log(`📝 [Optimizing] phase-message element: ${phaseMessageElement ? 'found' : 'not found'}`);
    }
    if (phaseMessageElement) {
      if (window.ClientLogger) {
        window.ClientLogger.log('info', `📝 [Optimizing] Updating phase-message element with: ${message}`);
      } else {
        console.log(`📝 [Optimizing] Updating phase-message element with: ${message}`);
      }
      phaseMessageElement.textContent = message;
      if (isError) {
        phaseMessageElement.classList.add('error');
      } else {
        phaseMessageElement.classList.remove('error');
      }
    } else {
      if (window.ClientLogger) {
        window.ClientLogger.log('warn', '⚠️ [Optimizing] phase-message element not found');
      } else {
        console.warn('⚠️ [Optimizing] phase-message element not found');
      }
    }
    
    // plans用
    const progressMessageElement = document.getElementById('progressMessage');
    if (window.ClientLogger) {
      window.ClientLogger.log('info', `📝 [Optimizing] progressMessage element: ${progressMessageElement ? 'found' : 'not found'}`);
    } else {
      console.log(`📝 [Optimizing] progressMessage element: ${progressMessageElement ? 'found' : 'not found'}`);
    }
    if (progressMessageElement) {
      if (window.ClientLogger) {
        window.ClientLogger.log('info', `📝 [Optimizing] Updating progressMessage element with: ${message}`);
      } else {
        console.log(`📝 [Optimizing] Updating progressMessage element with: ${message}`);
      }
      progressMessageElement.textContent = message;
      if (isError) {
        progressMessageElement.style.color = 'var(--color-danger)';
      } else {
        progressMessageElement.style.color = '';
      }
    } else {
      if (window.ClientLogger) {
        window.ClientLogger.log('info', 'ℹ️ [Optimizing] progressMessage element not found (this is normal for public plans)');
      } else {
        console.log('ℹ️ [Optimizing] progressMessage element not found (this is normal for public plans)');
      }
    }
  }
  
  // プログレスバーを更新
  function updateProgressBar(progress) {
    const progressBar = document.getElementById('progressBar');
    const progressPercentage = document.getElementById('progressPercentage');
    
    if (progressBar) progressBar.style.width = progress + '%';
    if (progressPercentage) progressPercentage.textContent = progress + '%';
  }
  
  // 完了時の処理
  function handleCompleted(redirectUrl) {
    console.log('✅ [Optimizing] Optimization completed! Redirecting...');
    
    // スピナーを非表示
    const spinner = document.getElementById('loading-spinner');
    if (spinner) {
      spinner.classList.add('hidden');
    }
    
    // タイマーを停止
    if (elapsedTimer) {
      clearInterval(elapsedTimer);
      elapsedTimer = null;
    }
    
    // 結果画面へリダイレクト
    setTimeout(() => {
      console.log('🚀 [Optimizing] Redirecting to:', redirectUrl);
      window.location.href = redirectUrl;
    }, 500);
  }
  
  // 失敗時の処理
  function handleFailed(data) {
    console.error('❌ [Optimizing] Optimization failed:', data.phase_message);
    
    // タイマーを停止
    if (elapsedTimer) {
      clearInterval(elapsedTimer);
      elapsedTimer = null;
    }
    
    // public_plans用のUI要素を更新
    const spinner = document.getElementById('loading-spinner');
    if (spinner) {
      spinner.classList.add('hidden');
    }
    
    const durationHint = document.getElementById('progress-duration-hint');
    if (durationHint) {
      durationHint.style.display = 'none';
    }
    
    const elapsedTime = document.getElementById('elapsed-time');
    if (elapsedTime) {
      elapsedTime.style.display = 'none';
    }
    
    // エラーメッセージエリアを表示（public_plans用）
    const errorContainer = document.getElementById('error-message-container');
    const errorDetail = document.getElementById('error-detail');
    
    if (errorContainer && errorDetail) {
      errorDetail.textContent = data.phase_message || data.message || '不明なエラーが発生しました。';
      errorContainer.style.display = 'flex';
    }
    
    // plans用のUI要素を更新
    const progressMessageElement = document.getElementById('progressMessage');
    if (progressMessageElement) {
      const errorTitle = progressMessageElement.dataset.errorTitle || '計画作成に失敗しました';
      progressMessageElement.textContent = errorTitle;
      progressMessageElement.style.color = 'var(--color-danger)';
    }
  }
  
  // フォールバック機能（WebSocket接続失敗時にリロード）
  function setupFallback() {
    if (fallbackTimer) {
      clearTimeout(fallbackTimer);
    }
    fallbackTimer = setTimeout(() => {
      console.warn('⚠️ [Optimizing] WebSocket timeout, reloading page');
      window.location.reload();
    }, 30000); // 30秒
  }
  
  // 経過時間タイマーを開始
  function startElapsedTimer() {
    // public_plans用とplans用の両方の要素を取得
    const elapsedTimeElementPublic = document.getElementById('elapsed-time');
    const elapsedTimeElementPlans = document.getElementById('elapsedTime');
    
    // どちらも存在しない場合は何もしない
    if (!elapsedTimeElementPublic && !elapsedTimeElementPlans) return;
    
    // タイマーが既に動いている場合は、startTimeをリセットしない
    if (!startTime) {
      startTime = Date.now();
    }
    
    // 既存のタイマーがあればクリア
    if (elapsedTimer) {
      clearInterval(elapsedTimer);
    }
    
    // 1秒ごとに経過時間を更新
    elapsedTimer = setInterval(() => {
      const elapsed = Math.floor((Date.now() - startTime) / 1000);
      const minutes = Math.floor(elapsed / 60);
      const seconds = elapsed % 60;
      
      // public_plans用の要素を更新
      if (elapsedTimeElementPublic) {
        const template = elapsedTimeElementPublic.dataset.elapsedTimeTemplate || '⏳ %{time}';
        let timeStr = '';
        
        if (minutes > 0) {
          const minuteTemplate = elapsedTimeElementPublic.dataset.elapsedTimeMinuteTemplate;
          if (minuteTemplate) {
            elapsedTimeElementPublic.textContent = minuteTemplate.replace('%{minutes}', minutes).replace('%{seconds}', seconds);
          } else {
            elapsedTimeElementPublic.textContent = `${minutes}:${String(seconds).padStart(2, '0')}`;
          }
        } else {
          elapsedTimeElementPublic.textContent = template.replace('%{time}', seconds.toString());
        }
      }
      
      // plans用の要素を更新
      if (elapsedTimeElementPlans) {
        if (minutes > 0) {
          const template = elapsedTimeElementPlans.dataset.templateMinute || '%{minutes}分%{seconds}秒';
          elapsedTimeElementPlans.textContent = template
            .replace('%{minutes}', minutes)
            .replace('%{seconds}', seconds.toString().padStart(2, '0'));
        } else {
          const template = elapsedTimeElementPlans.dataset.templateSecond || '⏳ %{time}秒';
          elapsedTimeElementPlans.textContent = template.replace('%{time}', elapsed);
        }
      }
    }, 1000);
  }
  
  // ページ離脱時に購読を解除
  function cleanupSubscription() {
    if (fallbackTimer) {
      clearTimeout(fallbackTimer);
      fallbackTimer = null;
    }
    if (elapsedTimer) {
      clearInterval(elapsedTimer);
      elapsedTimer = null;
    }
    if (subscription && window.CableSubscriptionManager) {
      const container = document.querySelector('[data-optimizing-container]');
      if (container) {
        const cultivationPlanId = container.dataset.cultivationPlanId;
        const channelName = container.dataset.channelName;
        window.CableSubscriptionManager.unsubscribe(cultivationPlanId, { channelName });
      }
      subscription = null;
    }
    startTime = null;
    currentPlanId = null;
    cableManagerWaitCount = 0;
  }
  
  // Turboのページ遷移時に実行
  document.addEventListener('turbo:load', initOptimizingWebSocket);
  
  // ページ離脱時にクリーンアップ
  document.addEventListener('turbo:before-visit', cleanupSubscription);
  document.addEventListener('turbo:before-cache', cleanupSubscription);
  window.addEventListener('beforeunload', cleanupSubscription);
  
  // 既にロード済みの場合は即座に実行
  if (document.readyState !== 'loading') {
    initOptimizingWebSocket();
  }
})();

