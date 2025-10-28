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
  
  // 重複実行を防ぐフラグ
  let initialized = false;
  
  function initCropSelection() {
    console.log('🔍 initCropSelection called, readyState:', document.readyState);
    
    // 既に初期化済みならスキップ
    if (initialized) {
      console.log('⚠️  Already initialized, skipping');
      return;
    }
    
    // 他の作物選択スクリプトが既に実行されている場合はスキップ
    if (document.querySelector('.crop-check') && document.querySelector('.crop-check').hasAttribute('data-initialized')) {
      console.log('⚠️  Another crop selection script already initialized, skipping');
      return;
    }
    
    const checkboxes = document.querySelectorAll('.crop-check');
    const counter = document.getElementById('counter');
    const submitBtn = document.getElementById('submitBtn');
    const hint = document.getElementById('hint');
    
    // 必要な要素が存在しない場合は静かに終了（他のページでは実行しない）
    if (!checkboxes.length || !counter || !submitBtn || !hint) {
      console.log('⚠️  Required elements not found');
      return;
    }
    
    console.log('✅ Crop selection initializing:', checkboxes.length, 'checkboxes found');
    
    // 初期化済みマークを設定
    checkboxes.forEach(checkbox => {
      checkbox.setAttribute('data-initialized', 'true');
    });
    
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
    
    // 初期化完了フラグを立てる
    initialized = true;
    console.log('✅ Crop selection initialized');
  }
  
  // <body>の最後に配置されるため、DOMは既に読み込まれている
  // ただし、Turboページ遷移のためにturbo:loadも監視
  
  // 初回実行（スクリプトロード時、DOMは既に準備完了）
  console.log('📄 Script loaded, readyState:', document.readyState);
  initCropSelection();
  
  // Turboによるページ遷移時（重複を避けるためturbo:frame-renderのみ使用）
  if (typeof Turbo !== 'undefined') {
    console.log('⚡ Turbo detected, registering turbo:frame-render handler');
    document.addEventListener('turbo:frame-render', function() {
      console.log('⚡ turbo:frame-render event fired');
      initialized = false;
      initCropSelection();
    });
    
    // turbo:before-cache で初期化をクリーンアップ
    document.addEventListener('turbo:before-cache', function() {
      console.log('🧹 turbo:before-cache - cleaning up');
      initialized = false;
    });
  }
})();

