// app/assets/javascripts/crop_colors.js
// 作物の色パレット管理（ガントチャートと作物パレットで共有）

// 作物の色パレット（順番に使用）
const colorPalette = [
  { fill: '#9ae6b4', stroke: '#48bb78' },   // 緑1
  { fill: '#fbd38d', stroke: '#f6ad55' },   // オレンジ
  { fill: '#90cdf4', stroke: '#4299e1' },   // 青
  { fill: '#c6f6d5', stroke: '#2f855a' },   // 緑2
  { fill: '#feebc8', stroke: '#dd6b20' },   // 淡いオレンジ
  { fill: '#feb2b2', stroke: '#fc8181' },   // 赤
  { fill: '#fef3c7', stroke: '#d69e2e' },   // 黄色
  { fill: '#e9d5ff', stroke: '#a78bfa' },   // 紫
  { fill: '#bfdbfe', stroke: '#60a5fa' },   // 水色
  { fill: '#fce7f3', stroke: '#f472b6' }    // ピンク
];

// 作物名をハッシュ化して色インデックスを決定
const cropColorMap = new Map();

/**
 * 作物名から塗りつぶし色を取得
 * @param {string} cropName - 作物名
 * @returns {string} - 塗りつぶし色（HEX）
 */
function getCropColor(cropName) {
  const baseCropName = cropName.split('（')[0];
  
  if (!cropColorMap.has(baseCropName)) {
    // 新しい作物の場合、次の色を割り当て
    const colorIndex = cropColorMap.size % colorPalette.length;
    cropColorMap.set(baseCropName, colorIndex);
  }
  
  const colorIndex = cropColorMap.get(baseCropName);
  return colorPalette[colorIndex].fill;
}

/**
 * 作物名から枠線色を取得
 * @param {string} cropName - 作物名
 * @returns {string} - 枠線色（HEX）
 */
function getCropStrokeColor(cropName) {
  const baseCropName = cropName.split('（')[0];
  
  if (!cropColorMap.has(baseCropName)) {
    const colorIndex = cropColorMap.size % colorPalette.length;
    cropColorMap.set(baseCropName, colorIndex);
  }
  
  const colorIndex = cropColorMap.get(baseCropName);
  return colorPalette[colorIndex].stroke;
}

/**
 * 作物名から色オブジェクトを取得
 * @param {string} cropName - 作物名
 * @returns {Object} - { fill: string, stroke: string }
 */
function getCropColors(cropName) {
  return {
    fill: getCropColor(cropName),
    stroke: getCropStrokeColor(cropName)
  };
}

// グローバルに公開
window.getCropColor = getCropColor;
window.getCropStrokeColor = getCropStrokeColor;
window.getCropColors = getCropColors;
window.cropColorPalette = colorPalette;

