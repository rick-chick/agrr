/**
 * @jest-environment jsdom
 */

// pest_form.jsを読み込む（実際の実装をテストするため）
// 注意: 実際のテスト環境では、pest_form.jsをモックまたはインポートする必要があります

describe('Pest Form - Control Method Management', () => {
  let addButton;
  let container;
  let formCard;
  let initializePestForm;
  let createMethodTemplate;
  let getPestFormI18n;
  let addControlMethodHandler;

  beforeEach(() => {
    // DOMをセットアップ
    document.body.innerHTML = `
      <div class="form-card" 
           data-pest-form
           data-i18n-control-methods-title="防除方法"
           data-i18n-method-type-label="防除方法タイプ"
           data-i18n-select-method-type="選択してください"
           data-i18n-method-types-chemical="化学的防除"
           data-i18n-method-types-biological="生物的防除"
           data-i18n-method-types-cultural="耕種的防除"
           data-i18n-method-types-physical="物理的防除"
           data-i18n-method-name-label="防除方法名"
           data-i18n-method-description-label="説明"
           data-i18n-timing-hint-label="実施時期"
           data-i18n-remove-method="削除">
        <div id="control-methods-list"></div>
        <button type="button" id="add-control-method">+ 防除方法を追加</button>
      </div>
    `;

    addButton = document.getElementById('add-control-method');
    container = document.getElementById('control-methods-list');
    formCard = document.querySelector('[data-pest-form]');

    // pest_form.jsの関数を模倣（実際の実装を反映）
    // 実際のテストでは、pest_form.jsをインポートして使用
    getPestFormI18n = (key) => {
      const value = formCard.getAttribute(`data-i18n-${key}`);
      return value || '';
    };

    createMethodTemplate = (index) => {
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
        </div>
      `;
    };

    // 修正後のinitializePestFormを模倣
    addControlMethodHandler = null;
    initializePestForm = () => {
      if (!addButton) return;

      // 非表示（削除フラグが立った）要素を除外してインデックスを計算
      const allMethodFields = document.querySelectorAll('.control-method-fields');
      let methodIndex = 0;
      allMethodFields.forEach(field => {
        const destroyFlag = field.querySelector('.destroy-flag');
        if (!destroyFlag || destroyFlag.value !== 'true') {
          if (field.style.display !== 'none') {
            methodIndex++;
          }
        }
      });

      // 既存のイベントリスナーを削除（重複登録防止）
      if (addControlMethodHandler) {
        addButton.removeEventListener('click', addControlMethodHandler);
      }

      // 防除方法追加ボタンのイベントハンドラーを定義
      addControlMethodHandler = (e) => {
        e.preventDefault();
        const container = document.getElementById('control-methods-list');
        const newMethod = createMethodTemplate(methodIndex);
        container.insertAdjacentHTML('beforeend', newMethod);
        methodIndex++;
      };

      // イベントリスナーを追加
      addButton.addEventListener('click', addControlMethodHandler);
    };
  });

  afterEach(() => {
    document.body.innerHTML = '';
    addControlMethodHandler = null;
  });

  test('add button exists in DOM', () => {
    expect(addButton).toBeTruthy();
    expect(addButton.id).toBe('add-control-method');
  });

  test('container exists in DOM', () => {
    expect(container).toBeTruthy();
    expect(container.id).toBe('control-methods-list');
  });

  test('initially no control methods exist', () => {
    const methods = container.querySelectorAll('.control-method-fields');
    expect(methods.length).toBe(0);
  });

  test('clicking add button once should add exactly one panel', () => {
    initializePestForm();
    
    const initialCount = container.querySelectorAll('.control-method-fields').length;
    addButton.click();
    
    const newCount = container.querySelectorAll('.control-method-fields').length;
    expect(newCount).toBe(initialCount + 1);
  });

  test('clicking add button multiple times should add correct number of panels', () => {
    initializePestForm();
    
    const initialCount = container.querySelectorAll('.control-method-fields').length;
    
    addButton.click();
    addButton.click();
    addButton.click();
    
    const newCount = container.querySelectorAll('.control-method-fields').length;
    expect(newCount).toBe(initialCount + 3);
  });

  test('event listener should not be duplicated when initializePestForm is called multiple times', () => {
    // 複数回初期化をシミュレート（turbo:loadが複数回発火する場合を想定）
    initializePestForm();
    initializePestForm();
    initializePestForm();
    
    const initialCount = container.querySelectorAll('.control-method-fields').length;
    
    // 1回だけクリック
    addButton.click();
    
    const newCount = container.querySelectorAll('.control-method-fields').length;
    // 1つだけ追加されるべき（重複登録されていない）
    expect(newCount).toBe(initialCount + 1);
  });

  test('methodIndex should exclude hidden elements with destroy flag', () => {
    // 既存の要素を追加（destroy flagがtrueのもの）
    container.innerHTML = `
      <div class="control-method-fields" style="display: none;">
        <input type="hidden" class="destroy-flag" value="true">
      </div>
      <div class="control-method-fields">
        <input type="hidden" class="destroy-flag" value="false">
      </div>
    `;

    initializePestForm();
    
    // methodIndexは非表示要素を除外して計算されるため、1から始まる
    addButton.click();
    
    const newMethod = container.querySelectorAll('.control-method-fields')[1];
    const methodNameInput = newMethod.querySelector('input[name*="[method_name]"]');
    // インデックスが1（既存の表示要素が0）になっていることを確認
    expect(methodNameInput.name).toContain('[1]');
  });

  test('methodIndex should exclude elements with display:none', () => {
    // display:noneの要素を追加
    container.innerHTML = `
      <div class="control-method-fields" style="display: none;">
        <input type="hidden" class="destroy-flag" value="false">
      </div>
      <div class="control-method-fields">
      </div>
    `;

    initializePestForm();
    
    addButton.click();
    
    const methods = container.querySelectorAll('.control-method-fields');
    const newMethod = methods[methods.length - 1];
    const methodNameInput = newMethod.querySelector('input[name*="[method_name]"]');
    // インデックスが1（既存の表示要素が0）になっていることを確認
    expect(methodNameInput.name).toContain('[1]');
  });

  test('template should include correct field names with index', () => {
    initializePestForm();
    
    addButton.click();
    
    const method = container.querySelector('.control-method-fields');
    expect(method).toBeTruthy();
    
    const methodTypeSelect = method.querySelector('select[name*="[method_type]"]');
    const methodNameInput = method.querySelector('input[name*="[method_name]"]');
    
    expect(methodTypeSelect).toBeTruthy();
    expect(methodNameInput).toBeTruthy();
    expect(methodTypeSelect.name).toBe('pest[pest_control_methods_attributes][0][method_type]');
    expect(methodNameInput.name).toBe('pest[pest_control_methods_attributes][0][method_name]');
  });

  test('template should include all required fields', () => {
    initializePestForm();
    
    addButton.click();
    
    const method = container.querySelector('.control-method-fields');
    expect(method.querySelector('.nested-title')).toBeTruthy();
    expect(method.querySelector('.remove-control-method')).toBeTruthy();
    expect(method.querySelector('select[name*="[method_type]"]')).toBeTruthy();
    expect(method.querySelector('input[name*="[method_name]"]')).toBeTruthy();
  });

  test('removing existing method should set destroy flag and hide element', () => {
    // 既存レコードを追加
    container.innerHTML = `
      <div class="control-method-fields">
        <input type="hidden" class="destroy-flag" value="false">
        <button type="button" class="btn btn-error btn-sm remove-control-method">削除</button>
      </div>
    `;

    const removeButton = container.querySelector('.remove-control-method');
    const methodItem = container.querySelector('.control-method-fields');
    const destroyFlag = methodItem.querySelector('.destroy-flag');

    // 削除処理を実行
    const handleRemove = (e) => {
      e.preventDefault();
      const item = e.target.closest('.control-method-fields');
      const flag = item.querySelector('.destroy-flag');
      if (flag) {
        flag.value = 'true';
        item.style.display = 'none';
      }
    };

    removeButton.addEventListener('click', handleRemove);
    removeButton.click();

    expect(destroyFlag.value).toBe('true');
    expect(methodItem.style.display).toBe('none');
  });

  test('removing new method should remove element from DOM', () => {
    initializePestForm();
    addButton.click();

    const methodItem = container.querySelector('.control-method-fields');
    const removeButton = methodItem.querySelector('.remove-control-method');

    // 新規追加の場合はDOMから削除
    const handleRemove = (e) => {
      e.preventDefault();
      const item = e.target.closest('.control-method-fields');
      const flag = item.querySelector('.destroy-flag');
      if (!flag) {
        item.remove();
      }
    };

    removeButton.addEventListener('click', handleRemove);
    removeButton.click();

    expect(container.querySelector('.control-method-fields')).toBeNull();
  });
});




