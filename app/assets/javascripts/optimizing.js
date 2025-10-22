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
  
  function initOptimizingWebSocket() {
    // 最適化画面の要素を確認
    const container = document.querySelector('[data-optimizing-container]');
    
    if (!container) {
      console.log('ℹ️ [Optimizing] Not on optimizing page, skipping WebSocket connection');
      cleanupSubscription();
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
      console.error('❌ [Optimizing] cultivation_plan_id not found');
      return;
    }
    
    if (!redirectUrl) {
      console.error('❌ [Optimizing] redirect_url not found');
      return;
    }

    if (!channelName) {
      console.error('❌ [Optimizing] data-channel-name not found on optimizing container');
      // フォールバックせず即時エラーとし、誤接続を防ぐ
      return;
    }
    
    // 既に同じplan_idで接続している場合はスキップ
    if (currentPlanId === cultivationPlanId && subscription) {
      console.log('ℹ️ [Optimizing] Already connected to plan:', cultivationPlanId);
      return;
    }
    
    console.log(`🔌 [Optimizing] Connecting to ${channelName} for plan:`, cultivationPlanId);
    currentPlanId = cultivationPlanId;
    
    // 既存の購読があれば解除
    if (subscription) {
      subscription.unsubscribe();
      subscription = null;
    }
    
    // フォールバックタイマー設定（30秒後にポーリングに戻る）
    setupFallback();
    
    // 経過時間タイマーを開始
    startElapsedTimer();
    
    // ActionCableに購読（グローバルに利用可能）
    if (typeof ActionCable === 'undefined') {
      console.error('❌ [Optimizing] ActionCable is not loaded');
      return;
    }
    
    const consumer = ActionCable.createConsumer();
    subscription = consumer.subscriptions.create(
      { 
        channel: channelName,
        cultivation_plan_id: cultivationPlanId
      },
      {
        connected() {
          console.log(`✅ [Optimizing] Connected to ${channelName}`);
          // タイムアウトタイマーをクリア
          if (fallbackTimer) {
            clearTimeout(fallbackTimer);
            fallbackTimer = null;
          }
        },
        
        disconnected() {
          console.log(`❌ [Optimizing] Disconnected from ${channelName}`);
          // 30秒後にフォールバック
          setupFallback();
        },
        
        rejected() {
          console.error(`❌ [Optimizing] Connection rejected by ${channelName}`);
          console.error('🔍 [Optimizing] Debug: cultivation_plan_id =', cultivationPlanId);
          
          // 開発環境でのデバッグ情報
          if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            console.error('⚠️ [Optimizing] Development mode: This might be a session/auth mismatch issue');
            console.error('💡 [Optimizing] Check server logs for detailed information');
          }
          
          // エラーメッセージを表示（data属性から取得）
          const errorMessage = container.dataset.errorMessage || 
            'Failed to fetch optimization status.\n\nPlease try:\n• Reload page (F5)\n• Clear browser cache\n• Wait a moment and try again\n\nIf the problem persists, please create a new plan.';
          
          alert(errorMessage);
          
          // 5秒後に自動リロード
          setTimeout(() => {
            console.log('🔄 Auto-reloading page...');
            window.location.reload();
          }, 5000);
        },
        
        received(data) {
          console.log('📨 [Optimizing] Received data:', JSON.stringify(data, null, 2));
          
          // フェーズメッセージを更新
          if (data.phase_message) {
            updatePhaseMessage(data.phase_message, data.status === 'failed');
          }
          
          // プログレスバーを更新
          if (data.progress !== undefined) {
            updateProgressBar(data.progress);
          }
          
          // ステータスに応じて処理
          if (data.status === 'completed') {
            handleCompleted(redirectUrl);
          } else if (data.status === 'failed') {
            handleFailed(data);
          } else if (data.status === 'adjusted') {
            // adjusted は結果ページでのみ処理（custom_gantt_chart.js）
            console.log('ℹ️ [Optimizing] Received adjusted status (ignored on optimizing page)');
          }
        }
      }
    );
  }
  
  // フェーズメッセージを更新
  function updatePhaseMessage(message, isError = false) {
    // public_plans用
    const phaseMessageElement = document.getElementById('phase-message');
    if (phaseMessageElement) {
      phaseMessageElement.textContent = message;
      if (isError) {
        phaseMessageElement.classList.add('error');
      } else {
        phaseMessageElement.classList.remove('error');
      }
    }
    
    // plans用
    const progressMessageElement = document.getElementById('progressMessage');
    if (progressMessageElement) {
      progressMessageElement.textContent = message;
      if (isError) {
        progressMessageElement.style.color = 'var(--color-danger)';
      } else {
        progressMessageElement.style.color = '';
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
            timeStr = minuteTemplate.replace('%{minutes}', minutes).replace('%{seconds}', seconds);
          } else {
            timeStr = `${minutes}:${String(seconds).padStart(2, '0')}`;
          }
        } else {
          timeStr = seconds.toString();
        }
        
        elapsedTimeElementPublic.textContent = template.replace('%{time}', timeStr);
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
    if (subscription) {
      subscription.unsubscribe();
      subscription = null;
    }
    startTime = null;
    currentPlanId = null;
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

