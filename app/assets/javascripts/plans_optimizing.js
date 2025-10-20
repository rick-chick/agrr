// app/assets/javascripts/plans_optimizing.js
// 最適化進捗画面のWebSocket接続と進捗表示

document.addEventListener('turbo:load', function() {
  // 最適化画面でのみ実行
  const container = document.querySelector('.optimizing-card');
  if (!container) {
    console.log('ℹ️ Not on optimizing page, skipping WebSocket connection');
    return;
  }
  
  const planId = container.dataset.planId;
  const redirectUrl = container.dataset.redirectUrl;
  
  if (!planId || !redirectUrl) {
    console.error('❌ Missing plan ID or redirect URL');
    return;
  }
  
  const startTime = Date.now();
  let timerInterval = null;
  let subscription = null;
  
  // 経過時間を更新
  function updateElapsedTime() {
    const elapsed = Math.floor((Date.now() - startTime) / 1000);
    const minutes = Math.floor(elapsed / 60);
    const seconds = elapsed % 60;
    
    const elapsedTimeEl = document.getElementById('elapsedTime');
    if (!elapsedTimeEl) return;
    
    if (minutes > 0) {
      // 分と秒で表示
      const template = elapsedTimeEl.dataset.templateMinute || '%{minutes}分%{seconds}秒';
      elapsedTimeEl.textContent = template
        .replace('%{minutes}', minutes)
        .replace('%{seconds}', seconds.toString().padStart(2, '0'));
    } else {
      // 秒のみ表示
      const template = elapsedTimeEl.dataset.templateSecond || '⏳ %{time}秒';
      elapsedTimeEl.textContent = template.replace('%{time}', elapsed);
    }
  }
  
  // 1秒ごとに経過時間を更新
  timerInterval = setInterval(updateElapsedTime, 1000);
  
  // WebSocket接続
  const consumer = ActionCable.createConsumer();
  subscription = consumer.subscriptions.create(
    {
      channel: "OptimizationChannel",
      cultivation_plan_id: planId
    },
    {
      received(data) {
        console.log('📡 Optimization update:', data);
        
        // プログレスバー更新
        if (data.progress !== undefined) {
          const progressBar = document.getElementById('progressBar');
          const progressPercentage = document.getElementById('progressPercentage');
          if (progressBar) progressBar.style.width = data.progress + '%';
          if (progressPercentage) progressPercentage.textContent = data.progress + '%';
        }
        
        // メッセージ更新
        if (data.phase_message) {
          const progressMessage = document.getElementById('progressMessage');
          if (progressMessage) progressMessage.textContent = data.phase_message;
        }
        
        // 完了時のリダイレクト
        if (data.status === 'completed') {
          clearInterval(timerInterval);
          console.log('✅ Optimization completed, redirecting...');
          setTimeout(() => {
            window.location.href = redirectUrl;
          }, 1000);
        }
        
        // エラー時の表示
        if (data.status === 'failed') {
          clearInterval(timerInterval);
          const msgEl = document.getElementById('progressMessage');
          if (msgEl) {
            msgEl.textContent = msgEl.dataset.errorTitle || '計画作成に失敗しました';
            msgEl.style.color = 'var(--color-danger)';
          }
        }
      }
    }
  );
  
  console.log('✅ Plans optimizing WebSocket initialized for plan:', planId);
  
  // クリーンアップ
  document.addEventListener('turbo:before-cache', () => {
    if (timerInterval) clearInterval(timerInterval);
    if (subscription) subscription.unsubscribe();
  });
  
  window.addEventListener('beforeunload', () => {
    if (timerInterval) clearInterval(timerInterval);
    if (subscription) subscription.unsubscribe();
  });
});

