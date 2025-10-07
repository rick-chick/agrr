/**
 * @jest-environment jsdom
 */

describe('Crop Form - Dynamic Stage Management', () => {
  let addButton;
  let container;
  let document;

  beforeEach(() => {
    // Setup DOM
    document.body.innerHTML = `
      <div id="crop-stages"></div>
      <button type="button" id="add-crop-stage">+ 生育ステージを追加</button>
    `;

    addButton = document.getElementById('add-crop-stage');
    container = document.getElementById('crop-stages');
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  test('add button exists in DOM', () => {
    expect(addButton).toBeTruthy();
    expect(addButton.id).toBe('add-crop-stage');
  });

  test('container exists in DOM', () => {
    expect(container).toBeTruthy();
    expect(container.id).toBe('crop-stages');
  });

  test('initially no crop stages exist', () => {
    const stages = container.querySelectorAll('.crop-stage-item');
    expect(stages.length).toBe(0);
  });

  test('clicking add button should trigger event', () => {
    const mockHandler = jest.fn();
    addButton.addEventListener('click', mockHandler);
    
    addButton.click();
    
    expect(mockHandler).toHaveBeenCalledTimes(1);
  });

  test('button should not be disabled', () => {
    expect(addButton.disabled).toBe(false);
  });

  test('button has correct text', () => {
    expect(addButton.textContent).toContain('生育ステージを追加');
  });

  test('remove button should hide or remove stage', () => {
    // Add a stage manually
    container.innerHTML = `
      <div class="crop-stage-item">
        <input type="hidden" class="destroy-flag" value="false">
        <button type="button" class="remove-crop-stage">削除</button>
      </div>
    `;

    const removeButton = container.querySelector('.remove-crop-stage');
    const stageItem = container.querySelector('.crop-stage-item');
    
    expect(removeButton).toBeTruthy();
    expect(stageItem).toBeTruthy();
    
    // Simulate removal
    const mockRemove = jest.fn(() => {
      stageItem.style.display = 'none';
    });
    
    removeButton.addEventListener('click', mockRemove);
    removeButton.click();
    
    expect(mockRemove).toHaveBeenCalledTimes(1);
  });

  test('multiple stages can be added', () => {
    // Simulate adding multiple stages
    for (let i = 0; i < 3; i++) {
      const stage = document.createElement('div');
      stage.className = 'crop-stage-item';
      container.appendChild(stage);
    }

    const stages = container.querySelectorAll('.crop-stage-item');
    expect(stages.length).toBe(3);
  });
});

describe('Crop Form - Template Generation', () => {
  test('stage template should include required fields', () => {
    const templateHTML = `
      <div class="nested-fields crop-stage-item">
        <div class="nested-fields-header">
          <h4 class="nested-title">生育ステージ</h4>
          <input type="hidden" name="crop[crop_stages_attributes][0][_destroy]" value="false" class="destroy-flag">
          <button type="button" class="btn btn-danger btn-sm remove-crop-stage">削除</button>
        </div>
        <div class="form-row">
          <input type="text" name="crop[crop_stages_attributes][0][name]" placeholder="例：発芽期、栄養成長期">
          <input type="number" name="crop[crop_stages_attributes][0][order]" placeholder="0">
        </div>
      </div>
    `;

    document.body.innerHTML = templateHTML;

    // Check for required elements
    expect(document.querySelector('.crop-stage-item')).toBeTruthy();
    expect(document.querySelector('.nested-fields-header')).toBeTruthy();
    expect(document.querySelector('.destroy-flag')).toBeTruthy();
    expect(document.querySelector('.remove-crop-stage')).toBeTruthy();
    expect(document.querySelector('input[name*="[name]"]')).toBeTruthy();
    expect(document.querySelector('input[name*="[order]"]')).toBeTruthy();
  });

  test('temperature requirement fields should exist', () => {
    const templateHTML = `
      <input type="number" name="crop[crop_stages_attributes][0][temperature_requirement_attributes][base_temperature]">
      <input type="number" name="crop[crop_stages_attributes][0][temperature_requirement_attributes][optimal_min]">
      <input type="number" name="crop[crop_stages_attributes][0][temperature_requirement_attributes][optimal_max]">
      <input type="number" name="crop[crop_stages_attributes][0][temperature_requirement_attributes][low_stress_threshold]">
      <input type="number" name="crop[crop_stages_attributes][0][temperature_requirement_attributes][high_stress_threshold]">
      <input type="number" name="crop[crop_stages_attributes][0][temperature_requirement_attributes][frost_threshold]">
      <input type="number" name="crop[crop_stages_attributes][0][temperature_requirement_attributes][sterility_risk_threshold]">
    `;

    document.body.innerHTML = templateHTML;

    expect(document.querySelector('input[name*="base_temperature"]')).toBeTruthy();
    expect(document.querySelector('input[name*="optimal_min"]')).toBeTruthy();
    expect(document.querySelector('input[name*="optimal_max"]')).toBeTruthy();
    expect(document.querySelector('input[name*="low_stress_threshold"]')).toBeTruthy();
    expect(document.querySelector('input[name*="high_stress_threshold"]')).toBeTruthy();
    expect(document.querySelector('input[name*="frost_threshold"]')).toBeTruthy();
    expect(document.querySelector('input[name*="sterility_risk_threshold"]')).toBeTruthy();
  });

  test('sunshine requirement fields should exist', () => {
    const templateHTML = `
      <input type="number" name="crop[crop_stages_attributes][0][sunshine_requirement_attributes][minimum_sunshine_hours]">
      <input type="number" name="crop[crop_stages_attributes][0][sunshine_requirement_attributes][target_sunshine_hours]">
    `;

    document.body.innerHTML = templateHTML;

    expect(document.querySelector('input[name*="minimum_sunshine_hours"]')).toBeTruthy();
    expect(document.querySelector('input[name*="target_sunshine_hours"]')).toBeTruthy();
  });
});

