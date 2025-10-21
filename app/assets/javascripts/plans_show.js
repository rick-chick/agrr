// app/assets/javascripts/plans_show.js
// 計画詳細画面のガントチャート表示

function initializePlansShow() {
  // ガントチャートコンテナがあるときのみ実行
  const chartContainer = document.getElementById('gantt-chart');
  if (!chartContainer) {
    console.log('ℹ️ Not on plans show page, skipping chart initialization');
    return;
  }
  
  const planId = chartContainer.dataset.planId;
  const dataUrl = chartContainer.dataset.dataUrl;
  
  if (!planId || !dataUrl) {
    console.error('❌ Missing plan ID or data URL');
    return;
  }
  
  // 計画データを取得
  fetch(dataUrl)
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log('✅ Plan data loaded:', data.data);
        renderGanttChart(data.data);
      } else {
        console.error('❌ Failed to load plan data:', data.message);
        showError(getI18nMessage('jsPlansLoadError', 'Failed to load data'));
      }
    })
    .catch(error => {
      console.error('❌ Error loading plan data:', error);
      showError('データの読み込みに失敗しました');
    });
  
  function renderGanttChart(planData) {
    // ガントチャートを描画
    // TODO: custom_gantt_chart.jsの関数を活用
    // 現在は暫定的にデータを表示
    
    const html = `
      <div style="padding: var(--space-4); background: var(--color-gray-50); border-radius: var(--radius-lg);">
        <p style="color: var(--text-secondary); text-align: center;">
          ガントチャートは開発中です。<br>
          custom_gantt_chart.jsを活用して実装予定です。
        </p>
        <details style="margin-top: var(--space-4);">
          <summary style="cursor: pointer; color: var(--color-primary);">データを確認</summary>
          <pre style="margin-top: var(--space-2); padding: var(--space-4); background: var(--color-white); border-radius: var(--radius-md); overflow-x: auto; font-size: var(--font-size-xs);">${JSON.stringify(planData, null, 2)}</pre>
        </details>
      </div>
    `;
    
    chartContainer.innerHTML = html;
  }
  
  function showError(message) {
    chartContainer.innerHTML = `
      <div style="padding: var(--space-8); text-align: center;">
        <div style="font-size: 3rem; margin-bottom: var(--space-4);">⚠️</div>
        <p style="color: var(--color-danger); font-weight: var(--font-weight-semibold);">${message}</p>
      </div>
    `;
  }
}

// 通常のページロード（初回アクセス時）
document.addEventListener('DOMContentLoaded', initializePlansShow);

// Turboによるページ遷移
document.addEventListener('turbo:load', initializePlansShow);

