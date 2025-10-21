// 作物フォーム - 動的な生育ステージ追加/削除機能

function initializeCropForm() {
  const addButton = document.getElementById('add-crop-stage');
  if (!addButton) return;

  let stageIndex = document.querySelectorAll('.crop-stage-item').length;

  // 生育ステージ追加ボタンのイベント
  addButton.addEventListener('click', (e) => {
    e.preventDefault();
    const container = document.getElementById('crop-stages');
    const newStage = createStageTemplate(stageIndex);
    container.insertAdjacentHTML('beforeend', newStage);
    stageIndex++;
    attachRemoveHandlers();
  });

  // 削除ボタンのハンドラーを既存の要素に適用
  attachRemoveHandlers();
}

// 通常のページロード（初回アクセス時）
document.addEventListener('DOMContentLoaded', initializeCropForm);

// Turboによるページ遷移
document.addEventListener('turbo:load', initializeCropForm);

// 削除ボタンのイベントハンドラーをアタッチ
function attachRemoveHandlers() {
  document.querySelectorAll('.remove-crop-stage').forEach(button => {
    button.removeEventListener('click', handleRemove);
    button.addEventListener('click', handleRemove);
  });
}

// 削除処理
function handleRemove(e) {
  e.preventDefault();
  const stageItem = e.target.closest('.crop-stage-item');
  const destroyFlag = stageItem.querySelector('.destroy-flag');
  
  if (destroyFlag && destroyFlag.value !== 'false') {
    // 既存のレコードの場合は_destroyフラグを立てて非表示
    destroyFlag.value = '1';
    stageItem.style.display = 'none';
  } else {
    // 新規追加の場合は削除
    stageItem.remove();
  }
}

// 生育ステージのHTMLテンプレート
function createStageTemplate(index) {
  return `
    <div class="nested-fields crop-stage-item">
      <div class="nested-fields-header">
        <h4 class="nested-title">生育ステージ</h4>
        <input type="hidden" name="crop[crop_stages_attributes][${index}][_destroy]" value="false" class="destroy-flag">
        <button type="button" class="btn btn-danger btn-sm remove-crop-stage">削除</button>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label class="form-label" for="crop_crop_stages_attributes_${index}_name">ステージ名</label>
          <input type="text" name="crop[crop_stages_attributes][${index}][name]" 
                 id="crop_crop_stages_attributes_${index}_name" 
                 class="form-control" placeholder="${getI18nMessage('jsCropStageNamePlaceholder', 'e.g., Germination, Vegetative growth')}">
        </div>

        <div class="form-group">
          <label class="form-label" for="crop_crop_stages_attributes_${index}_order">順序</label>
          <input type="number" name="crop[crop_stages_attributes][${index}][order]" 
                 id="crop_crop_stages_attributes_${index}_order" 
                 class="form-control" min="0" placeholder="${getI18nMessage('jsCropOrderPlaceholder', '0')}">
        </div>
      </div>

      <div class="nested-section">
        <h5 class="nested-subtitle">🌡️ 温度要件</h5>
        ${createTemperatureRequirementTemplate(index)}
      </div>

      <div class="nested-section">
        <h5 class="nested-subtitle">☀️ 日照要件</h5>
        ${createSunshineRequirementTemplate(index)}
      </div>
    </div>
  `;
}

// 温度要件のテンプレート
function createTemperatureRequirementTemplate(index) {
  return `
    <div class="requirement-fields">
      <input type="hidden" name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][_destroy]" 
             value="false" class="destroy-flag">
      
      <div class="form-row">
        <div class="form-group">
          <label class="form-label">最低限界温度 (°C)</label>
          <input type="number" 
                 name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][base_temperature]" 
                 class="form-control" step="0.1" placeholder="${getI18nMessage('jsCropBaseTemperaturePlaceholder', 'e.g., 5.0')}">
        </div>

        <div class="form-group">
          <label class="form-label">最適温度 最小 (°C)</label>
          <input type="number" 
                 name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][optimal_min]" 
                 class="form-control" step="0.1" placeholder="${getI18nMessage('jsCropOptimalMinPlaceholder', 'e.g., 15.0')}">
        </div>

        <div class="form-group">
          <label class="form-label">最適温度 最大 (°C)</label>
          <input type="number" 
                 name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][optimal_max]" 
                 class="form-control" step="0.1" placeholder="${getI18nMessage('jsCropOptimalMaxPlaceholder', 'e.g., 25.0')}">
        </div>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label class="form-label">低温ストレス閾値 (°C)</label>
          <input type="number" 
                 name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][low_stress_threshold]" 
                 class="form-control" step="0.1" placeholder="${getI18nMessage('jsCropLowStressPlaceholder', 'e.g., 10.0')}">
        </div>

        <div class="form-group">
          <label class="form-label">高温ストレス閾値 (°C)</label>
          <input type="number" 
                 name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][high_stress_threshold]" 
                 class="form-control" step="0.1" placeholder="${getI18nMessage('jsCropHighStressPlaceholder', 'e.g., 30.0')}">
        </div>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label class="form-label">霜害閾値 (°C)</label>
          <input type="number" 
                 name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][frost_threshold]" 
                 class="form-control" step="0.1" placeholder="${getI18nMessage('jsCropFrostThresholdPlaceholder', 'e.g., 0.0')}">
        </div>

        <div class="form-group">
          <label class="form-label">不稔リスク閾値 (°C)</label>
          <input type="number" 
                 name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][sterility_risk_threshold]" 
                 class="form-control" step="0.1" placeholder="${getI18nMessage('jsCropSterilityRiskPlaceholder', 'e.g., 35.0')}">
        </div>
      </div>
    </div>
  `;
}

// 日照要件のテンプレート
function createSunshineRequirementTemplate(index) {
  return `
    <div class="requirement-fields">
      <input type="hidden" name="crop[crop_stages_attributes][${index}][sunshine_requirement_attributes][_destroy]" 
             value="false" class="destroy-flag">
      
      <div class="form-row">
        <div class="form-group">
          <label class="form-label">最低日照時間 (時間)</label>
          <input type="number" 
                 name="crop[crop_stages_attributes][${index}][sunshine_requirement_attributes][minimum_sunshine_hours]" 
                 class="form-control" step="0.1" placeholder="${getI18nMessage('jsCropMinimumSunshinePlaceholder', 'e.g., 4.0')}">
        </div>

        <div class="form-group">
          <label class="form-label">目標日照時間 (時間)</label>
          <input type="number" 
                 name="crop[crop_stages_attributes][${index}][sunshine_requirement_attributes][target_sunshine_hours]" 
                 class="form-control" step="0.1" placeholder="${getI18nMessage('jsCropTargetSunshinePlaceholder', 'e.g., 8.0')}">
        </div>
      </div>
    </div>
  `;
}

