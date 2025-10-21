// app/assets/javascripts/plans_select_crop.js
// 作物選択画面の選択カウンター機能

(function() {
  'use strict';
  
  console.log('🌾 plans_select_crop.js loaded');
  
  // 重複実行を防ぐフラグ
  let initialized = false;
  
  function initializeCropSelection() {
    console.log('🔍 initializeCropSelection called');
    console.log('⏰ Called at:', new Date().toISOString());
    console.log('📄 Document readyState:', document.readyState);
    
    // 既に初期化済みならスキップ
    if (initialized) {
      console.log('⚠️  Already initialized, skipping');
      return;
    }
    
    // 作物選択画面でのみ実行
    const checkboxes = document.querySelectorAll('.crop-check');
    console.log('📊 Found checkboxes:', checkboxes.length);
    
    if (checkboxes.length === 0) {
      console.log('⚠️  No checkboxes found, exiting');
      return;
    }
    
    const counter = document.getElementById('counter');
    const submitBtn = document.getElementById('submitBtn');
    const hint = document.getElementById('hint');
    
    console.log('📍 Elements found:', {
      counter: !!counter,
      submitBtn: !!submitBtn,
      hint: !!hint
    });
    
    if (!counter || !submitBtn || !hint) {
      console.error('❌ Missing required elements');
      return;
    }
    
    function updateCounter() {
      const checkedCount = document.querySelectorAll('.crop-check:checked').length;
      counter.textContent = checkedCount;
      console.log('✅ Counter updated:', checkedCount);
      
      if (checkedCount > 0) {
        submitBtn.disabled = false;
        submitBtn.style.opacity = '1';
        submitBtn.style.cursor = 'pointer';
        hint.style.display = 'none';
      } else {
        submitBtn.disabled = true;
        submitBtn.style.opacity = '0.5';
        submitBtn.style.cursor = 'not-allowed';
        hint.style.display = 'block';
      }
    }
    
    checkboxes.forEach(checkbox => {
      checkbox.addEventListener('change', updateCounter);
    });
    
    // 初期状態を更新
    updateCounter();
    
    // 初期化完了フラグを立てる
    initialized = true;
    
    console.log('✅ Plans select crop counter initialized');
  }
  
  // <body>の最後に配置されるため、DOMは既に読み込まれている
  // ただし、Turboページ遷移のためにturbo:loadも監視
  
  // 初回実行（スクリプトロード時、DOMは既に準備完了）
  console.log('📄 Script loaded, readyState:', document.readyState);
  initializeCropSelection();
  
  // Turboによるページ遷移時
  if (typeof Turbo !== 'undefined') {
    console.log('⚡ Turbo detected, registering turbo:load handler');
    document.addEventListener('turbo:load', function() {
      console.log('⚡ turbo:load event fired');
      initialized = false;
      initializeCropSelection();
    });
    
    // turbo:before-cache で初期化をクリーンアップ
    document.addEventListener('turbo:before-cache', function() {
      console.log('🧹 turbo:before-cache - cleaning up');
      initialized = false;
    });
  }
})();

