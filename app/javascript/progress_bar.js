// 進捗バーの幅を設定
function updateProgressBars() {
  document.querySelectorAll('.progress-fill[data-progress]').forEach((element) => {
    const progress = element.dataset.progress;
    element.style.width = `${progress}%`;
  });
}

// 初期ロード時にも実行
updateProgressBars();

// Turboイベントで実行
document.addEventListener('turbo:load', updateProgressBars);
document.addEventListener('turbo:render', updateProgressBars);
document.addEventListener('turbo:frame-load', updateProgressBars);

// Turbo Streamsでの部分更新時にも実行
document.addEventListener('turbo:before-stream-render', (event) => {
  // ストリームレンダリングの後に実行
  requestAnimationFrame(() => {
    updateProgressBars();
  });
});

// MutationObserverで動的な変更も監視
const observer = new MutationObserver((mutations) => {
  mutations.forEach((mutation) => {
    // 追加されたノードに進捗バーが含まれているかチェック
    mutation.addedNodes.forEach((node) => {
      if (node.nodeType === 1) { // Element ノードのみ
        if (node.classList?.contains('progress-fill') && node.dataset?.progress) {
          const progress = node.dataset.progress;
          node.style.width = `${progress}%`;
        }
        // 子要素も確認
        node.querySelectorAll?.('.progress-fill[data-progress]').forEach((element) => {
          const progress = element.dataset.progress;
          element.style.width = `${progress}%`;
        });
      }
    });
  });
});

// ページ全体を監視
observer.observe(document.documentElement, {
  childList: true,
  subtree: true
});

