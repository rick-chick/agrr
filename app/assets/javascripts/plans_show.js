// app/assets/javascripts/plans_show.js
// 計画詳細画面のガントチャート表示
// custom_gantt_chart.jsと連携して動作します

function initializePlansShow() {
  console.log('🔍 [Plans Show] initializePlansShow 呼び出し開始');
  // ガントチャートコンテナがあるときのみ実行
  const chartContainer = document.getElementById('gantt-chart-container');
  if (!chartContainer) {
    console.log('ℹ️ [Plans Show] Not on plans show page, skipping chart initialization');
    return;
  }
  console.log('✅ [Plans Show] Chart container found');
  
  const planId = chartContainer.dataset.cultivationPlanId;
  const dataUrl = chartContainer.dataset.dataUrl;
  
  if (!planId || !dataUrl) {
    console.error('❌ Missing plan ID or data URL');
    return;
  }
  
  console.log('📊 [Plans Show] Loading plan data...', { planId, dataUrl });
  
  // 計画データを取得
  fetch(dataUrl)
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      if (data.success) {
        console.log('✅ [Plans Show] Plan data loaded:', data.data);
        prepareGanttChartData(data.data);
      } else {
        console.error('❌ [Plans Show] Failed to load plan data:', data.message);
        showError(getI18nMessage('jsPlansLoadError', 'Failed to load data'));
      }
    })
    .catch(error => {
      console.error('❌ [Plans Show] Error loading plan data:', error);
      showError(getI18nTemplate('jsPlansLoadErrorWithMessage', 'データの読み込みに失敗しました: %{message}', { message: error.message }));
    });
  
  /**
   * APIデータをcustom_gantt_chart.js形式に変換してDOM属性に設定
   * 共通ユーティリティを使用して重複を削除
   */
  function prepareGanttChartData(planData) {
    console.log('🔄 [Plans Show] Preparing gantt chart data...');
    
    // 共通ユーティリティを使用してデータを正規化
    const ganttData = window.prepareGanttData(planData);
    
    console.log('📊 [Plans Show] Fields data:', ganttData.fields);
    console.log('📊 [Plans Show] Cultivations data:', ganttData.cultivations);
    
    // 共通ユーティリティを使用してDOM属性を設定
    window.setGanttDataAttributes(chartContainer, ganttData);
    
    console.log('✅ [Plans Show] Data attributes set, initializing gantt chart...');
    
    // custom_gantt_chart.jsの初期化関数を呼び出す
    if (typeof window.initCustomGanttChart === 'function') {
      window.initCustomGanttChart();
      console.log('✅ [Plans Show] Gantt chart initialized successfully');
    } else {
      console.error('❌ [Plans Show] initCustomGanttChart is not available. Make sure custom_gantt_chart.js is loaded.');
      showError(getI18nMessage('jsGanttNotLoaded', 'ガントチャート機能が読み込まれていません'));
    }
  }
  
  /**
   * エラーメッセージを表示
   */
  function showError(message) {
    chartContainer.innerHTML = `
      <div style="padding: var(--space-8); text-align: center; background: var(--color-gray-50); border-radius: var(--radius-lg);">
        <div style="font-size: 3rem; margin-bottom: var(--space-4);">⚠️</div>
        <p style="color: var(--color-danger); font-weight: var(--font-weight-semibold);">${message}</p>
      </div>
    `;
  }
}

// 通常のページロード（初回アクセス時）
document.addEventListener('DOMContentLoaded', () => {
  console.log('🔍 [Plans Show] DOMContentLoaded event detected');
  initializePlansShow();
});

// Turboによるページ遷移（全てのケースで確実に発火）
document.addEventListener('turbo:load', () => {
  console.log('🔍 [Plans Show] turbo:load event detected');
  initializePlansShow();
});

