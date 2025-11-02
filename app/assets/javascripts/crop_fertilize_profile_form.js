// 肥料プロファイルフォーム - 動的な施用計画追加/削除機能

// 追加ボタンのクリックハンドラー（重複防止のため関数として定義）
function handleAddApplication(e) {
  e.preventDefault();
  const container = document.getElementById('crop-fertilize-applications');
  if (!container) return;
  
  // 現在のインデックスを計算（既存のアイテム数から、非表示も含む）
  // Railsのnested attributesは配列形式を期待するため、全てのアイテムを数える
  let applicationIndex = document.querySelectorAll('.crop-fertilize-application-item').length;
  
  const newApplication = createApplicationTemplate(applicationIndex);
  container.insertAdjacentHTML('beforeend', newApplication);
  attachRemoveHandlers();
}

function initializeCropFertilizeProfileForm() {
  const addButton = document.getElementById('add-crop-fertilize-application');
  if (!addButton) return;

  // 既存のイベントリスナーを削除してから追加（重複防止）
  addButton.removeEventListener('click', handleAddApplication);
  addButton.addEventListener('click', handleAddApplication);

  // 削除ボタンのハンドラーを既存の要素に適用
  attachRemoveHandlers();
}

// 通常のページロード（初回アクセス時）
document.addEventListener('DOMContentLoaded', initializeCropFertilizeProfileForm);

// Turbo使用時（SPA遷移時）
document.addEventListener('turbo:load', initializeCropFertilizeProfileForm);

// 削除ハンドラーのアタッチ
function attachRemoveHandlers() {
  document.querySelectorAll('.remove-crop-fertilize-application').forEach(button => {
    // 既にイベントリスナーがアタッチされている場合は削除してから再追加
    button.removeEventListener('click', handleRemove);
    button.addEventListener('click', handleRemove);
  });
}

// 削除処理
function handleRemove(e) {
  e.preventDefault();
  const applicationItem = e.target.closest('.crop-fertilize-application-item');
  const destroyFlag = applicationItem.querySelector('.destroy-flag');
  
  if (destroyFlag && destroyFlag.value !== 'false') {
    // 既存のレコードの場合は_destroyフラグを立てて非表示
    destroyFlag.value = '1';
    applicationItem.style.display = 'none';
  } else {
    // 新規追加の場合は削除
    applicationItem.remove();
  }
}

// i18nデータを取得する関数
function getI18n(key) {
  const formCard = document.querySelector('[data-crop-fertilize-profile-form]');
  if (!formCard) return '';
  
  const value = formCard.getAttribute(`data-i18n-${key}`);
  return value || '';
}

// 施用計画のHTMLテンプレート
function createApplicationTemplate(index) {
  return `
    <div class="nested-fields crop-fertilize-application-item">
      <div class="nested-fields-header">
        <h4 class="nested-title">${getI18n('title')}</h4>
        <input type="hidden" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][_destroy]" value="false" class="destroy-flag">
        <button type="button" class="btn btn-error btn-sm remove-crop-fertilize-application">${getI18n('remove-button')}</button>
      </div>

      <div class="form-group">
        <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_application_type">${getI18n('application-type-label')}</label>
        <select name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][application_type]" 
                id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_application_type" 
                class="form-control" required>
          <option value="">${getI18n('application-type-prompt')}</option>
          <option value="basal">${getI18n('basal')}</option>
          <option value="topdress">${getI18n('topdress')}</option>
        </select>
        <div class="form-text">${getI18n('application-type-help')}</div>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_count">${getI18n('count-label')}</label>
          <input type="number" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][count]" 
                 id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_count" 
                 class="form-control" min="1" value="1" required>
          <div class="form-text">${getI18n('count-help')}</div>
        </div>

        <div class="form-group">
          <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_schedule_hint">${getI18n('schedule-hint-label')}</label>
          <input type="text" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][schedule_hint]" 
                 id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_schedule_hint" 
                 class="form-control" placeholder="${getI18n('schedule-hint-placeholder')}">
          <div class="form-text">${getI18n('schedule-hint-help')}</div>
        </div>
      </div>

      <div class="nested-section">
        <h5 class="nested-subtitle">${getI18n('per-application-section')}</h5>
        <div class="form-text">${getI18n('per-application-help')}</div>
        
        <div class="form-row">
          <div class="form-group">
            <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_per_application_n">${getI18n('per-application-n-label')}</label>
            <input type="number" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][per_application_n]" 
                   id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_per_application_n" 
                   class="form-control" step="any">
          </div>

          <div class="form-group">
            <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_per_application_p">${getI18n('per-application-p-label')}</label>
            <input type="number" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][per_application_p]" 
                   id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_per_application_p" 
                   class="form-control" step="any">
          </div>

          <div class="form-group">
            <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_per_application_k">${getI18n('per-application-k-label')}</label>
            <input type="number" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][per_application_k]" 
                   id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_per_application_k" 
                   class="form-control" step="any">
          </div>
        </div>
      </div>
    </div>
  `;
}

