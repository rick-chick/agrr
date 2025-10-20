// app/assets/javascripts/i18n_helper.js
// JavaScript用のi18nヘルパー関数

/**
 * i18nメッセージを取得
 * @param {string} key - data属性のキー（例: 'jsGanttOptimizationFailed'）
 * @param {string} defaultMessage - キーが見つからない場合のデフォルトメッセージ
 * @returns {string} - 翻訳されたメッセージまたはデフォルトメッセージ
 */
function getI18nMessage(key, defaultMessage) {
  const i18nData = document.body.dataset;
  return i18nData[key] || defaultMessage;
}

/**
 * i18nテンプレートを取得し、置換を実行
 * @param {string} key - data属性のキー
 * @param {Object} replacements - 置換する値のオブジェクト（例: {field_name: '圃場A'}）
 * @param {string} defaultMessage - キーが見つからない場合のデフォルトメッセージ
 * @returns {string} - 置換済みのメッセージ
 */
function getI18nTemplate(key, replacements, defaultMessage) {
  let template = document.body.dataset[key] || defaultMessage;
  for (const [placeholder, value] of Object.entries(replacements)) {
    // %{placeholder} 形式を置換
    template = template.replace(new RegExp(`%\\{${placeholder}\\}`, 'g'), value);
  }
  return template;
}

/**
 * キャメルケースをスネークケースに変換
 * @param {string} str - キャメルケースの文字列
 * @returns {string} - スネークケースの文字列
 */
function camelToSnake(str) {
  return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
}

/**
 * i18nキーをdata属性名に変換
 * 例: 'js.gantt.optimization_failed' -> 'jsGanttOptimizationFailed'
 * @param {string} key - i18nキー（ドット区切り）
 * @returns {string} - data属性名（キャメルケース）
 */
function i18nKeyToDataAttr(key) {
  return key.split('.').map((part, index) => {
    if (index === 0) return part;
    return part.charAt(0).toUpperCase() + part.slice(1).replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
  }).join('');
}

