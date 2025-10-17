/**
 * Google Analytics 4 イベントトラッキング
 */

// GA4が利用可能かチェック
function isGA4Available() {
  return typeof gtag === 'function';
}

/**
 * カスタムイベントを送信
 * @param {string} eventName - イベント名
 * @param {object} params - イベントパラメータ
 */
export function trackEvent(eventName, params = {}) {
  if (isGA4Available()) {
    gtag('event', eventName, params);
    console.log('📊 GA4 Event:', eventName, params);
  }
}

/**
 * 作付け計画作成開始
 */
export function trackPlanCreationStart() {
  trackEvent('plan_creation_start', {
    event_category: 'cultivation',
    event_label: 'start'
  });
}

/**
 * 農場サイズ選択
 * @param {string} farmSize - 選択された農場サイズ
 */
export function trackFarmSizeSelection(farmSize) {
  trackEvent('farm_size_select', {
    event_category: 'cultivation',
    farm_size: farmSize
  });
}

/**
 * 作物選択
 * @param {string} cropName - 選択された作物名
 * @param {number} cropCount - 選択された作物の総数
 */
export function trackCropSelection(cropName, cropCount) {
  trackEvent('crop_select', {
    event_category: 'cultivation',
    crop_name: cropName,
    crop_count: cropCount
  });
}

/**
 * 作付け計画最適化開始
 * @param {number} cropCount - 作物数
 */
export function trackOptimizationStart(cropCount) {
  trackEvent('optimization_start', {
    event_category: 'cultivation',
    crop_count: cropCount
  });
}

/**
 * 作付け計画完成
 * @param {number} cropCount - 作物数
 * @param {number} duration - 作成にかかった時間（秒）
 */
export function trackPlanCompleted(cropCount, duration) {
  trackEvent('plan_completed', {
    event_category: 'cultivation',
    crop_count: cropCount,
    duration_seconds: duration
  });
}

/**
 * ガントチャート作物クリック
 * @param {string} cropName - クリックされた作物名
 * @param {number} fieldCultivationId - フィールド栽培ID
 */
export function trackGanttCropClick(cropName, fieldCultivationId) {
  trackEvent('gantt_crop_click', {
    event_category: 'gantt',
    crop_name: cropName,
    field_cultivation_id: fieldCultivationId
  });
}

/**
 * 気候データ表示
 * @param {string} cropName - 作物名
 */
export function trackClimateDataView(cropName) {
  trackEvent('climate_data_view', {
    event_category: 'data',
    crop_name: cropName
  });
}

/**
 * AI作物情報取得
 * @param {string} cropName - 作物名
 */
export function trackAICropInfoRequest(cropName) {
  trackEvent('ai_crop_info', {
    event_category: 'ai',
    crop_name: cropName
  });
}

/**
 * ページビュー（自動で送信されるが、SPAの場合に手動で送信）
 * @param {string} pagePath - ページパス
 */
export function trackPageView(pagePath) {
  if (isGA4Available()) {
    gtag('config', 'G-WNLSL6W4ZT', {
      page_path: pagePath
    });
  }
}

/**
 * エラー発生
 * @param {string} errorMessage - エラーメッセージ
 * @param {string} errorLocation - エラー発生場所
 */
export function trackError(errorMessage, errorLocation) {
  trackEvent('error', {
    event_category: 'error',
    error_message: errorMessage,
    error_location: errorLocation
  });
}

