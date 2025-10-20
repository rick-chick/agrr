// app/assets/javascripts/plans_select_crop.js
// 作物選択画面の選択カウンター機能

document.addEventListener('turbo:load', function() {
  // 作物選択画面でのみ実行
  const checkboxes = document.querySelectorAll('.crop-check');
  if (checkboxes.length === 0) return;
  
  const counter = document.getElementById('counter');
  const submitBtn = document.getElementById('submitBtn');
  const hint = document.getElementById('hint');
  
  if (!counter || !submitBtn || !hint) return;
  
  function updateCounter() {
    const checkedCount = document.querySelectorAll('.crop-check:checked').length;
    counter.textContent = checkedCount;
    
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
});

