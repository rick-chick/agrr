// app/assets/javascripts/plans_select_crop.js
// 作物選択画面の選択カウンター機能

console.log('🌾 plans_select_crop.js loaded');
console.log('📄 Document readyState:', document.readyState);
console.log('🔍 Current URL:', window.location.href);

function initializeCropSelection() {
  console.log('🔍 initializeCropSelection called');
  console.log('⏰ Called at:', new Date().toISOString());
  
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
  
  console.log('✅ Plans select crop counter initialized');
}

// 即座に実行を試みる
console.log('🚀 Attempting immediate execution, readyState:', document.readyState);
if (document.readyState === 'loading') {
  console.log('⏳ Document still loading, waiting for DOMContentLoaded');
} else {
  console.log('✅ Document already loaded, executing immediately');
  initializeCropSelection();
}

// 通常のページロード（初回アクセス時）
document.addEventListener('DOMContentLoaded', function() {
  console.log('📄 DOMContentLoaded event fired');
  initializeCropSelection();
});

// Turboによるページ遷移
document.addEventListener('turbo:load', function() {
  console.log('⚡ turbo:load event fired');
  initializeCropSelection();
});

