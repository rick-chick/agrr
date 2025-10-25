// app/assets/javascripts/crop_colors.js
// 作物の色管理システム

// 作物の色マップ（デフォルト色）
const CROP_COLOR_MAP = {
  // 穀物類
  'rice': '#4CAF50',           // 緑
  'wheat': '#FFC107',          // 黄色
  'barley': '#FF9800',         // オレンジ
  'corn': '#FF5722',           // 赤オレンジ
  
  // 豆類
  'soybean': '#8BC34A',        // ライトグリーン
  'red_bean': '#E91E63',       // ピンク
  'green_bean': '#4CAF50',     // 緑
  
  // 野菜類
  'tomato': '#F44336',         // 赤
  'cabbage': '#4CAF50',        // 緑
  'carrot': '#FF9800',         // オレンジ
  'onion': '#9C27B0',          // 紫
  'potato': '#795548',         // 茶色
  
  // 果物類
  'apple': '#F44336',          // 赤
  'orange': '#FF9800',         // オレンジ
  'grape': '#9C27B0',          // 紫
  
  // その他
  'default': '#607D8B'          // ブルーグレー
};

// 色の透明度バリエーション
const COLOR_OPACITIES = {
  light: 0.2,
  medium: 0.5,
  dark: 0.8
};

/**
 * 作物名から色を取得
 * @param {string} cropName - 作物名
 * @returns {string} 色コード（HEX）
 */
function getCropColor(cropName) {
  if (!cropName) return CROP_COLOR_MAP.default;
  
  // 作物名を正規化（小文字、アンダースコア区切り）
  const normalizedName = cropName.toLowerCase().replace(/[-\s]/g, '_');
  
  return CROP_COLOR_MAP[normalizedName] || CROP_COLOR_MAP.default;
}

/**
 * 作物名からストローク色を取得（ガントチャート用）
 * @param {string} cropName - 作物名
 * @returns {string} 色コード（HEX）
 */
function getCropStrokeColor(cropName) {
  return getCropColor(cropName);
}

/**
 * 作物名から塗りつぶし色を取得（透明度付き）
 * @param {string} cropName - 作物名
 * @param {string} opacity - 透明度レベル ('light', 'medium', 'dark')
 * @returns {string} 色コード（RGBA）
 */
function getCropFillColor(cropName, opacity = 'medium') {
  const baseColor = getCropColor(cropName);
  const alpha = COLOR_OPACITIES[opacity] || COLOR_OPACITIES.medium;
  
  // HEXをRGBに変換
  const hex = baseColor.replace('#', '');
  const r = parseInt(hex.substr(0, 2), 16);
  const g = parseInt(hex.substr(2, 2), 16);
  const b = parseInt(hex.substr(4, 2), 16);
  
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

/**
 * 作物の色マップを更新
 * @param {Object} colorMap - 新しい色マップ
 */
function updateCropColorMap(colorMap) {
  Object.assign(CROP_COLOR_MAP, colorMap);
}

/**
 * 作物の色を設定
 * @param {string} cropName - 作物名
 * @param {string} color - 色コード
 */
function setCropColor(cropName, color) {
  const normalizedName = cropName.toLowerCase().replace(/[-\s]/g, '_');
  CROP_COLOR_MAP[normalizedName] = color;
}

/**
 * 利用可能な作物色の一覧を取得
 * @returns {Object} 作物色マップ
 */
function getAvailableColors() {
  return { ...CROP_COLOR_MAP };
}

/**
 * 色のコントラスト比を計算
 * @param {string} hexColor - HEX色コード
 * @returns {number} コントラスト比
 */
function getContrastRatio(hexColor) {
  // 簡易的なコントラスト比計算
  const hex = hexColor.replace('#', '');
  const r = parseInt(hex.substr(0, 2), 16);
  const g = parseInt(hex.substr(2, 2), 16);
  const b = parseInt(hex.substr(4, 2), 16);
  
  // 相対輝度を計算
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  
  return luminance > 0.5 ? 1 : 0; // 白文字か黒文字かを判定
}

/**
 * 作物の色が適切かチェック
 * @param {string} cropName - 作物名
 * @returns {boolean} 色が設定されているか
 */
function hasCropColor(cropName) {
  const normalizedName = cropName.toLowerCase().replace(/[-\s]/g, '_');
  return CROP_COLOR_MAP.hasOwnProperty(normalizedName);
}

// グローバルに公開
window.getCropColor = getCropColor;
window.getCropStrokeColor = getCropStrokeColor;
window.getCropFillColor = getCropFillColor;
window.updateCropColorMap = updateCropColorMap;
window.setCropColor = setCropColor;
window.getAvailableColors = getAvailableColors;
window.getContrastRatio = getContrastRatio;
window.hasCropColor = hasCropColor;

// 初期化完了を通知
console.log('🎨 Crop Colors System initialized');

// イベント発火（他のスクリプトが色システムの準備完了を検知できるように）
document.dispatchEvent(new CustomEvent('cropColorsReady'));
