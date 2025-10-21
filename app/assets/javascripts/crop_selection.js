// 作物選択画面のJavaScript
(function() {
  console.log('🌾 Crop selection script loading');
  
  const MAX_CROPS = 5;  // 作物選択の上限
  
  // i18n helper functions (inline copy for independence)
  function getI18nMessage(key, defaultMessage) {
    if (typeof document === 'undefined' || !document.body) {
      return defaultMessage;
    }
    const i18nData = document.body.dataset;
    return i18nData[key] || defaultMessage;
  }
  
  function getI18nTemplate(key, replacements, defaultMessage) {
    if (typeof document === 'undefined' || !document.body) {
      return defaultMessage;
    }
    let template = document.body.dataset[key] || defaultMessage;
    for (const [placeholder, value] of Object.entries(replacements)) {
      template = template.replace(new RegExp(`%\\{${placeholder}\\}`, 'g'), value);
    }
    return template;
  }
  
  function initCropSelection() {
    const checkboxes = document.querySelectorAll('.crop-check');
    const counter = document.getElementById('counter');
    const submitBtn = document.getElementById('submitBtn');
    const hint = document.getElementById('hint');
    
    // 必要な要素が存在しない場合は静かに終了（他のページでは実行しない）
    if (!checkboxes.length || !counter || !submitBtn || !hint) {
      return;
    }
    
    console.log('✅ Crop selection initializing:', checkboxes.length, 'checkboxes found');
    
    function updateSelection() {
      const count = document.querySelectorAll('.crop-check:checked').length;
      counter.textContent = count;
      console.log('📊 Selected count:', count);
      
      // 上限に達したら他のチェックボックスを無効化
      if (count >= MAX_CROPS) {
        checkboxes.forEach(checkbox => {
          if (!checkbox.checked) {
            checkbox.disabled = true;
            const card = checkbox.parentElement.querySelector('.crop-card');
            if (card) {
              card.style.opacity = '0.5';
              card.style.cursor = 'not-allowed';
            }
          }
        });
        hint.textContent = getI18nTemplate('jsCropSelectionMaxMessage', {max: MAX_CROPS}, `Maximum ${MAX_CROPS} crop types can be selected`);
        hint.style.display = 'block';
        hint.style.color = '#e53e3e';
      } else {
        // 上限未満なら全て有効化
        checkboxes.forEach(checkbox => {
          checkbox.disabled = false;
          const card = checkbox.parentElement.querySelector('.crop-card');
          if (card) {
            card.style.opacity = '1';
            card.style.cursor = 'pointer';
          }
        });
      }
      
      if (count > 0) {
        counter.style.background = '#4299e1';
        counter.style.color = 'white';
        submitBtn.disabled = false;
        submitBtn.style.opacity = '1';
        submitBtn.style.cursor = 'pointer';
        if (count < MAX_CROPS) {
          hint.style.display = 'none';
        }
      } else {
        counter.style.background = '#e2e8f0';
        counter.style.color = '#a0aec0';
        submitBtn.disabled = true;
        submitBtn.style.opacity = '0.5';
        submitBtn.style.cursor = 'not-allowed';
        hint.style.display = 'block';
        hint.style.color = '';
        // Restore original hint text
        const originalText = hint.getAttribute('data-original-text');
        if (originalText) {
          hint.textContent = originalText;
        }
      }
    }
    
    // オリジナルのヒントテキストを保存
    if (hint.textContent) {
      hint.setAttribute('data-original-text', hint.textContent);
    }
    
    checkboxes.forEach(checkbox => {
      checkbox.addEventListener('change', updateSelection);
    });
    
    updateSelection();
    console.log('✅ Crop selection initialized');
  }
  
  // DOMが既にロードされている場合は即座に実行、そうでなければイベントを待つ
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initCropSelection);
  } else {
    initCropSelection();
  }
  
  document.addEventListener('turbo:load', initCropSelection);
  window.addEventListener('load', initCropSelection);
})();

