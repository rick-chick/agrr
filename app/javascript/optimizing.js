// 最適化画面のWebSocket接続スクリプト
import { createConsumer } from "@rails/actioncable"

(function() {
  console.log('🔌 Optimizing WebSocket script loading');
  
  let consumer = null;
  let subscription = null;
  let fallbackTimer = null;
  let elapsedTimer = null;
  let startTime = null;
  let currentPlanId = null;  // 現在接続中のplan_idを記録
  
  function initOptimizingWebSocket() {
    // optimizing.html.erb以外のページでは実行しない
    const isOptimizingPage = document.querySelector('.status-badge.optimizing');
    
    if (!isOptimizingPage) {
      cleanupSubscription();
      return;
    }
    
    // cultivation_plan_idを取得
    const cultivationPlanId = document.querySelector('[data-cultivation-plan-id]')?.dataset.cultivationPlanId;
    
    if (!cultivationPlanId) {
      console.error('❌ cultivation_plan_id not found');
      return;
    }
    
    // 既に同じplan_idで接続している場合はスキップ
    if (currentPlanId === cultivationPlanId && subscription) {
      console.log('ℹ️ Already connected to plan:', cultivationPlanId);
      return;
    }
    
    console.log('🔌 Connecting to OptimizationChannel for plan:', cultivationPlanId);
    currentPlanId = cultivationPlanId;
    
    // コンシューマーを再利用
    if (!consumer) {
      consumer = createConsumer();
    }
    
    // 既存の購読があれば解除
    if (subscription) {
      subscription.unsubscribe();
      subscription = null;
    }
    
    // フォールバックタイマー設定（30秒後にポーリングに戻る）
    setupFallback();
    
    // 経過時間タイマーを開始
    startElapsedTimer();
    
    // OptimizationChannelに購読
    subscription = consumer.subscriptions.create(
      { 
        channel: "OptimizationChannel",
        cultivation_plan_id: cultivationPlanId
      },
      {
        connected() {
          console.log('✅ Connected to OptimizationChannel');
          // タイムアウトタイマーをクリア
          if (fallbackTimer) {
            clearTimeout(fallbackTimer);
            fallbackTimer = null;
          }
        },
        
        disconnected() {
          console.log('❌ Disconnected from OptimizationChannel');
          // 30秒後にフォールバック
          setupFallback();
        },
        
        rejected() {
          console.error('❌ Connection rejected');
          console.error('🔍 Debug: cultivation_plan_id =', cultivationPlanId);
          
          // 開発環境でのデバッグ情報
          if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            console.error('⚠️ Development mode: This might be a session ID mismatch issue');
            console.error('💡 Check server logs for detailed information');
          }
          
          // より詳細で親切なエラーメッセージ
          const message = [
            '最適化状況の取得に失敗しました。',
            '',
            '以下のいずれかをお試しください：',
            '• ページをリロード（F5キー）',
            '• ブラウザのキャッシュをクリア',
            '• しばらく時間をおいてから再度アクセス',
            '',
            '問題が解決しない場合は、新しい計画を作成してください。'
          ].join('\n');
          
          alert(message);
          
          // 5秒後に自動リロード（ユーザーが閉じない場合）
          setTimeout(() => {
            console.log('🔄 Auto-reloading page...');
            window.location.reload();
          }, 5000);
        },
        
        received(data) {
          console.log('📨 Received data:', JSON.stringify(data, null, 2));
          console.log('📊 Status:', data.status, '(type:', typeof data.status, ')');
          console.log('📝 Phase:', data.phase);
          console.log('💬 Phase message:', data.phase_message);
          
          // フェーズメッセージを更新
          if (data.phase_message) {
            const phaseMessageElement = document.getElementById('phase-message');
            if (phaseMessageElement) {
              phaseMessageElement.textContent = data.phase_message;
              // エラー時はクラスを追加
              if (data.status === 'failed') {
                phaseMessageElement.classList.add('error');
              } else {
                phaseMessageElement.classList.remove('error');
              }
            }
          }
          
          console.log('🔍 Checking status...');
          if (data.status === 'completed') {
            console.log('✅ Optimization completed! Redirecting to results...');
            // スピナーを非表示
            const spinner = document.getElementById('loading-spinner');
            if (spinner) {
              spinner.classList.add('hidden');
            }
            // 結果画面へリダイレクト
            setTimeout(() => {
              console.log('🚀 Redirecting now...');
              window.location.href = '/public_plans/results';
            }, 500);
          } else if (data.status === 'failed') {
            console.error('❌ Optimization failed:', data.message);
            // スピナーを非表示
            const spinner = document.getElementById('loading-spinner');
            if (spinner) {
              spinner.classList.add('hidden');
            }
            // アラートは表示せず、画面上にエラーを表示
          } else {
            console.log('ℹ️ Status is not completed or failed:', data.status);
          }
        }
      }
    );
  }
  
  // フォールバック機能（WebSocket接続失敗時にポーリングに戻る）
  function setupFallback() {
    if (fallbackTimer) {
      clearTimeout(fallbackTimer);
    }
    fallbackTimer = setTimeout(() => {
      console.warn('⚠️ WebSocket timeout, falling back to polling');
      window.location.reload();
    }, 30000); // 30秒
  }
  
  // 経過時間タイマーを開始
  function startElapsedTimer() {
    const elapsedTimeElement = document.getElementById('elapsed-time');
    if (!elapsedTimeElement) return;
    
    startTime = Date.now();
    
    // 既存のタイマーがあればクリア
    if (elapsedTimer) {
      clearInterval(elapsedTimer);
    }
    
    // 1秒ごとに経過時間を更新
    elapsedTimer = setInterval(() => {
      const elapsed = Math.floor((Date.now() - startTime) / 1000);
      const minutes = Math.floor(elapsed / 60);
      const seconds = elapsed % 60;
      
      if (minutes > 0) {
        elapsedTimeElement.textContent = `${minutes}分${seconds}秒`;
      } else {
        elapsedTimeElement.textContent = `${seconds}秒`;
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
    if (consumer) {
      consumer.disconnect();
      consumer = null;
    }
    currentPlanId = null;  // リセット
  }
  
  // DOMが既にロードされている場合は即座に実行
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initOptimizingWebSocket);
  } else {
    initOptimizingWebSocket();
  }
  
  // Turboのページ遷移時にも実行
  document.addEventListener('turbo:load', initOptimizingWebSocket);
  
  // ページ離脱時にクリーンアップ
  document.addEventListener('turbo:before-visit', cleanupSubscription);
  window.addEventListener('beforeunload', cleanupSubscription);
})();

