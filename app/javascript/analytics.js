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

