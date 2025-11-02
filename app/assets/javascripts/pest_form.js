// 害虫フォーム - 動的な防除方法追加/削除機能

function initializePestForm() {
  const addButton = document.getElementById('add-control-method');
  if (!addButton) return;

  let methodIndex = document.querySelectorAll('.control-method-fields').length;

  // 防除方法追加ボタンのイベント
  addButton.addEventListener('click', (e) => {
    e.preventDefault();
    const container = document.getElementById('control-methods-list');
    const newMethod = createMethodTemplate(methodIndex);
    container.insertAdjacentHTML('beforeend', newMethod);
    methodIndex++;
    attachRemoveHandlers();
  });

  // 削除ボタンのハンドラーを既存の要素に適用
  attachRemoveHandlers();
}

// 通常のページロード（初回アクセス時）
document.addEventListener('DOMContentLoaded', initializePestForm);

// Turboフレームワーク対応（Turbo Drive使用時）
document.addEventListener('turbo:load', initializePestForm);

// 削除ハンドラーを全ての削除ボタンに適用
function attachRemoveHandlers() {
  const removeButtons = document.querySelectorAll('.remove-control-method');
  removeButtons.forEach(button => {
    button.removeEventListener('click', handleRemove);
    button.addEventListener('click', handleRemove);
  });
}

// 削除ボタンのハンドラー
function handleRemove(e) {
  e.preventDefault();
  const methodItem = e.target.closest('.control-method-fields');
  if (!methodItem) return;

  const destroyFlag = methodItem.querySelector('.destroy-flag');
  if (destroyFlag) {
    // 既存レコードの場合は非表示にして削除フラグを立てる
    destroyFlag.value = 'true';
    methodItem.style.display = 'none';
  } else {
    // 新規追加の場合は削除
    methodItem.remove();
  }
}

// i18nデータを取得する関数
function getPestFormI18n(key) {
  const formCard = document.querySelector('[data-pest-form]');
  if (!formCard) return '';
  
  const value = formCard.getAttribute(`data-i18n-${key}`);
  return value || '';
}

// 防除方法のHTMLテンプレート
function createMethodTemplate(index) {
  return `
    <div class="control-method-fields nested-fields">
      <div class="nested-fields-header">
        <h4 class="nested-title">${getPestFormI18n('control-methods-title')}</h4>
        <button type="button" class="btn btn-error btn-sm remove-control-method">${getPestFormI18n('remove-method')}</button>
      </div>

      <div class="form-group">
        <label class="form-label">${getPestFormI18n('method-type-label')}</label>
        <select name="pest[pest_control_methods_attributes][${index}][method_type]" class="form-control">
          <option value="">${getPestFormI18n('select-method-type')}</option>
          <option value="chemical">${getPestFormI18n('method-types-chemical')}</option>
          <option value="biological">${getPestFormI18n('method-types-biological')}</option>
          <option value="cultural">${getPestFormI18n('method-types-cultural')}</option>
          <option value="physical">${getPestFormI18n('method-types-physical')}</option>
        </select>
      </div>

      <div class="form-group">
        <label class="form-label">${getPestFormI18n('method-name-label')}</label>
        <input type="text" name="pest[pest_control_methods_attributes][${index}][method_name]" class="form-control">
      </div>

      <div class="form-group">
        <label class="form-label">${getPestFormI18n('method-description-label')}</label>
        <textarea name="pest[pest_control_methods_attributes][${index}][description]" class="form-control" rows="3"></textarea>
      </div>

      <div class="form-group">
        <label class="form-label">${getPestFormI18n('timing-hint-label')}</label>
        <input type="text" name="pest[pest_control_methods_attributes][${index}][timing_hint]" class="form-control">
      </div>
    </div>
  `;
}

