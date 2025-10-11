// 作物選択画面のJavaScript
(function() {
  console.log('🌾 Crop selection script loading');
  
  function initCropSelection() {
    const checkboxes = document.querySelectorAll('.crop-check');
    const counter = document.getElementById('counter');
    const submitBtn = document.getElementById('submitBtn');
    const hint = document.getElementById('hint');
    
    // 必要な要素が存在しない場合は静かに終了（他のページでは実行しない）
    if (!checkboxes.length || !counter || !submitBtn) {
      return;
    }
    
    console.log('Found:', checkboxes.length, 'checkboxes');
    console.log('Counter:', counter);
    console.log('Button:', submitBtn);
    
    function updateSelection() {
      const count = document.querySelectorAll('.crop-check:checked').length;
      counter.textContent = count;
      console.log('Count:', count);
      
      if (count > 0) {
        counter.style.background = '#4299e1';
        counter.style.color = 'white';
        submitBtn.disabled = false;
        submitBtn.style.opacity = '1';
        submitBtn.style.cursor = 'pointer';
        hint.style.display = 'none';
      } else {
        counter.style.background = '#e2e8f0';
        counter.style.color = '#a0aec0';
        submitBtn.disabled = true;
        submitBtn.style.opacity = '0.5';
        submitBtn.style.cursor = 'not-allowed';
        hint.style.display = 'block';
      }
    }
    
    checkboxes.forEach(checkbox => {
      checkbox.addEventListener('change', updateSelection);
    });
    
    updateSelection();
    console.log('Crop selection initialized');
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

