// 肥料AI作成機能 - Propshaftで直接配信
// Stimulusを使わない純粋なJavaScript実装

(function() {
  'use strict';

  function initializeFertilizeAi() {
    const button = document.getElementById('ai-save-fertilize-btn');
    if (!button) return;

    const statusDiv = document.getElementById('ai-save-status');
    const nameField = document.querySelector('input[name="fertilize[name]"]');
    const adPopup = document.getElementById('ad-popup-overlay');

    if (!nameField) {
      console.warn('[FertilizeAi] Name field not found');
      return;
    }

    console.log('[FertilizeAi] Initialized', { button, statusDiv, nameField, adPopup });

    // イベントリスナーを設定
    button.addEventListener('click', async function(event) {
      event.preventDefault();

      const fertilizeName = nameField.value.trim();

      // バリデーション
      if (!fertilizeName) {
        const enterName = button.dataset.enterName || '肥料名を入力してください';
        showStatus(statusDiv, enterName, 'error');
        return;
      }

      // ボタンを無効化
      button.disabled = true;
      button.textContent = button.dataset.buttonFetching || '🤖 AIで情報を取得中...';
      
      const fetching = button.dataset.fetching || 'AIで肥料情報を取得しています...';
      showStatus(statusDiv, fetching, 'info');

      // 広告ポップアップを表示
      if (adPopup) {
        adPopup.classList.add('show');
        document.body.style.overflow = 'hidden';
      }

      try {
        const csrfToken = document.querySelector('[name="csrf-token"]')?.content;

        // AI Create APIを呼び出し
        const response = await fetch('/api/v1/fertilizes/ai_create', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken
          },
          body: JSON.stringify({ 
            name: fertilizeName
          })
        });

        const data = await response.json();

        if (response.ok) {
          // 成功時：広告を閉じて肥料詳細画面に遷移
          const successMsg = (button.dataset.createdSuccess || '✓ 肥料「%{name}」の情報を取得して保存しました！').replace('%{name}', data.fertilize_name);
          showStatus(statusDiv, successMsg, 'success');

          setTimeout(() => {
            if (adPopup) {
              adPopup.classList.remove('show');
              document.body.style.overflow = '';
            }
            window.location.href = `/fertilizes/${data.fertilize_id}`;
          }, 1500);
        } else {
          // エラー時
          if (adPopup) {
            adPopup.classList.remove('show');
            document.body.style.overflow = '';
          }
          const errorMsg = `エラー: ${data.error || (button.dataset.fetchFailed || '肥料情報の取得に失敗しました')}`;
          showStatus(statusDiv, errorMsg, 'error');
          resetButton(button);
        }
      } catch (error) {
        console.error('Error in AI fertilize creation:', error);
        if (adPopup) {
          adPopup.classList.remove('show');
          document.body.style.overflow = '';
        }
        const networkError = button.dataset.networkError || 'ネットワークエラーが発生しました';
        showStatus(statusDiv, networkError, 'error');
        resetButton(button);
      }
    });
  }

  function showStatus(statusDiv, message, type) {
    if (statusDiv) {
      statusDiv.textContent = message;
      statusDiv.style.display = 'block';
      statusDiv.className = `form-text ai-status-${type}`;
    }
  }

  function resetButton(button) {
    if (button) {
      button.disabled = false;
      button.textContent = button.dataset.buttonIdle || '🤖 AIで肥料情報を取得・保存';
    }
  }

  // 通常のページロード（初回アクセス時）
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeFertilizeAi);
  } else {
    initializeFertilizeAi();
  }

  // Turboによるページ遷移
  document.addEventListener('turbo:load', initializeFertilizeAi);
})();


