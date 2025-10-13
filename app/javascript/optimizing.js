// 最適化画面の自動リロードスクリプト
(function() {
  console.log('🔄 Optimizing script loading');
  
  function initOptimizingReload() {
    // optimizing.html.erb以外のページでは実行しない
    const isOptimizingPage = document.querySelector('.status-badge.optimizing');
    
    if (!isOptimizingPage) {
      return;
    }
    
    console.log('Optimizing page detected. Will reload in 3 seconds.');
    
    // 3秒後に自動リロード
    setTimeout(function() {
      window.location.reload();
    }, 3000);
  }
  
  // DOMが既にロードされている場合は即座に実行、そうでなければイベントを待つ
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initOptimizingReload);
  } else {
    initOptimizingReload();
  }
  
  document.addEventListener('turbo:load', initOptimizingReload);
  window.addEventListener('load', initOptimizingReload);
})();

