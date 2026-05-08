/**
 * 既存のJavaScriptファイルにGA4トラッキングを統合
 */

import {
  trackGanttCropClick,
  trackClimateDataView,
  trackPlanCreationStart,
  trackFarmSizeSelection
} from '../analytics.js';

/**
 * カスタムガントチャートにGA4イベントを追加
 */
export function integrateGanttChartAnalytics() {
  document.addEventListener('DOMContentLoaded', () => {
    // ガントチャート作物クリックイベント
    document.addEventListener('click', (e) => {
      const cropBar = e.target.closest('.gantt-cultivation-bar');
      if (cropBar) {
        const cropName = cropBar.dataset.cropName || '不明';
        const fieldCultivationId = cropBar.dataset.fieldCultivationId || 0;
        trackGanttCropClick(cropName, parseInt(fieldCultivationId));
      }
    });
  });
}

/**
 * 作付け計画作成フローにGA4イベントを追加
 */
export function integratePlanCreationAnalytics() {
  // 作付け計画作成開始ボタン
  const startButtons = document.querySelectorAll('a[href*="public_plans"], button[data-action="start-plan"]');
  startButtons.forEach(button => {
    button.addEventListener('click', () => {
      trackPlanCreationStart();
    });
  });
  
  // 農場サイズ選択
  const farmSizeInputs = document.querySelectorAll('input[name*="farm_size"]');
  farmSizeInputs.forEach(input => {
    input.addEventListener('change', (e) => {
      trackFarmSizeSelection(e.target.value);
    });
  });
}

/**
 * 気候データ表示にGA4イベントを追加
 */
export function integrateClimateDataAnalytics() {
  // MutationObserverで気候チャート表示を監視
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.target.id === 'climate-chart-display' && 
          mutation.target.style.display !== 'none') {
        const cropName = mutation.target.dataset.cropName || '不明';
        trackClimateDataView(cropName);
      }
    });
  });
  
  const climateDisplay = document.getElementById('climate-chart-display');
  if (climateDisplay) {
    observer.observe(climateDisplay, { attributes: true, attributeFilter: ['style'] });
  }
}

/**
 * すべてのアナリティクス統合を初期化
 */
export function initializeAnalytics() {
  console.log('📊 GA4 Analytics Integration 初期化');
  
  integrateGanttChartAnalytics();
  integratePlanCreationAnalytics();
  integrateClimateDataAnalytics();
}

// DOMContentLoadedで自動初期化
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeAnalytics);
} else {
  initializeAnalytics();
}

