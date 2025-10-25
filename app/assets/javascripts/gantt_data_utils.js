// app/assets/javascripts/gantt_data_utils.js
// ガントチャート用データ変換ユーティリティ（共通化）

/**
 * field_idをそのまま返す（変換処理なし）
 * @param {string|number} fieldId - 圃場ID
 * @returns {string|number|null} 未変換のfield_id
 */
function normalizeFieldId(fieldId) {
  return fieldId;
}

/**
 * 圃場データを正規化する
 * @param {Array} fieldsData - 圃場データ配列
 * @returns {Array} 正規化された圃場データ
 */
function normalizeFieldsData(fieldsData) {
  return fieldsData.map(field => ({
    ...field,
    field_id: normalizeFieldId(field.field_id || field.id)
  }));
}

/**
 * 栽培データを正規化する
 * @param {Array} cultivationsData - 栽培データ配列
 * @returns {Array} 正規化された栽培データ
 */
function normalizeCultivationsData(cultivationsData) {
  return cultivationsData.map(cultivation => ({
    ...cultivation,
    field_id: normalizeFieldId(cultivation.field_id)
  }));
}

/**
 * APIレスポンスからガントチャート用データを準備する
 * @param {Object} planData - APIレスポンスデータ
 * @returns {Object} ガントチャート用の正規化されたデータ
 */
function prepareGanttData(planData) {
  const normalizedFields = normalizeFieldsData(planData.fields || []);
  const normalizedCultivations = normalizeCultivationsData(planData.cultivations || []);
  
  return {
    fields: normalizedFields,
    cultivations: normalizedCultivations,
    planStartDate: planData.planning_start_date,
    planEndDate: planData.planning_end_date,
    cultivationPlanId: planData.id
  };
}

/**
 * DOM要素にガントチャートデータを設定する
 * @param {HTMLElement} container - ガントチャートコンテナ要素
 * @param {Object} ganttData - 正規化されたガントチャートデータ
 */
function setGanttDataAttributes(container, ganttData) {
  container.dataset.cultivations = JSON.stringify(ganttData.cultivations);
  container.dataset.fields = JSON.stringify(ganttData.fields);
  container.dataset.planStartDate = ganttData.planStartDate;
  container.dataset.planEndDate = ganttData.planEndDate;
  container.dataset.cultivationPlanId = ganttData.cultivationPlanId;
}

// グローバルに公開
window.normalizeFieldId = normalizeFieldId;
window.normalizeFieldsData = normalizeFieldsData;
window.normalizeCultivationsData = normalizeCultivationsData;
window.prepareGanttData = prepareGanttData;
window.setGanttDataAttributes = setGanttDataAttributes;
