// 肥料プロファイルフォーム - 動的な施用計画追加/削除機能

function initializeCropFertilizeProfileForm() {
  const addButton = document.getElementById('add-crop-fertilize-application');
  if (!addButton) return;

  let applicationIndex = document.querySelectorAll('.crop-fertilize-application-item').length;

  // 施用計画追加ボタンのイベント
  addButton.addEventListener('click', (e) => {
    e.preventDefault();
    const container = document.getElementById('crop-fertilize-applications');
    const newApplication = createApplicationTemplate(applicationIndex);
    container.insertAdjacentHTML('beforeend', newApplication);
    applicationIndex++;
    attachRemoveHandlers();
  });

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
    // 既にイベントリスナーがアタッチされている場合はスキップ
    if (button.dataset.handlerAttached) return;
    
    button.addEventListener('click', handleRemove);
    button.dataset.handlerAttached = 'true';
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

// 施用計画のHTMLテンプレート
function createApplicationTemplate(index) {
  return `
    <div class="nested-fields crop-fertilize-application-item">
      <div class="nested-fields-header">
        <h4 class="nested-title">施用計画</h4>
        <input type="hidden" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][_destroy]" value="false" class="destroy-flag">
        <button type="button" class="btn btn-error btn-sm remove-crop-fertilize-application">削除</button>
      </div>

      <div class="form-group">
        <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_application_type">施用タイプ</label>
        <select name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][application_type]" 
                id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_application_type" 
                class="form-control" required>
          <option value="">選択してください</option>
          <option value="basal">基肥</option>
          <option value="topdress">追肥</option>
        </select>
        <div class="form-text">基肥または追肥を選択してください</div>
      </div>

      <div class="form-row">
        <div class="form-group">
          <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_count">施用回数</label>
          <input type="number" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][count]" 
                 id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_count" 
                 class="form-control" min="1" value="1" required>
          <div class="form-text">施用回数を入力してください（必須、デフォルト: 1）</div>
        </div>

        <div class="form-group">
          <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_schedule_hint">タイミングガイダンス</label>
          <input type="text" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][schedule_hint]" 
                 id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_schedule_hint" 
                 class="form-control" placeholder="例: pre-plant, fruiting">
          <div class="form-text">施用のタイミングに関するガイダンスを入力してください（任意）</div>
        </div>
      </div>

      <div class="nested-section">
        <h5 class="nested-subtitle">総栄養素量</h5>
        
        <div class="form-row">
          <div class="form-group">
            <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_total_n">総窒素量 (g/m²)</label>
            <input type="number" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][total_n]" 
                   id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_total_n" 
                   class="form-control" step="any" required>
          </div>

          <div class="form-group">
            <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_total_p">総リン量 (g/m²)</label>
            <input type="number" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][total_p]" 
                   id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_total_p" 
                   class="form-control" step="any" required>
          </div>

          <div class="form-group">
            <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_total_k">総カリ量 (g/m²)</label>
            <input type="number" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][total_k]" 
                   id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_total_k" 
                   class="form-control" step="any" required>
          </div>
        </div>
      </div>

      <div class="nested-section">
        <h5 class="nested-subtitle">1回あたりの施肥量</h5>
        <div class="form-text">追肥で複数回の場合、1回あたりの施肥量を入力してください（任意）</div>
        
        <div class="form-row">
          <div class="form-group">
            <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_per_application_n">1回あたりの窒素量 (g/m²)</label>
            <input type="number" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][per_application_n]" 
                   id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_per_application_n" 
                   class="form-control" step="any">
          </div>

          <div class="form-group">
            <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_per_application_p">1回あたりのリン量 (g/m²)</label>
            <input type="number" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][per_application_p]" 
                   id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_per_application_p" 
                   class="form-control" step="any">
          </div>

          <div class="form-group">
            <label class="form-label" for="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_per_application_k">1回あたりのカリ量 (g/m²)</label>
            <input type="number" name="crop_fertilize_profile[crop_fertilize_applications_attributes][${index}][per_application_k]" 
                   id="crop_fertilize_profile_crop_fertilize_applications_attributes_${index}_per_application_k" 
                   class="form-control" step="any">
          </div>
        </div>
      </div>
    </div>
  `;
}

